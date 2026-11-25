import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';
import '../utils/public_user_id.dart';
import 'recharge_screen.dart';

class InviteShareScreen extends StatefulWidget {
  const InviteShareScreen({super.key, required this.state});

  final AppState state;

  @override
  State<InviteShareScreen> createState() => _InviteShareScreenState();
}

class _InviteShareScreenState extends State<InviteShareScreen> {
  final TextEditingController _codeController = TextEditingController();
  Map<String, dynamic>? data;
  bool loading = true;
  bool joining = false;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    final value = await state.backend.inviteSummary(userId: state.userId);
    if (!mounted) return;
    setState(() {
      data = value;
      loading = false;
    });
  }

  String _formatCoins(Object? raw) {
    final value = int.tryParse(raw?.toString() ?? '') ?? 0;
    final digits = value.abs().toString();
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return '${value < 0 ? '-' : ''}${out.toString()}';
  }

  String _formatPercent(Object? raw) {
    final value = double.tryParse(raw?.toString() ?? '') ?? 0;
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  // Integer US cents -> "$3.00" / "$0.05".
  String _formatDollars(Object? rawCents) {
    final cents = int.tryParse(rawCents?.toString() ?? '') ?? 0;
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    return '$sign\$${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
  }

  int get _dollarBalanceCents =>
      int.tryParse(data?['referral_dollar_balance_usd_cents']?.toString() ?? '') ?? 0;

  // The enter-code option closes 48 hours after the ID is created
  // (Vinay, 2026-11-23). A missing field (old server) means open.
  bool get _inviteWindowOpen => data?['invite_window_open'] != false;

  List<Map<String, dynamic>> get _dollarCommissions {
    final raw = data?['referral_dollar_commissions'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  List<Map<String, dynamic>> get _dollarWithdrawals {
    final raw = data?['referral_dollar_withdrawals'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  int get _withdrawMinCents =>
      int.tryParse(data?['referral_withdrawal_min_usd_cents']?.toString() ?? '') ?? 300;

  bool _withdrawing = false;

  Future<void> _showWithdrawDialog() async {
    final balance = _dollarBalanceCents;
    final min = _withdrawMinCents;
    if (balance < min) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You need at least ${_formatDollars(min)} to withdraw.',
          ),
        ),
      );
      return;
    }
    final amountController = TextEditingController(
      text: (balance / 100).toStringAsFixed(2),
    );
    String? selectedProviderId;
    List<Map<String, dynamic>> providers = const [];
    bool providersLoading = true;
    String? dialogError;
    final loaded = await state.backend.rechargeProviders();
    if (!mounted) {
      amountController.dispose();
      return;
    }
    providers = loaded;
    providersLoading = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Withdraw referral dollars'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Balance: ${_formatDollars(balance)}  •  Minimum: ${_formatDollars(min)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount in dollars',
                    hintText: 'e.g. 3.00',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Send to (coin seller / merchant):',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                if (providersLoading)
                  const Center(child: CircularProgressIndicator())
                else if (providers.isEmpty)
                  const Text('No coin sellers or merchants found.')
                else
                  RadioGroup<String>(
                    groupValue: selectedProviderId,
                    onChanged: (value) =>
                        setDialogState(() => selectedProviderId = value),
                    child: Column(
                      children: providers.map((provider) {
                        final id = provider['user_id']?.toString() ?? '';
                        final name =
                            provider['display_name']?.toString().trim() ?? '';
                        final publicId =
                            provider['public_id']?.toString() ?? '';
                        final role = provider['role']?.toString() ?? '';
                        return RadioListTile<String>(
                          value: id,
                          title: Text(name.isNotEmpty ? name : 'Seller'),
                          subtitle: Text(
                            'ID $publicId  •  $role',
                          ),
                        );
                      }).toList(growable: false),
                    ),
                  ),
                if (dialogError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    dialogError!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'The seller / merchant receives the dollars and automatically gets 11,000,000 coins per \$1 into their seller wallet. You get nothing extra for sending the dollars.',
                  style: TextStyle(fontSize: 11, height: 1.35),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _withdrawing
                  ? null
                  : () async {
                      final dollars =
                          double.tryParse(amountController.text.trim());
                      if (dollars == null) {
                        setDialogState(
                          () => dialogError = 'Enter a valid amount.',
                        );
                        return;
                      }
                      final cents = (dollars * 100).round();
                      if (cents < min) {
                        setDialogState(
                          () => dialogError =
                              'Minimum withdrawal is ${_formatDollars(min)}.',
                        );
                        return;
                      }
                      if (cents > balance) {
                        setDialogState(
                          () => dialogError =
                              'Amount is more than your balance.',
                        );
                        return;
                      }
                      if (selectedProviderId == null) {
                        setDialogState(
                          () => dialogError =
                              'Select a coin seller or merchant.',
                        );
                        return;
                      }
                      setDialogState(() {
                        _withdrawing = true;
                        dialogError = null;
                      });
                      final result =
                          await state.backend.withdrawInviteDollars(
                        userId: state.userId,
                        providerUserId: selectedProviderId!,
                        amountUsdCents: cents,
                      );
                      if (!mounted) return;
                      setDialogState(() => _withdrawing = false);
                      if (result?['ok'] == true) {
                        final withdrawal = result?['withdrawal'];
                        final coins =
                            withdrawal is Map ? withdrawal['coins_credited'] : null;
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Sent ${_formatDollars(cents)}. The seller receives ${_formatCoins(coins)} coins in their seller wallet.',
                            ),
                          ),
                        );
                        await _load();
                        return;
                      }
                      final error = result?['error']?.toString() ??
                          'Withdrawal failed.';
                      setDialogState(
                        () => dialogError = error.replaceAll('_', ' '),
                      );
                    },
              child: Text(_withdrawing ? 'Sending...' : 'Send'),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
  }

  String get invitationCode =>
      data?['invitation_code']?.toString() ?? state.publicId;

  String get inviteLink =>
      data?['invite_link']?.toString().trim().isNotEmpty == true
          ? data!['invite_link'].toString()
          : '';

  String get shareText =>
      'Join me on DarkVibeX: $inviteLink\n'
      'Invitation code: $invitationCode\n'
      'If you install from this link, the invitation binds automatically after signup. '
      'Every successful invite earns 800,000 coins once, plus 5% of every recharge the invited friend makes in the next 3 months, in dollars.';

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: invitationCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invitation code copied.')),
    );
  }

  Future<void> _copyLink() async {
    if (inviteLink.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: inviteLink));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite link copied.')),
    );
  }

  Future<void> _share() async {
    await SharePlus.instance.share(ShareParams(text: shareText));
  }

  Future<void> _join() async {
    if (joining) return;
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{7}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 7-digit invitation code.')),
      );
      return;
    }
    setState(() => joining = true);
    final result = await state.backend.bindInvitationCode(
      userId: state.userId,
      invitationCode: code,
    );
    if (!mounted) return;
    setState(() => joining = false);
    if (result?['ok'] == true) {
      _codeController.clear();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation code joined successfully.')),
      );
      return;
    }
    final error = result?['error']?.toString() ?? 'Unable to join invitation code.';
    final message = error == 'cannot_invite_self'
        ? 'You cannot use your own invitation code.'
        : error == 'invite_window_expired'
            ? 'Invite codes can only be entered within 48 hours of creating your ID.'
            : error == 'device_already_used_invite'
                ? 'This device has already used an invite code.'
                : error.replaceAll('_', ' ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _goldButton({
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
  }) =>
      FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.card_giftcard_rounded, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: TinniPalette.brightGold,
          foregroundColor: const Color(0xFF7A160C),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bound = data?['bound_to'];
    final boundMap =
        bound is Map ? Map<String, dynamic>.from(bound) : null;
    final invitedRaw = data?['invited_users'];
    final invited = invitedRaw is List
        ? invitedRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Invite & Share'),
        backgroundColor: const Color(0x66130A2A),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF8D0B1F),
                          Color(0xFFC32A36),
                          Color(0xFF710716),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: TinniPalette.gold, width: 1.2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 16,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.redeem_rounded,
                          color: TinniPalette.gold,
                          size: 54,
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Invite Get Gold',
                          style: TextStyle(
                            color: TinniPalette.gold,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Invite friends and earn 800,000 coins per successful invite, plus 5% of every recharge they make in the next 3 months, in dollars.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF2A2140),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _goldButton(
                          label: 'Get Coins',
                          icon: Icons.monetization_on_rounded,
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => RechargeScreen(state: state),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionTitle('My Record'),
                  _panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _recordRow(
                          'Friends Invite',
                          (data?['invite_count'] ?? 0).toString(),
                        ),
                        _divider(),
                        _recordRow(
                          'Fixed invite rewards',
                          '${_formatCoins(data?['successful_invite_reward_coins'])} coins',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Successful Friend Invite Details',
                          style: TextStyle(
                            color: TinniPalette.gold,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (invited.isEmpty)
                          const Text(
                            'No successful invites yet.',
                            style: TextStyle(
                              color: const Color(0xFF2A2140),
                              fontSize: 12,
                            ),
                          )
                        else
                          _inviteRecordsTable(invited),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionTitle('Referral Dollars'),
                  _panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _recordRow(
                          'Dollar balance',
                          _formatDollars(
                            data?['referral_dollar_balance_usd_cents'],
                          ),
                        ),
                        _divider(),
                        _recordRow(
                          'Total referral dollars earned',
                          _formatDollars(
                            data?['referral_dollar_commission_usd_cents'],
                          ),
                        ),
                        _divider(),
                        _recordRow(
                          'Commission rate',
                          '${_formatPercent(data?['referral_commission_rate_percent'])}% of every recharge, 3 months from joining',
                        ),
                        const SizedBox(height: 12),
                        _goldButton(
                          label: _dollarBalanceCents >= _withdrawMinCents
                              ? 'Withdraw'
                              : 'Withdraw (min ${_formatDollars(_withdrawMinCents)})',
                          icon: Icons.account_balance_wallet_rounded,
                          onPressed: _showWithdrawDialog,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Recent referral earnings',
                          style: TextStyle(
                            color: TinniPalette.gold,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_dollarCommissions.isEmpty)
                          const Text(
                            'No recharge commissions yet. When an invited friend recharges within 3 months of joining, 5% of that recharge lands here in dollars.',
                            style: TextStyle(
                              color: const Color(0xFF2A2140),
                              fontSize: 12,
                            ),
                          )
                        else
                          ..._dollarCommissions.map(
                            (row) => _recordRow(
                              '${(row['display_name']?.toString().trim().isNotEmpty == true ? row['display_name'].toString() : 'Invited friend')} recharged ${_formatDollars(row['recharge_usd_cents'])}',
                              '+${_formatDollars(row['commission_usd_cents'])}${row['status'] == 'reversed' ? ' (reversed)' : ''}',
                            ),
                          ),
                        if (_dollarWithdrawals.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Withdrawals',
                            style: TextStyle(
                              color: TinniPalette.gold,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._dollarWithdrawals.map(
                            (row) => _recordRow(
                              'To ${(row['provider_name']?.toString().trim().isNotEmpty == true ? row['provider_name'].toString() : row['provider_role']?.toString() ?? 'seller')} (${row['provider_public_id'] ?? ''})',
                              '-${_formatDollars(row['amount_usd_cents'])}  •  ${_formatCoins(row['coins_credited'])} coins to seller wallet',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionTitle('Invite Method'),
                  _panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Your invitation code',
                          style: TextStyle(
                            color: const Color(0xFF2A2140),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x44FFFFFF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0x6650D8FF),
                                  ),
                                ),
                                child: Text(
                                  invitationCode,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: _copyCode,
                              icon: const Icon(Icons.copy_rounded),
                            ),
                            const SizedBox(width: 4),
                            IconButton.filled(
                              onPressed: _share,
                              icon: const Icon(Icons.share_rounded),
                            ),
                          ],
                        ),
                        if (inviteLink.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Your invite link',
                            style: TextStyle(
                              color: const Color(0xFF2A2140),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  inviteLink,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _copyLink,
                                tooltip: 'Copy invite link',
                                icon: const Icon(Icons.link_rounded),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        const Text(
                          "Each successful invite gives 800,000 coins once. Every recharge the invited friend makes within 3 months of joining also earns you 5% of that recharge in dollars, shown below. At \$3 you can withdraw the dollars to a coin seller or merchant — they receive the dollars and automatically get 11,000,000 coins per \$1 into their seller wallet.",
                          style: TextStyle(
                            color: const Color(0xFF2A2140),
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                        // Enter an inviter's code here, beside your own
                        // code (Vinay, 2026-11-23): the option stays on
                        // this screen for later, not just the one-time
                        // prompt after login — but only within 48 hours
                        // of the ID being created, then it disappears.
                        if (boundMap == null && _inviteWindowOpen) ...[
                          const SizedBox(height: 14),
                          const Text(
                            'Have an invitation code?',
                            style: TextStyle(
                              color: const Color(0xFF2A2140),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            maxLength: 7,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Invitation code',
                              hintText: '7-digit user ID',
                              counterText: '',
                              prefixIcon: Icon(Icons.link_rounded),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _goldButton(
                            label: joining ? 'Joining...' : 'Join',
                            icon: Icons.login_rounded,
                            onPressed: joining ? () {} : _join,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (boundMap != null) ...[
                    const SizedBox(height: 12),
                    _sectionTitle('Joined inviter'),
                    _panel(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: Color(0x33FFD36B),
                          child: Icon(
                            Icons.person_rounded,
                            color: TinniPalette.gold,
                          ),
                        ),
                        title: Text(
                          boundMap['inviter_name']?.toString().trim().isNotEmpty ==
                                  true
                              ? boundMap['inviter_name'].toString()
                              : 'Inviter',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          'ID ${formatPublicUserId(boundMap['inviter_public_id'], fallback: boundMap['invitation_code']?.toString() ?? '')}',
                          style: const TextStyle(color: const Color(0xFF2A2140)),
                        ),
                        trailing: const Icon(
                          Icons.verified_rounded,
                          color: TinniPalette.gold,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                ],
              ),
            ),
    );
  }

  String _formatDateTime(Object? raw) {
    final ms = int.tryParse(raw?.toString() ?? '') ?? 0;
    if (ms <= 0) return '-';
    final value = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  Widget _inviteUserCell(Map<String, dynamic> row) {
    final name = row['display_name']?.toString().trim() ?? '';
    final avatarKey = row['avatar_key']?.toString().trim() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0x33FFD36B),
            foregroundImage: avatarKey.isEmpty
                ? null
                : NetworkImage(
                    state.backend.fileUrl(avatarKey),
                    headers: state.backend.fileHeaders,
                  ),
            child: Text(
              (name.isNotEmpty ? name[0] : '?').toUpperCase(),
              style: const TextStyle(
                color: TinniPalette.gold,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 125,
            child: Text(
              name.isNotEmpty ? name : 'DarkVibeX User',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inviteTableCell(
    String text, {
    bool header = false,
    TextAlign align = TextAlign.center,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: TextStyle(
            color: header ? TinniPalette.gold : const Color(0xFF2A2140),
            fontSize: header ? 10 : 11,
            fontWeight: header ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      );

  Widget _inviteRecordsTable(List<Map<String, dynamic>> invited) {
    // The invited-users list scrolls up/down inside a fixed-height box
    // (Vinay, 2026-11-23): 5 invites show at a time, the rest are seen
    // by scrolling. A long list must not push the rest of the Share page
    // down. The horizontal scroll stays for the wide table.
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 272,
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: TableBorder.all(
                  color: const Color(0x44FFD36B),
                  width: 0.8,
                ),
                columnWidths: const <int, TableColumnWidth>{
                  0: FixedColumnWidth(190),
                  1: FixedColumnWidth(90),
                  2: FixedColumnWidth(145),
                  3: FixedColumnWidth(120),
                  4: FixedColumnWidth(110),
                  5: FixedColumnWidth(110),
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFF7A1320)),
                    children: [
                      _inviteTableCell('DP / Name', header: true),
                      _inviteTableCell('8-digit ID', header: true),
                      _inviteTableCell('Invite Date & Time', header: true),
                      _inviteTableCell('Invite Reward', header: true),
                      _inviteTableCell('Referral \$', header: true),
                      _inviteTableCell('Recharge', header: true),
                    ],
                  ),
                  for (final row in invited)
                    TableRow(
                      decoration:
                          const BoxDecoration(color: Color(0xFF5A0D17)),
                      children: [
                        _inviteUserCell(row),
                        _inviteTableCell(
                          formatPublicUserId(row['public_id']),
                        ),
                        _inviteTableCell(_formatDateTime(row['bound_at'])),
                        _inviteTableCell(
                          '+${_formatCoins(row['fixed_reward_coins'])}',
                        ),
                        _inviteTableCell(
                          '+${_formatDollars(row['referral_commission_usd_cents'])}',
                        ),
                        _inviteTableCell(
                          _formatDollars(row['total_recharge_usd_cents']),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF65101B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x6650D8FF)),
        ),
        child: child,
      );

  Widget _sectionTitle(String value) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 7),
        child: Text(
          value,
          style: const TextStyle(
            color: TinniPalette.gold,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      );

  Widget _recordRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: const Color(0xFF2A2140),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: TinniPalette.gold,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );

  Widget _divider() => const Divider(
        height: 1,
        color: Color(0x44FFD36B),
      );
}
