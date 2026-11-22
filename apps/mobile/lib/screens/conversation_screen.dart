import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_state.dart';
import '../infra/backend_api.dart';
import '../infra/local_message_cache.dart';
import '../widgets/cosmetic_store_previews.dart';
import '../widgets/gift_media_preview.dart';
import '../widgets/vip_chat_bubble.dart';
import 'direct_call_screen.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.state,
    required this.otherUserId,
    required this.otherName,
  });

  final AppState state;
  final String otherUserId;
  final String otherName;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final controller = TextEditingController();
  final List<Map<String, dynamic>> messages = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> envelopes = <Map<String, dynamic>>[];
  bool loading = true;
  bool uploadingImage = false;
  bool sendingEnvelope = false;
  bool sendingGift = false;
  bool isFriend = false;
  bool startingCall = false;
  bool callsMutedForPeer = false;

  List<Map<String, dynamic>> get _timeline {
    final items = <Map<String, dynamic>>[
      ...messages.map((item) => <String, dynamic>{...item, '_kind': 'message'}),
      ...envelopes.map((item) => <String, dynamic>{...item, '_kind': 'envelope'}),
    ];
    items.sort((a, b) => (int.tryParse(a['created_at']?.toString() ?? '') ?? 0)
        .compareTo(int.tryParse(b['created_at']?.toString() ?? '') ?? 0));
    return items;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String get _cacheKey =>
      LocalMessageCache.dmKey(widget.state.userId, widget.otherUserId);

  Future<void> _persistMessages() async {
    await LocalMessageCache.save(_cacheKey, messages);
  }

  Future<void> _load() async {
    final cached = await LocalMessageCache.load(_cacheKey);
    messages
      ..clear()
      ..addAll(cached);
    if (widget.state.backendConnected) {
      final rows = await widget.state.backend.messageThread(
        userId: widget.state.userId,
        otherUserId: widget.otherUserId,
      );
      // Local cache + server rows merged by id (server wins). The
      // cache is what keeps old messages visible: the server only
      // keeps the last 100 per thread past 45 days. Nothing here
      // prunes by age (Vinay, 2026-11-22: "App se delete nhi hone
      // chahiye") — the old VIP retention-days prune that deleted
      // messages from the app is gone.
      messages
        ..clear()
        ..addAll(LocalMessageCache.merge(messages, rows));
      final envelopeRows = await widget.state.backend.inboxRedEnvelopes(
        userId: widget.state.userId,
        otherUserId: widget.otherUserId,
      );
      envelopes
        ..clear()
        ..addAll(envelopeRows);
      final friends = await widget.state.backend.friends(
        userId: widget.state.userId,
      );
      isFriend = friends.any(
        (row) => row['id']?.toString() == widget.otherUserId,
      );
      // Call mute (Vinay, 2026-11-21): the per-person mute switch in
      // this chat reflects the server-side setting.
      await widget.state.refreshCallSettings(notify: false);
      callsMutedForPeer =
          widget.state.mutedCallUserIds.contains(widget.otherUserId);
    }
    await _persistMessages();
    if (!mounted) return;
    setState(() => loading = false);
  }

  bool _respondingToCpInvite = false;

  Future<void> _respondToCpInvite(bool accept) async {
    if (_respondingToCpInvite) return;
    setState(() => _respondingToCpInvite = true);
    try {
      final result = await widget.state.backend.cpRespond(
        userId: widget.state.userId,
        accept: accept,
      );
      if (!mounted) return;
      if (result?['ok'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result?['error']?.toString() ?? 'Could not respond to the invite',
            ),
          ),
        );
        return;
      }
      await _load();
    } finally {
      if (mounted) setState(() => _respondingToCpInvite = false);
    }
  }

  Widget _cpInviteCard(Map<String, dynamic> item, bool mine) {
    final kind = item['kind']?.toString() ?? '';
    final accepted = kind == 'cp_invite_accepted';
    final decided = kind != 'cp_invite';
    final partnerName = widget.otherName;
    final String title;
    final String subtitle;
    if (mine) {
      title = 'CP invite sent';
      subtitle = decided
          ? (accepted
              ? '$partnerName accepted your CP invite ❤️'
              : '$partnerName rejected your CP invite')
          : 'Waiting for $partnerName to respond…';
    } else {
      title = 'CP invite';
      subtitle = decided
          ? (accepted
              ? 'You accepted $partnerName\'s CP invite ❤️'
              : 'You rejected this CP invite')
          : '$partnerName wants to be your CP';
    }
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1530),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xAAFF5C8A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFFF5C8A),
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle),
          if (!mine && !decided) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _respondingToCpInvite
                      ? null
                      : () => _respondToCpInvite(false),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _respondingToCpInvite
                      ? null
                      : () => _respondToCpInvite(true),
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sendEnvelope() async {
    if (!isFriend) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Both users must follow each other first.')),
      );
      return;
    }
    if (sendingEnvelope || !widget.state.hasVipPrivilege('red_envelope')) return;
    final amountController = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send to ${widget.otherName}'),
        content: TextField(
          controller: amountController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Coins (you have ${widget.state.coins})'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            final value = int.tryParse(amountController.text.trim());
            if (value == null || value < 1 || value > widget.state.coins) return;
            Navigator.pop(context, value);
          }, child: const Text('Send envelope')),
        ],
      ),
    );
    amountController.dispose();
    if (amount == null || !mounted) return;
    setState(() => sendingEnvelope = true);
    Map<String, dynamic>? result;
    try {
      result = await widget.state.backend.sendInboxRedEnvelope(
        senderUserId: widget.state.userId,
        receiverUserId: widget.otherUserId,
        amount: amount,
      );
    } catch (_) {
      result = null;
    } finally {
      if (mounted) setState(() => sendingEnvelope = false);
    }
    if (!mounted) return;
    if (result?['ok'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Red envelope could not be sent. Check VIP6 and coin balance.')));
      return;
    }
    await widget.state.refreshWallet();
    await _load();
  }

  Future<void> _claimEnvelope(String envelopeId) async {
    Map<String, dynamic>? result;
    try {
      result = await widget.state.backend.claimInboxRedEnvelope(userId: widget.state.userId, envelopeId: envelopeId);
    } catch (_) {
      result = null;
    }
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not claim the envelope. Please try again.')));
      return;
    }
    if (result['ok'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This envelope has expired or was already opened.')));
      return;
    }
    await widget.state.refreshWallet();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You received ${result['amount'] ?? 0} coins')));
  }

  Future<void> _send() async {
    if (!isFriend) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Both users must follow each other before messaging.')),
      );
      return;
    }
    final text = controller.text.trim();
    if (text.isEmpty) return;

    // Offline means not sent (full-app audit 2026-11-20): the old
    // offline branch added the message to the local list and persisted
    // it, so it looked sent but was never delivered and never retried.
    // The text stays in the composer so nothing is lost.
    if (!widget.state.backendConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are offline. Connect to send messages.')),
      );
      return;
    }
    bool ok;
    String? sendError;
    try {
      final result = await widget.state.backend.sendDirectMessageResult(
        senderUserId: widget.state.userId,
        receiverUserId: widget.otherUserId,
        text: text,
      );
      ok = result?['ok'] == true;
      sendError = result?['error']?.toString();
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      if (!mounted) return;
      // Strong security (Vinay, 2026-11-22): the server blocks
      // gaaliyan, porn, political content and other apps' names.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sendError == 'content_blocked'
                ? 'Ye message nahi bheja ja sakta — isme mana kiya hua shabd hai.'
                : 'Message could not be sent',
          ),
        ),
      );
      return;
    }

    controller.clear();
    await _load();
    await widget.state.refreshInbox();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _sendImage() async {
    if (!isFriend) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photos can only be sent to mutual friends.')),
      );
      return;
    }
    if (!widget.state.backendConnected || uploadingImage) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.pop(sheetContext, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Gallery'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pop(sheetContext, ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text('Camera'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (file == null) return;
    final ext = file.name.split('.').last.toLowerCase();
    final type = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => null,
    };
    if (type == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a JPG, PNG or WebP image')),
        );
      }
      return;
    }
    setState(() => uploadingImage = true);
    try {
      final key = 'messages/${widget.state.userId}/${DateTime.now().microsecondsSinceEpoch}.${ext == 'jpeg' ? 'jpg' : ext}';
      final uploaded = await widget.state.backend.uploadImage(
        key: key,
        bytes: await file.readAsBytes(),
        contentType: type,
      );
      if (uploaded == null) throw StateError('upload_failed');
      final sent = await widget.state.backend.sendDirectMessage(
        senderUserId: widget.state.userId,
        receiverUserId: widget.otherUserId,
        text: '',
        imageKey: uploaded,
      );
      if (!sent) throw StateError('message_failed');
      await _load();
      await widget.state.refreshInbox();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo could not be sent')),
        );
      }
    } finally {
      if (mounted) setState(() => uploadingImage = false);
    }
  }

  // DM gift (Vinay, 2026-11-21): pic and gift both send from inside the
  // 1-to-1 DM chat. The pic button already existed; this adds the gift
  // button next to it. The gift goes to the DM partner with no room, and
  // the server writes a kind='gift' DM row so it shows in the thread.
  Future<void> _sendGift() async {
    if (!isFriend) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gifts can only be sent to mutual friends.')),
      );
      return;
    }
    if (!widget.state.backendConnected || sendingGift) return;
    List<Map<String, dynamic>> gifts = const <Map<String, dynamic>>[];
    try {
      gifts = await widget.state.backend.giftCatalog(userId: widget.state.userId);
    } catch (_) {
      gifts = const <Map<String, dynamic>>[];
    }
    if (!mounted) return;
    if (gifts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No gifts available right now.')),
      );
      return;
    }
    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _DmGiftPicker(
        gifts: gifts,
        receiverName: widget.otherName,
        coins: widget.state.coins,
        backend: widget.state.backend,
      ),
    );
    if (chosen == null || !mounted) return;
    final giftId = chosen['id']?.toString() ?? '';
    final cost = int.tryParse(chosen['coin_cost']?.toString() ?? '') ?? 0;
    if (giftId.isEmpty || cost <= 0) return;
    if (cost > widget.state.coins) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins for this gift.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Send ${chosen['name'] ?? 'gift'}?'),
        content: Text('Send to ${widget.otherName} for $cost coins?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send gift'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => sendingGift = true);
    Map<String, dynamic>? result;
    try {
      result = await widget.state.backend.sendGift(
        senderUserId: widget.state.userId,
        receiverUserId: widget.otherUserId,
        giftId: giftId,
        coinCost: cost,
      );
    } catch (_) {
      result = null;
    } finally {
      if (mounted) setState(() => sendingGift = false);
    }
    if (!mounted) return;
    if (result?['ok'] != true) {
      final error = result?['error']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            switch (error) {
              'friends_required' => 'Both users must be friends before gifting.',
              'insufficient_coins' => 'Not enough coins for this gift.',
              'vip_required' => 'This gift needs a higher VIP level.',
              'gifts_disabled' => 'Gifts are disabled.',
              _ => 'Gift could not be sent.',
            },
          ),
        ),
      );
      return;
    }
    await widget.state.refreshWallet();
    await _load();
    await widget.state.refreshInbox();
    // Lucky win (Vinay, 2026-11-22): a Lucky DM gift can win the sender
    // coins too — the win is in the send response.
    final dmWinCoins =
        int.tryParse(result?['lucky_win_coins']?.toString() ?? '') ?? 0;
    if (dmWinCoins > 0 && mounted) {
      final dmMultiplier =
          int.tryParse(result?['lucky_multiplier']?.toString() ?? '') ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🎉 Lucky win! You won $dmWinCoins coins (${dmMultiplier}×)!',
          ),
        ),
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _startCall() async {
    if (!isFriend || startingCall || !widget.state.backendConnected) return;
    setState(() => startingCall = true);
    final value = await widget.state.backend.startDirectCall(
      userId: widget.state.userId,
      receiverUserId: widget.otherUserId,
    );
    if (!mounted) return;
    setState(() => startingCall = false);
    final raw = value?['call'];
    if (value?['ok'] != true || raw is! Map) {
      final error = value?['error']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            switch (error) {
              'friends_required' => 'Both users must be friends before calling.',
              'call_muted' => 'This user has muted calls.',
              'user_busy' => 'This user is busy on another call.',
              _ => 'Call could not be started.',
            },
          ),
        ),
      );
      return;
    }
    final call = Map<String, dynamic>.from(raw);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DirectCallScreen(
          state: widget.state,
          callId: call['id']?.toString() ?? '',
          peerName: widget.otherName,
          initialState: call['state']?.toString() ?? 'ringing',
        ),
      ),
    );
  }

  Future<void> _toggleMuteCalls() async {
    final muting = !callsMutedForPeer;
    final ok = muting
        ? await widget.state.muteCallUser(widget.otherUserId)
        : await widget.state.unmuteCallUser(widget.otherUserId);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call mute setting could not be saved')),
      );
      return;
    }
    setState(() => callsMutedForPeer = muting);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherName),
        actions: [
          if (isFriend)
            IconButton(
              tooltip: 'Call',
              onPressed: startingCall ? null : _startCall,
              icon: startingCall
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.call_rounded),
            ),
          if (isFriend)
            PopupMenuButton<String>(
              tooltip: 'Chat options',
              onSelected: (value) async {
                if (value == 'mute_calls') await _toggleMuteCalls();
              },
              itemBuilder: (_) => [
                PopupMenuItem<String>(
                  value: 'mute_calls',
                  child: Text(
                    callsMutedForPeer ? 'Unmute calls' : 'Mute calls',
                  ),
                ),
              ],
            ),
          if (widget.state.hasVipPrivilege('red_envelope'))
            IconButton(
              tooltip: 'Send red envelope',
              onPressed: !isFriend || sendingEnvelope ? null : _sendEnvelope,
              icon: sendingEnvelope ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.redeem_rounded, color: Color(0xFFFF7070)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty && envelopes.isEmpty
                    ? const Center(child: Text('Start a conversation'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _timeline.length,
                        itemBuilder: (context, index) {
                          final item = _timeline[index];
                          if (item['_kind'] == 'envelope') {
                            final mine = item['sender_user_id']?.toString() == widget.state.userId;
                            final expiresAt = int.tryParse(item['expires_at']?.toString() ?? '') ?? 0;
                            final canClaim = !mine && item['status'] == 'open' && expiresAt > DateTime.now().millisecondsSinceEpoch;
                            final claimed = item['claimed_by_me'] == true || item['status'] == 'claimed';
                            return Align(
                              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                              child: Card(
                                color: const Color(0xFF8B202B),
                                child: SizedBox(width: 230, child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    const Icon(Icons.redeem_rounded, color: Color(0xFF50D8FF), size: 30),
                                    const SizedBox(height: 6),
                                    Text(mine ? 'Red envelope sent' : 'Red envelope from ${item['sender_name'] ?? widget.otherName}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                    Text(mine
                                        ? '${item['amount'] ?? 0} coins · ${item['status'] == 'expired' ? 'refunded' : _expiry(expiresAt)}'
                                        : claimed
                                            ? '${item['amount'] ?? 0} coins received'
                                            : 'Open within 24 hours'),
                                    if (canClaim) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => _claimEnvelope(item['id'].toString()), child: const Text('Open'))),
                                    if (!mine && item['status'] == 'expired') const Text('Expired · sender refunded'),
                                  ]),
                                )),
                              ),
                            );
                          }
                          // DM gift (Vinay, 2026-11-21): a room-less gift
                          // writes a kind='gift' DM row, rendered as a gold
                          // gift card in the thread for both sides.
                          if (item['kind']?.toString() == 'gift') {
                            final mine = item['sender_user_id']?.toString() ==
                                widget.state.userId;
                            return Align(
                              alignment: mine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 7),
                                child: Container(
                                  constraints:
                                      const BoxConstraints(maxWidth: 300),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x664B3511),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xAAFFD36A),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.card_giftcard_rounded,
                                        color: Color(0xFFFFD36A),
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          item['text']?.toString() ??
                                              '🎁 Gift',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                          // CP invite message (Vinay, 2026-11-20): the
                          // invite stays permanently in the DM chat. Its
                          // kind records the verdict, so Accept/Reject can
                          // be chosen only once per invite — a later
                          // re-invite is a new message with fresh buttons.
                          if ((item['kind']?.toString() ?? '')
                              .startsWith('cp_invite')) {
                            final mine = item['sender_user_id']?.toString() ==
                                widget.state.userId;
                            return Align(
                              alignment: mine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 7),
                                child: _cpInviteCard(item, mine),
                              ),
                            );
                          }
                          final mine =
                              item['sender_user_id']?.toString() == widget.state.userId;
                          final bubbleId = mine
                              ? widget.state.activeCosmetic('bubble')
                              : item['active_bubble_id']?.toString();
                          final bubbleAssetKey =
                              item['active_bubble_asset_key']?.toString().trim() ?? '';
                          final hasStoreBubble =
                              (bubbleId != null && bubbleId.isNotEmpty) ||
                              bubbleAssetKey.isNotEmpty;
                          final effectiveBubbleId = bubbleId?.isNotEmpty == true
                              ? bubbleId!
                              : 'bubble-dream';
                          final hasVipBubble =
                              mine && widget.state.hasVipPrivilege('chat_bubble');
                          final messageContent = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item['image_key']?.toString().isNotEmpty == true)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    widget.state.backend.fileUrl(item['image_key'].toString()),
                                    headers: widget.state.sessionToken == null
                                        ? const <String, String>{}
                                        : <String, String>{'Authorization': 'Bearer ${widget.state.sessionToken}'},
                                    width: 204,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox(
                                      width: 204,
                                      height: 120,
                                      child: Center(child: Icon(Icons.broken_image_outlined)),
                                    ),
                                  ),
                                ),
                              if (item['text']?.toString().isNotEmpty == true)
                                hasStoreBubble
                                    ? BubbleChatText(text: item['text'].toString())
                                    : Text(
                                        item['text'].toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                            ],
                          );
                          final messageBubble = hasStoreBubble
                              ? bubbleAssetKey.isNotEmpty
                                  // Custom uploaded bubble art supplies its own
                                  // outline: show it as before.
                                  ? StretchableCosmeticBubble(
                                      styleId: effectiveBubbleId,
                                      assetImageUrl: widget.state.backend
                                          .fileUrl(bubbleAssetKey),
                                      assetImageHeaders:
                                          widget.state.backend.fileHeaders,
                                      maxWidth: 292,
                                      minWidth: 100,
                                      minHeight: 44,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 44,
                                        vertical: 10,
                                      ),
                                      child: messageContent,
                                    )
                                  : VipChatBubble(
                                      styleId: effectiveBubbleId,
                                      maxWidth: 292,
                                      minWidth: 100,
                                      minHeight: 44,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 44,
                                        vertical: 10,
                                      ),
                                      child: messageContent,
                                    )
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  constraints: const BoxConstraints(maxWidth: 300),
                                  decoration: BoxDecoration(
                                    color: mine
                                        ? (hasVipBubble
                                            ? const Color(0x664B3511)
                                            : const Color(0x33FFD36A))
                                        : Colors.white10,
                                    borderRadius: BorderRadius.circular(16),
                                    border: hasVipBubble
                                        ? Border.all(
                                            color: const Color(0xAAFFD36A),
                                          )
                                        : null,
                                    boxShadow: hasVipBubble
                                        ? const <BoxShadow>[
                                            BoxShadow(
                                              color: Color(0x33FFD36A),
                                              blurRadius: 10,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: messageContent,
                                );
                          return Align(
                            alignment:
                                mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: messageBubble,
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: !isFriend || uploadingImage ? null : _sendImage,
                    tooltip: 'Share photo',
                    icon: uploadingImage
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.image_rounded),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: !isFriend || sendingGift ? null : _sendGift,
                    tooltip: 'Send gift',
                    icon: sendingGift
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.card_giftcard_rounded),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: isFriend,
                      maxLength: 1000,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: isFriend
                            ? 'Message…'
                            : 'Mutual follow required',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: isFriend ? _send : null,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _expiry(int expiresAt) {
  final left = expiresAt - DateTime.now().millisecondsSinceEpoch;
  if (left <= 0) return 'expired';
  final hours = left ~/ 3600000;
  final minutes = (left % 3600000) ~/ 60000;
  return 'expires in ${hours}h ${minutes}m';
}

// DM gift picker (Vinay, 2026-11-21): the same 6 categories as the room
// gift panel (Normal, Lucky, CP, Country, Luxury, Backpack). Tapping a
// gift returns it to the DM screen, which confirms and sends it.
class _DmGiftPicker extends StatefulWidget {
  const _DmGiftPicker({
    required this.gifts,
    required this.receiverName,
    required this.coins,
    required this.backend,
  });

  final List<Map<String, dynamic>> gifts;
  final String receiverName;
  final int coins;
  final BackendApi backend;

  @override
  State<_DmGiftPicker> createState() => _DmGiftPickerState();
}

class _DmGiftPickerState extends State<_DmGiftPicker> {
  static const _categories = <String>[
    'Normal',
    'Lucky',
    'CP',
    'Country',
    'Luxury',
    'Backpack',
  ];

  String _selectedCategory = 'Normal';

  String _giftCategory(Map<String, dynamic> item) {
    final raw = (item['category'] ?? item['gift_category'] ?? item['type'] ?? '')
        .toString()
        .toLowerCase();
    return raw.replaceAll('-', '').replaceAll('_', '').replaceAll(' ', '');
  }

  List<Map<String, dynamic>> get _visibleGifts {
    return widget.gifts.where((item) {
      final category = _giftCategory(item);
      switch (_selectedCategory) {
        case 'Lucky':
          return category == 'lucky';
        case 'CP':
          return category == 'cp' || category.contains('couple');
        case 'Country':
          return category == 'country';
        case 'Luxury':
          return category == 'luxury';
        case 'Backpack':
          return category == 'backpack';
        case 'Normal':
        default:
          return category.isEmpty ||
              category == 'normal' ||
              category == 'gift' ||
              !const <String>{
                'lucky',
                'cp',
                'couple',
                'country',
                'luxury',
                'backpack',
              }.contains(category);
      }
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleGifts;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Send a gift to ${widget.receiverName}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.coins} coins',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final category in _categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: _selectedCategory == category,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = category),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: visible.isEmpty
                    ? const Center(child: Text('No gifts in this category'))
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final gift = visible[index];
                          final cost = int.tryParse(
                                gift['coin_cost']?.toString() ?? '',
                              ) ??
                              0;
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.pop(context, gift),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 4,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Glass gifts (Vinay, 2026-11-22): show
                                  // the 3D glass image when the gift has
                                  // one (asset_key); the emoji is only the
                                  // fallback for gifts without an image.
                                  SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: GiftMediaPreview(
                                      backend: widget.backend,
                                      videoKey: gift['video_key']
                                              ?.toString() ??
                                          '',
                                      assetKey: gift['asset_key']
                                              ?.toString() ??
                                          '',
                                      glbKey:
                                          gift['glb_key']?.toString() ?? '',
                                      emoji:
                                          gift['emoji']?.toString() ?? '🎁',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    gift['name']?.toString() ??
                                        gift['id']?.toString() ??
                                        'Gift',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$cost',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFFFD36A),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
