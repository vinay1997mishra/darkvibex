import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Invite follow-up (Vinay, 2026-11-23): the enter-code box sits beside
// your own code in the Invite Method panel (not a separate section), and
// the invited-users table on the Share page shows a Recharge column and
// scrolls up/down inside a fixed-height box.
void main() {
  test('enter-code box lives in the Invite Method panel, no separate Join section',
      () {
    final screen =
        File('lib/screens/invite_share_screen.dart').readAsStringSync();
    expect(screen, contains('Have an invitation code?'));
    expect(screen, contains("controller: _codeController,"));
    // The old separate section is gone; the box is now inside the
    // Invite Method panel, shown while no inviter is bound.
    expect(screen, isNot(contains(" _sectionTitle('Join an inviter')")));
    expect(screen, isNot(contains('_sectionTitle(\'Join an inviter\')')));
  });

  test('invited-users table shows a Recharge column from the summary', () {
    final screen =
        File('lib/screens/invite_share_screen.dart').readAsStringSync();
    expect(screen, contains("_inviteTableCell('Recharge', header: true)"));
    expect(
      screen,
      contains("_formatDollars(row['total_recharge_usd_cents'])"),
    );
  });

  test('invited-users table scrolls up/down inside a fixed-height box', () {
    final screen =
        File('lib/screens/invite_share_screen.dart').readAsStringSync();
    expect(screen, contains('thumbVisibility: true'));
    expect(screen, contains('scrollDirection: Axis.vertical'));
    // 5 invites visible at a time (header + 5 rows), the rest scroll.
    expect(screen, contains('height: 272'));
    // The wide table keeps its horizontal scroll too.
    expect(screen, contains('scrollDirection: Axis.horizontal'));
  });

  test('enter-code box disappears 48 hours after the ID is created', () {
    final screen =
        File('lib/screens/invite_share_screen.dart').readAsStringSync();
    expect(screen, contains('_inviteWindowOpen'));
    expect(
      screen,
      contains('if (boundMap == null && _inviteWindowOpen) ...['),
    );
    expect(screen, contains('invite_window_expired'));
    expect(screen, contains('This device has already used an invite code.'));

    final shell = File('lib/screens/home_shell.dart').readAsStringSync();
    expect(shell, contains("summary['invite_window_open'] == false"));

    final service =
        File('lib/infra/invite_referral_service.dart').readAsStringSync();
    expect(service, contains("error == 'invite_window_expired'"));
    expect(service, contains("error == 'device_already_used_invite'"));
  });

  test('bind sends the device key so one device binds for one ID only', () {
    final api = File('lib/infra/backend_api.dart').readAsStringSync();
    expect(api, contains("'device_key': deviceKey!.trim()"));
  });
}
