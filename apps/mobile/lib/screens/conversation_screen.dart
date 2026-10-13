import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_state.dart';
import '../vip/vip_policy.dart';
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
  bool isFriend = false;
  bool startingCall = false;

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

  String get _cacheKey => 'dvx_messages_${widget.state.userId}_${widget.otherUserId}';

  Future<void> _persistMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(messages));
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedText = prefs.getString(_cacheKey);
    if (cachedText != null) {
      try {
        final cached = jsonDecode(cachedText);
        if (cached is List) {
          messages
            ..clear()
            ..addAll(cached.whereType<Map>().map((row) => Map<String, dynamic>.from(row)));
        }
      } catch (_) {}
    }
    if (widget.state.backendConnected) {
      final rows = await widget.state.backend.messageThread(
        userId: widget.state.userId,
        otherUserId: widget.otherUserId,
      );
      final byId = <String, Map<String, dynamic>>{};
      for (final row in [...messages, ...rows]) {
        final id = row['id']?.toString();
        if (id != null && id.isNotEmpty) {
          byId[id] = row;
        } else {
          final key = '${row['sender_user_id']}|${row['receiver_user_id']}|${row['created_at']}|${row['text']}|${row['image_key']}';
          byId[key] = row;
        }
      }
      messages
        ..clear()
        ..addAll(byId.values)
        ..sort((a, b) => (int.tryParse(a['created_at']?.toString() ?? '') ?? 0)
            .compareTo(int.tryParse(b['created_at']?.toString() ?? '') ?? 0));
      final days = widget.state.vipIsActive && widget.state.vipLevel >= 5
          ? VipPolicy.messageRetentionDays(widget.state.vipLevel)
          : 0;
      if (days > 0) {
        final cutoff = DateTime.now().millisecondsSinceEpoch - days * 86400000;
        messages.removeWhere((row) => (int.tryParse(row['created_at']?.toString() ?? '') ?? 0) < cutoff);
      }
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
    }
    await _persistMessages();
    if (!mounted) return;
    setState(() => loading = false);
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
    final result = await widget.state.backend.sendInboxRedEnvelope(
      senderUserId: widget.state.userId,
      receiverUserId: widget.otherUserId,
      amount: amount,
    );
    if (!mounted) return;
    setState(() => sendingEnvelope = false);
    if (result?['ok'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Red envelope could not be sent. Check VIP6 and coin balance.')));
      return;
    }
    await widget.state.refreshWallet();
    await _load();
  }

  Future<void> _claimEnvelope(String envelopeId) async {
    final result = await widget.state.backend.claimInboxRedEnvelope(userId: widget.state.userId, envelopeId: envelopeId);
    if (!mounted) return;
    if (result?['ok'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This envelope has expired or was already opened.')));
      return;
    }
    await widget.state.refreshWallet();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You received ${result?['amount'] ?? 0} coins')));
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

    if (widget.state.backendConnected) {
      final ok = await widget.state.backend.sendDirectMessage(
        senderUserId: widget.state.userId,
        receiverUserId: widget.otherUserId,
        text: text,
      );
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message could not be sent')),
        );
        return;
      }
    }

    controller.clear();
    if (widget.state.backendConnected) {
      await _load();
    } else {
      messages.add(<String, dynamic>{
        'sender_user_id': widget.state.userId,
        'receiver_user_id': widget.otherUserId,
        'text': text,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      await _persistMessages();
    }
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
                                    const Icon(Icons.redeem_rounded, color: Color(0xFFFFD36A), size: 30),
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
                          final mine =
                              item['sender_user_id']?.toString() == widget.state.userId;
                          return Align(
                            alignment:
                                mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              constraints: const BoxConstraints(maxWidth: 300),
                              decoration: BoxDecoration(
                                color: mine
                                    ? (widget.state.hasVipPrivilege('chat_bubble')
                                        ? const Color(0x664B3511)
                                        : const Color(0x33FFD36A))
                                    : Colors.white10,
                                borderRadius: BorderRadius.circular(16),
                                border: mine &&
                                        widget.state.hasVipPrivilege('chat_bubble')
                                    ? Border.all(
                                        color: const Color(0xAAFFD36A),
                                      )
                                    : null,
                                boxShadow: mine &&
                                        widget.state.hasVipPrivilege('chat_bubble')
                                    ? const [
                                        BoxShadow(
                                          color: Color(0x33FFD36A),
                                          blurRadius: 10,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
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
                                        width: 220,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const SizedBox(
                                          width: 220,
                                          height: 120,
                                          child: Center(child: Icon(Icons.broken_image_outlined)),
                                        ),
                                      ),
                                    ),
                                  if (item['text']?.toString().isNotEmpty == true)
                                    Text(item['text'].toString()),
                                ],
                              ),
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
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: isFriend,
                      maxLength: 1000,
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
