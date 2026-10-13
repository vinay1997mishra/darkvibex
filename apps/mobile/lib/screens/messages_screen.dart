import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';
import 'conversation_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => TinniBackground(
        child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          const Text(
            'Message',
            style: TextStyle(
              color: TinniPalette.gold,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          if (state.messages.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: Text('No messages yet')),
            ),
          for (final item in state.messages)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: TinniPanel(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: item.avatarKey == null
                      ? null
                      : NetworkImage(state.backend.fileUrl(item.avatarKey!), headers: state.backend.fileHeaders),
                  child: item.avatarKey == null
                      ? Text(item.name.isEmpty ? '?' : item.name.substring(0, 1))
                      : null,
                ),
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(item.preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: item.unread > 0
                    ? Badge(label: Text(item.unread.toString()))
                    : const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConversationScreen(
                      state: state,
                      otherUserId: item.id,
                      otherName: item.name,
                    ),
                  ),
                ),
              ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}
