import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../lib/app/app_state.dart';
import '../lib/infra/backend_api.dart';
import '../lib/infra/play_billing.dart';
import '../lib/screens/recharge_screen.dart';

/// Fake store for the Recharge screen: no platform channels, the test
/// drives availability, prices, and the purchase stream by hand.
class _FakePlayBilling extends PlayBillingService {
  _FakePlayBilling({
    this.fakeAvailable = false,
    this.fakeFirstRechargeAvailable = false,
    Map<String, ProductDetails>? fakePrices,
  }) : _fakePrices = fakePrices ?? const <String, ProductDetails>{};

  final bool fakeAvailable;
  final bool fakeFirstRechargeAvailable;
  final Map<String, ProductDetails> _fakePrices;

  final StreamController<List<PurchaseDetails>> purchases =
      StreamController<List<PurchaseDetails>>.broadcast();
  final List<String> buyCalls = <String>[];
  final List<PurchaseDetails> completed = <PurchaseDetails>[];
  bool restoreCalled = false;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => purchases.stream;

  @override
  Future<void> init(BackendApi backend) async {
    available = fakeAvailable;
    firstRechargeAvailable = fakeFirstRechargeAvailable;
    prices = Map<String, ProductDetails>.from(_fakePrices);
  }

  @override
  Future<bool> buy(String productId) async {
    buyCalls.add(productId);
    return _fakePrices.containsKey(productId);
  }

  @override
  Future<void> complete(PurchaseDetails purchase) async {
    completed.add(purchase);
  }

  @override
  Future<void> restore() async {
    restoreCalled = true;
  }
}

Map<String, ProductDetails> _prices() => <String, ProductDetails>{
      for (final pack in PlayBillingService.packs)
        pack.productId: ProductDetails(
          id: pack.productId,
          title: '${pack.coins} coins',
          description: 'DarkVibeX coins',
          price: '₹110.00',
          rawPrice: 110,
          currencyCode: 'INR',
          currencySymbol: '₹',
        ),
    };

PurchaseDetails _purchased(String productId, String token) =>
    PurchaseDetails(
      purchaseID: 'test-$productId',
      productID: productId,
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: token,
        source: 'Google Play',
      ),
      transactionDate: '2026-11-20',
      status: PurchaseStatus.purchased,
    )..pendingCompletePurchase = true;

Future<void> _pumpScreen(
  WidgetTester tester, {
  required AppState state,
  PlayBillingService? billing,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RechargeScreen(state: state, playBilling: billing),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('buy coins section renders all four packs when the store is unavailable',
      (tester) async {
    final state = AppState();
    await _pumpScreen(tester, state: state);

    expect(find.text('Buy Coins'), findsOneWidget);
    expect(
      find.text('In-app purchases are not available on this device.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('recharge-first-recharge-badge')), findsNothing);
    for (final pack in PlayBillingService.packs) {
      // The list builds lazily: scroll each tile into view first.
      final key = Key('recharge-pack-${pack.productId}');
      await tester.scrollUntilVisible(find.byKey(key), 200);
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(find.byKey(key));
      // No store in tests: the packs still render, but buying is off.
      expect(button.onPressed, isNull);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('first-recharge badge shows when available and buy buttons are enabled',
      (tester) async {
    final state = AppState();
    final billing = _FakePlayBilling(
      fakeAvailable: true,
      fakeFirstRechargeAvailable: true,
      fakePrices: _prices(),
    );
    await _pumpScreen(tester, state: state, billing: billing);

    expect(billing.restoreCalled, isTrue);
    expect(find.byKey(const Key('recharge-first-recharge-badge')), findsOneWidget);
    expect(
      find.text('First recharge: DOUBLE coins + VIP1 for 10 days'),
      findsOneWidget,
    );
    for (final pack in PlayBillingService.packs) {
      final key = Key('recharge-pack-${pack.productId}');
      await tester.scrollUntilVisible(find.byKey(key), 200);
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(find.byKey(key));
      expect(button.onPressed, isNotNull);
      // Packs display as $1 / $2 / $5 / $10 (Vinay, 2026-11-21); the rupee
      // amount is what the Play sheet charges, not the tile.
      expect(
        find.descendant(of: find.byKey(key), matching: find.text(pack.usdLabel)),
        findsOneWidget,
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('tapping a pack shows a spinner until the purchase is canceled',
      (tester) async {
    final state = AppState();
    final billing = _FakePlayBilling(
      fakeAvailable: true,
      fakePrices: _prices(),
    );
    await _pumpScreen(tester, state: state, billing: billing);

    final packKey = const Key('recharge-pack-coins_8000000');
    await tester.ensureVisible(find.byKey(packKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(packKey));
    await tester.pump();

    expect(billing.buyCalls, <String>['coins_8000000']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    billing.purchases.add(<PurchaseDetails>[
      PurchaseDetails(
        purchaseID: 'test-cancel',
        productID: 'coins_8000000',
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: '',
          source: 'Google Play',
        ),
        transactionDate: '2026-11-20',
        status: PurchaseStatus.canceled,
      )..pendingCompletePurchase = true,
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Purchase canceled.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(billing.completed, hasLength(1));
    final button = tester.widget<FilledButton>(find.byKey(packKey));
    expect(button.onPressed, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('a purchased event that cannot be verified is not completed',
      (tester) async {
    final state = AppState();
    final billing = _FakePlayBilling(
      fakeAvailable: true,
      fakePrices: _prices(),
    );
    await _pumpScreen(tester, state: state, billing: billing);

    // The test backend answers nothing, so server verification fails
    // and the purchase must stay unfinished instead of being consumed.
    billing.purchases.add(
      <PurchaseDetails>[_purchased('coins_8000000', 'test-token-1')],
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Could not verify your purchase. Please try again.'),
      findsOneWidget,
    );
    expect(billing.completed, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
