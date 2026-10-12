import 'package:flutter/material.dart';

import '../app/app_state.dart';

class VipSupportScreen extends StatefulWidget {
  const VipSupportScreen({super.key, required this.state});
  final AppState state;

  @override
  State<VipSupportScreen> createState() => _VipSupportScreenState();
}

class _VipSupportScreenState extends State<VipSupportScreen> {
  late Future<List<Map<String, dynamic>>> _tickets;

  @override
  void initState() {
    super.initState();
    _tickets = widget.state.backend.vipSupportTickets(userId: widget.state.userId);
  }

  void _reload() => setState(() => _tickets = widget.state.backend.vipSupportTickets(userId: widget.state.userId));

  Future<void> _newTicket() async {
    final subject = TextEditingController();
    final message = TextEditingController();
    final values = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New VIP support ticket'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: subject, maxLength: 100, decoration: const InputDecoration(labelText: 'Subject')),
            const SizedBox(height: 8),
            TextField(controller: message, minLines: 3, maxLines: 6, maxLength: 2000, decoration: const InputDecoration(labelText: 'How can we help?')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            final s = subject.text.trim();
            final m = message.text.trim();
            if (s.isEmpty || m.isEmpty) return;
            Navigator.pop(context, (s, m));
          }, child: const Text('Submit')),
        ],
      ),
    );
    subject.dispose();
    message.dispose();
    if (values == null || !mounted) return;
    final id = await widget.state.backend.createVipSupportTicket(userId: widget.state.userId, subject: values.$1, message: values.$2);
    if (!mounted) return;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket could not be submitted. Check your connection and VIP status.')));
      return;
    }
    _reload();
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _VipTicketThread(state: widget.state, ticketId: id)));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('VIP Customer Service'), actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: _newTicket, icon: const Icon(Icons.add), label: const Text('New ticket')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _tickets,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return const Center(child: Text('Could not load support tickets'));
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) return const Center(child: Text('No support tickets yet'));
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final ticket = rows[index];
              final open = ticket['status'] == 'open';
              return Card(child: ListTile(
                leading: Icon(open ? Icons.support_agent : Icons.check_circle_outline, color: open ? const Color(0xFFFFD36A) : null),
                title: Text(ticket['subject']?.toString() ?? 'Support ticket'),
                subtitle: Text('Updated ${_date(ticket['updated_at'])}'),
                trailing: Chip(label: Text(open ? 'Open' : 'Closed')),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _VipTicketThread(state: widget.state, ticketId: ticket['id'].toString())));
                  if (mounted) _reload();
                },
              ));
            },
          ),
        );
      },
    ),
  );
}

class _VipTicketThread extends StatefulWidget {
  const _VipTicketThread({required this.state, required this.ticketId});
  final AppState state;
  final String ticketId;

  @override
  State<_VipTicketThread> createState() => _VipTicketThreadState();
}

class _VipTicketThreadState extends State<_VipTicketThread> {
  late Future<Map<String, dynamic>?> _thread;
  final _reply = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _thread = widget.state.backend.vipSupportTicket(userId: widget.state.userId, ticketId: widget.ticketId);
  }

  @override
  void dispose() { _reply.dispose(); super.dispose(); }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await widget.state.backend.replyVipSupportTicket(userId: widget.state.userId, ticketId: widget.ticketId, message: text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) {
        _reply.clear();
        _thread = widget.state.backend.vipSupportTicket(userId: widget.state.userId, ticketId: widget.ticketId);
      }
    });
    if (!ok) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply could not be sent. The ticket may be closed.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Support conversation')),
    body: FutureBuilder<Map<String, dynamic>?>(
      future: _thread,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data;
        if (data == null) return const Center(child: Text('Ticket could not be loaded'));
        final ticket = data['ticket'] as Map<String, dynamic>? ?? const <String, dynamic>{};
        final messages = (data['messages'] as List? ?? const []).whereType<Map>().toList();
        final closed = ticket['status'] == 'closed';
        return Column(children: [
          ListTile(title: Text(ticket['subject']?.toString() ?? 'Ticket'), subtitle: Text(closed ? 'Closed' : 'Open with VIP support')),
          const Divider(height: 1),
          Expanded(child: ListView(padding: const EdgeInsets.all(16), children: messages.map((raw) {
            final message = Map<String, dynamic>.from(raw);
            final staff = message['sender_type'] == 'staff';
            return Align(alignment: staff ? Alignment.centerLeft : Alignment.centerRight, child: Container(
              constraints: const BoxConstraints(maxWidth: 340),
              margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: staff ? const Color(0xFF20212A) : const Color(0xFF4A3515), borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(staff ? 'VIP Support' : 'You', style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(message['body']?.toString() ?? '')]),
            ));
          }).toList())),
          if (closed)
            const SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('This ticket is closed.'),
              ),
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _reply,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        hintText: 'Write a reply',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ]),
              ),
            ),
        ]);
      },
    ),
  );
}

String _date(dynamic value) {
  final ms = int.tryParse(value?.toString() ?? '');
  if (ms == null) return 'recently';
  final date = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
  return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
