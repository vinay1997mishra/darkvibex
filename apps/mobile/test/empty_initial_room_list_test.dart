import 'package:darkvibex/app/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live room list starts empty instead of showing demo rooms', () {
    final state = AppState();
    expect(state.rooms, isEmpty);
    state.dispose();
  });
}
