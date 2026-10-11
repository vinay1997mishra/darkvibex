import 'package:flutter/material.dart';

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
    if (!mounted) return;
    setState(() {});
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
                              child: Text(item['text']?.toString() ?? ''),
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
