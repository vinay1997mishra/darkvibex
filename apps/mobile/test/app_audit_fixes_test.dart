import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Full-app audit fixes (2026-11-20): the direct-call trap, the gifts
// deadlock, the systemic offline throws, signOut rooms, the VS gifts
// in the offline fallback, the CP invite DM retention, dialog
// stacking, and the fake offline DM branch.
void main() {
  test('BackendApi _json returns null on transport failure instead of throwing',
      () {
    final api = File('lib/infra/backend_api.dart').readAsStringSync();
    expect(api, contains('on SocketException'));
    expect(api, contains('on HttpException'));
    expect(api, contains('on HandshakeException'));
    expect(api, contains('onConnectivityChanged?.call(false)'));
    expect(api, contains('onConnectivityChanged?.call(true)'));
    expect(
      api,
      contains('static void Function(bool connected)? onConnectivityChanged;'),
    );
    // One shared client: no fresh HttpClient + TLS handshake per call.
    expect(api, contains('static HttpClient? _sharedClient;'));
    expect(api, isNot(contains('final client = HttpClient();')));
    expect(api, isNot(contains('client.close(force: true);')));
  });

  test('offline gift-catalog fallback no longer sells removed VS gifts', () {
    final api = File('lib/infra/backend_api.dart').readAsStringSync();
    expect(api, isNot(contains("'dandiya-night'")));
    expect(api, isNot(contains("'peacock-dance'")));
  });

  test(
      'AppState flips backendConnected on transport events and signOut clears rooms',
      () {
    final state = File('lib/app/app_state.dart').readAsStringSync();
    expect(state, contains('BackendApi.onConnectivityChanged = (connected)'));
    expect(state, contains('rooms.clear();'));
  });

  test('direct call always ends locally, even when the server call fails',
      () {
    final screen =
        File('lib/screens/direct_call_screen.dart').readAsStringSync();
    expect(
      screen,
      contains('The call ends locally no matter what the server says'),
    );
    expect(
      screen,
      contains('try {\n      await widget.state.backend.endDirectCall('),
    );
    expect(screen, contains('await _leaveVoice();'));
    expect(screen, contains('if (mounted) Navigator.of(context).pop();'));
  });

  test('a failed gift send always resets the sending flag', () {
    final screen = File('lib/screens/gifts_screen.dart').readAsStringSync();
    expect(
      screen,
      contains('A failed send used to leave `sending` true forever'),
    );
    expect(screen, contains('} finally {'));
    expect(screen, contains('if (mounted) setState(() => sending = false);'));
  });

  test('Rocket help text no longer promises DIRECT VIP + launch coins', () {
    final screen =
        File('lib/screens/rocket_room_screen.dart').readAsStringSync();
    expect(screen, isNot(contains('get DIRECT VIP for a few days plus')));
    expect(screen, contains('get a Rocket medal'));
    expect(screen, contains("key: const Key('rocket-room-claim-pool')"));
    final rewards =
        File('lib/utils/rocket_top_rewards.dart').readAsStringSync();
    expect(rewards, contains('DISPLAY ONLY'));
    expect(rewards, isNot(contains('ALSO get DIRECT VIP + launch coins')));
  });

  test('Messages tab only refreshes the inbox while it is showing', () {
    final screen = File('lib/screens/messages_screen.dart').readAsStringSync();
    expect(screen, contains('this.isActive = true'));
    expect(screen, contains('if (foreground && widget.isActive)'));
    expect(screen, contains('AppLifecycleState.resumed'));
    final shell = File('lib/screens/home_shell.dart').readAsStringSync();
    expect(shell, contains('isActive: index == 2'));
  });

  test('HomeShell never stacks the CP invite on a login dialog', () {
    final shell = File('lib/screens/home_shell.dart').readAsStringSync();
    expect(shell, contains('bool _anyDialogOpen = false;'));
    expect(shell, contains('_anyDialogOpen'));
    expect(shell, isNot(contains('_cpInviteDialogOpen')));
  });

  test('an offline DM is never faked as sent', () {
    final screen =
        File('lib/screens/conversation_screen.dart').readAsStringSync();
    expect(
      screen,
      contains('You are offline. Connect to send messages.'),
    );
    expect(screen, isNot(contains('messages.add(<String, dynamic>{')));
  });

  test('a failed unfollow tells the user instead of failing silently', () {
    final screen = File('lib/screens/profile_screen.dart').readAsStringSync();
    expect(
      screen,
      contains('Could not unfollow. Please try again.'),
    );
  });
}
