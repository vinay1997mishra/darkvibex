import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'backend_api.dart';

/// One Google Play Billing coin pack (shared contract with the worker
/// slice). Prices are set in Play Console and always come from the
/// Play storefront — this list only fixes product IDs and coins per
/// pack, never a price.
///
/// [usdLabel] is what the pack shows as in the app (Vinay, 2026-11-21):
/// packs display as $1 / $2 / $5 / $10; the rupee amount
/// (Rs.110 / Rs.220 / Rs.550 / Rs.1,100) is what the Play payment sheet
/// charges and what the wallet shows after the payment.
class PlayPack {
  const PlayPack({
    required this.productId,
    required this.coins,
    required this.usdLabel,
  });

  final String productId;
  final int coins;
  final String usdLabel;
}

/// Google Play Billing for coin purchases (Vinay, 2026-11-20).
///
/// The store is wrapped so the screen never talks to the plugin
/// directly: every store call is guarded, so a device without Play
/// Billing (or a test without a store) just reports the packs as
/// unavailable instead of throwing. The service is also the seam the
/// widget tests use — they inject a fake instead of the real store.
///
/// Flow: [init] loads store availability + localized prices +
/// the server-side first-recharge flag. [buy] starts a consumable
/// purchase with `autoConsume: false` on purpose — the purchase is
/// only completed (consumed) after the server has verified the
/// purchase token and credited the coins (see RechargeScreen).
/// Unfinished purchases are replayed onto [purchaseStream] by
/// [restore] when the screen opens.
class PlayBillingService {
  PlayBillingService({InAppPurchase? store}) : _storeOverride = store;

  /// The 4 coin packs (Vinay, 2026-11-21), cheapest first. Rs.5,500
  /// was removed; it must also be removed in Play Console (Vinay's side).
  static const List<PlayPack> packs = <PlayPack>[
    PlayPack(productId: 'coins_8000000', coins: 8000000, usdLabel: '\$1'),
    PlayPack(productId: 'coins_16000000', coins: 16000000, usdLabel: '\$2'),
    PlayPack(productId: 'coins_40000000', coins: 40000000, usdLabel: '\$5'),
    PlayPack(productId: 'coins_80000000', coins: 80000000, usdLabel: '\$10'),
  ];

  static const Set<String> productIds = <String>{
    'coins_8000000',
    'coins_16000000',
    'coins_40000000',
    'coins_80000000',
  };

  final InAppPurchase? _storeOverride;

  /// Resolved lazily so constructing the service (including in widget
  /// tests with a fake) never touches the platform.
  InAppPurchase get _store => _storeOverride ?? InAppPurchase.instance;

  /// Timers owned by [_timeout]. Cancelled by [dispose] so no timer
  /// outlives the screen that owns this service.
  final List<Timer> _timers = <Timer>[];

  /// Like [Future.timeout], but the timer is tracked so [dispose]
  /// can cancel it. The store calls below can hang forever on a
  /// device (or test host) without a billing client; the timeout
  /// turns that into "unavailable" instead of a stuck screen.
  Future<T> _timeout<T>(
    Future<T> future,
    Duration duration,
    T Function() onTimeout,
  ) {
    final completer = Completer<T>();
    late final Timer timer;
    timer = Timer(duration, () {
      _timers.remove(timer);
      if (!completer.isCompleted) completer.complete(onTimeout());
    });
    _timers.add(timer);
    unawaited(
      future.then(
        (value) {
          timer.cancel();
          _timers.remove(timer);
          if (!completer.isCompleted) completer.complete(value);
        },
        onError: (Object error, StackTrace stackTrace) {
          timer.cancel();
          _timers.remove(timer);
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
      ),
    );
    return completer.future;
  }

  /// Cancels any pending store timeouts. Call when the owning screen
  /// is disposed.
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  /// True when the device can buy through the store.
  bool available = false;

  /// True when this user has never recharged (server-side flag).
  /// A first recharge doubles the coins and grants VIP1 for 10 days.
  bool firstRechargeAvailable = false;

  /// Localized Play storefront prices by product ID. Empty when the
  /// store is unavailable or has not returned the products yet.
  Map<String, ProductDetails> prices =
      const <String, ProductDetails>{};

  Stream<List<PurchaseDetails>> get purchaseStream =>
      _store.purchaseStream;

  /// Loads availability, localized prices and the first-recharge
  /// flag. Never throws, and never waits forever: every store call
  /// has a timeout, because a wedged billing client (or a device
  /// without Play services) must not hang the screen — it just shows
  /// the packs as unavailable.
  Future<void> init(BackendApi backend) async {
    try {
      available = await _timeout(
        _store.isAvailable(),
        const Duration(seconds: 5),
        () => false,
      );
    } catch (_) {
      available = false;
    }
    if (available) {
      try {
        final response = await _timeout(
          _store.queryProductDetails(productIds),
          const Duration(seconds: 10),
          () => ProductDetailsResponse(
            productDetails: const <ProductDetails>[],
            notFoundIDs: const <String>[],
          ),
        );
        prices = <String, ProductDetails>{
          for (final details in response.productDetails) details.id: details,
        };
      } catch (_) {
        prices = const <String, ProductDetails>{};
      }
    }
    final packsResponse = await backend.playPacks();
    firstRechargeAvailable =
        packsResponse?['firstRechargeAvailable'] == true;
  }

  /// Starts a consumable purchase for [productId]. Returns false when
  /// the product has no storefront price or the store refuses to
  /// start the purchase. Never throws.
  Future<bool> buy(String productId) async {
    final details = prices[productId];
    if (details == null) return false;
    try {
      return await _timeout(
        _store.buyConsumable(
          purchaseParam: PurchaseParam(productDetails: details),
          // False on purpose: the purchase is completed only after the
          // server verifies the token and credits the coins.
          autoConsume: false,
        ),
        const Duration(seconds: 10),
        () => false,
      );
    } catch (_) {
      return false;
    }
  }

  /// Completes (consumes) a verified purchase. Never throws.
  Future<void> complete(PurchaseDetails purchase) async {
    try {
      await _timeout(
        _store.completePurchase(purchase),
        const Duration(seconds: 10),
        () {},
      );
    } catch (_) {}
  }

  /// Replays unfinished past purchases onto [purchaseStream] so a
  /// purchase interrupted before verification is processed when the
  /// screen opens again. Never throws.
  Future<void> restore() async {
    try {
      await _timeout(
        _store.restorePurchases(),
        const Duration(seconds: 10),
        () {},
      );
    } catch (_) {}
  }
}
