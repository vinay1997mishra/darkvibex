import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';
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
      'Only coins received through eligible Coin Seller transfers into the invited user's normal wallet count toward commission.';

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
        : error.replaceAll('_', ' ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: TinniPalette.gold,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFD7B0),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

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
          backgroundColor: const Color(0xFFFFB517),
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
    final tiersRaw = data?['tiers'];
    final tiers = tiersRaw is List
        ? tiersRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
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
                          'Invite friends and earn commission only when they receive eligible Coin Seller coins in their normal wallet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFFFE6CB),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _stat(
                              'Current rate',
                              '${_formatPercent(data?['current_rate_percent'])}%',
                            ),
                            _stat(
                              'Rate basis',
                              '1\$ = 6,000,000',
                            ),
                            _stat(
                              'Level',
                              'Lv${data?['current_level'] ?? 0}',
                            ),
                          ],
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
                          'Invited users received',
                          '${_formatCoins(data?['invited_received_coins'])} coins',
                        ),
                        _divider(),
                        _recordRow(
                          'My invite commission',
                          '${_formatCoins(data?['commission_coins'])} coins',
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
                              color: Color(0xFFFFD7B0),
                              fontSize: 12,
                            ),
                          )
                        else
                          _inviteRecordsTable(invited),
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
                            color: Color(0xFFFFD7B0),
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
                                    color: const Color(0x66FFD36B),
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
                              color: Color(0xFFFFD7B0),
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
                          "Each successful invite gives 300,000 coins once. Ongoing commission counts only coins credited to the invited user's normal wallet through eligible Coin Seller transfers. Merchant transfers, gifts, game winnings and other coin sources do not count. Rewards are coins only; no Entry Vehicle or other prize item is included.",
                          style: TextStyle(
                            color: Color(0xFFFFD7B0),
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (boundMap == null) ...[
                    const SizedBox(height: 12),
                    _sectionTitle('Join an inviter'),
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                      ),
                    ),
                  ] else ...[
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
                          'ID ${boundMap['inviter_public_id'] ?? boundMap['invitation_code'] ?? ''}',
                          style: const TextStyle(color: Color(0xFFFFD7B0)),
                        ),
                        trailing: const Icon(
                          Icons.verified_rounded,
                          color: TinniPalette.gold,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _sectionTitle('Reward level'),
                  for (final tier in tiers) ...[
                    _tierCard(tier),
                    const SizedBox(height: 8),
                  ],

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
            color: header ? TinniPalette.gold : const Color(0xFFFFE6CB),
            fontSize: header ? 10 : 11,
            fontWeight: header ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      );

  Widget _inviteRecordsTable(List<Map<String, dynamic>> invited) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
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
            3: FixedColumnWidth(155),
            4: FixedColumnWidth(135),
            5: FixedColumnWidth(120),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFF7A1320)),
              children: [
                _inviteTableCell('DP / Name', header: true),
                _inviteTableCell('7-digit ID', header: true),
                _inviteTableCell('Invite Date & Time', header: true),
                _inviteTableCell('Coin Seller Coins', header: true),
                _inviteTableCell('Commission', header: true),
                _inviteTableCell('Invite Reward', header: true),
              ],
            ),
            for (final row in invited)
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFF5A0D17)),
                children: [
                  _inviteUserCell(row),
                  _inviteTableCell(
                    row['public_id']?.toString().trim().isNotEmpty == true
                        ? row['public_id'].toString()
                        : '-',
                  ),
                  _inviteTableCell(_formatDateTime(row['bound_at'])),
                  _inviteTableCell(
                    '${_formatCoins(row['received_coins'])} coins',
                  ),
                  _inviteTableCell(
                    '+${_formatCoins(row['commission_coins'])}',
                  ),
                  _inviteTableCell(
                    '+${_formatCoins(row['fixed_reward_coins'])}',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _tierCard(Map<String, dynamic> tier) {
    final level = tier['level'] ?? 0;
    final minInvites = tier['min_invites'] ?? 0;
    final minCoins = tier['min_received_coins'] ?? 0;
    final percent = _formatPercent(tier['rate_percent']);
    final active = (data?['current_level'] as num?)?.toInt() == (level as num?)?.toInt();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF8F1824) : const Color(0xFF65101B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? TinniPalette.gold : const Color(0x66FFD36B),
          width: active ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFFF9E1B),
            foregroundColor: const Color(0xFF7A160C),
            child: Text(
              'L$level',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_formatCoins(minCoins)} received + $minInvites invite${minInvites == 1 ? '' : 's'}',
              style: const TextStyle(
                color: Color(0xFFFFE6CB),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFBF36),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$percent% return',
              style: const TextStyle(
                color: Color(0xFF77120A),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF65101B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x66FFD36B)),
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
                  color: Color(0xFFFFE6CB),
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
