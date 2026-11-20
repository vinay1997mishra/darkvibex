import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// CP invite message + pop-up (Vinay, 2026-11-20): the invite shows in the
// DM chat permanently with Accept/Reject (chosen once per invite), and a
// pop-up appears the moment it arrives — or on coming online when it was
// sent while the receiver was away.
void main() {
  test('CP request writes a cp_invite DM and respond records its verdict', () {
    final social = File('../worker/src/tinni_social.js').readAsStringSync();
    expect(social, contains("kind TEXT NOT NULL DEFAULT 'text'"));
    expect(
      social,
      contains('"cp_invite"'),
    );
    expect(social, contains('CP invite from'));
    expect(
      social,
      contains(
        '"INSERT INTO direct_messages(id,sender_user_id,receiver_user_id,kind,text,created_at,read_at) VALUES(?,?,?,?,?,?,NULL)"',
      ),
    );
    expect(social, contains('"cp_invite_accepted"'));
    expect(social, contains('"cp_invite_rejected"'));
    expect(
      social,
      contains(
        '"UPDATE direct_messages SET kind=? WHERE kind=\'cp_invite\' AND sender_user_id=? AND receiver_user_id=?"',
      ),
    );
  });

  test('DM thread returns the message kind so the app can render the card',
      () {
    final worker = File('../worker/src/index.js').readAsStringSync();
    expect(
      worker,
      contains(
        'SELECT m.id, m.sender_user_id, m.receiver_user_id, m.kind, m.text, m.created_at, m.read_at,',
      ),
    );
  });

  test('DM thread renders a CP invite card with one-time Accept/Reject', () {
    final conversation =
        File('lib/screens/conversation_screen.dart').readAsStringSync();
    expect(conversation, contains("_cpInviteCard(item, mine)"));
    expect(conversation, contains(".startsWith('cp_invite')"));
    expect(conversation, contains("kind == 'cp_invite_accepted'"));
    expect(conversation, contains("kind != 'cp_invite'"));
    expect(conversation, contains("child: const Text('Reject')"));
    expect(conversation, contains("child: const Text('Accept')"));
    expect(conversation, contains('_respondToCpInvite(false)'));
    expect(conversation, contains('_respondToCpInvite(true)'));
    expect(conversation, contains('_respondingToCpInvite'));
    expect(conversation, contains('widget.state.backend.cpRespond'));
    expect(conversation, contains('You accepted'));
    expect(conversation, contains('You rejected this CP invite'));
    expect(conversation, contains('Waiting for'));
  });

  test('home shell pops the CP invite up at once and on coming online', () {
    final shell = File('lib/screens/home_shell.dart').readAsStringSync();
    expect(shell, contains('_checkCpInvite()'));
    expect(shell, contains('Timer.periodic('));
    expect(shell, contains('const Duration(seconds: 30)'));
    expect(shell, contains('didChangeAppLifecycleState'));
    expect(shell, contains('AppLifecycleState.resumed'));
    expect(shell, contains('WidgetsBindingObserver'));
    expect(shell, contains('_cpInvitesSeen'));
    expect(shell, contains("cp['state']?.toString() == 'pending'"));
    expect(shell, contains("cp['requested_by']?.toString() != widget.state.userId"));
    expect(shell, contains('wants to be your CP'));
    expect(shell, contains("child: const Text('Reject')"));
    expect(shell, contains("child: const Text('Accept')"));
    expect(shell, contains('widget.state.backend.cpRespond'));
    expect(shell, contains('You are CP now'));
  });
}
