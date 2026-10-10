import 'package:flutter/material.dart';

import '../app/app_state.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text(
          'Messages',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        for (final item in state.messages)
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(item.name.characters.first)),
              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(item.preview, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: item.unread > 0
                  ? Badge(label: Text(item.unread.toString()))
                  : const Icon(Icons.chevron_right_rounded),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Chat with ${item.name}')),
              ),
            ),
          ),
      ],
    );
  }
}
