import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_state.dart';

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
  bool loading = true;
  bool uploadingImage = false;

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

  Future<void> _load() async {
    if (widget.state.backendConnected) {
      final rows = await widget.state.backend.messageThread(
        userId: widget.state.userId,
        otherUserId: widget.otherUserId,
      );
      messages
        ..clear()
        ..addAll(rows);
    }
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _send() async {
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
    messages.add(<String, dynamic>{
      'sender_user_id': widget.state.userId,
      'receiver_user_id': widget.otherUserId,
      'text': text,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await widget.state.refreshInbox();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _sendImage() async {
    if (!widget.state.backendConnected || uploadingImage) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
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
      messages.add(<String, dynamic>{
        'sender_user_id': widget.state.userId,
        'receiver_user_id': widget.otherUserId,
        'text': '',
        'image_key': uploaded,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherName)),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? const Center(child: Text('Start a conversation'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final item = messages[index];
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
                    onPressed: uploadingImage ? null : _sendImage,
                    tooltip: 'Share photo',
                    icon: uploadingImage
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.image_rounded),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: 'Message…',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
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
