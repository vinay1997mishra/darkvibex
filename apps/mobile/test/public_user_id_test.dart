import 'package:darkvibex/utils/public_user_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy seven-digit public IDs display as eight digits without data migration', () {
    expect(formatPublicUserId('1000001'), '01000001');
    expect(formatPublicUserId('9100001'), '09100001');
  });

  test('new eight-digit public IDs remain unchanged', () {
    expect(formatPublicUserId('10000001'), '10000001');
    expect(formatPublicUserId('99999999'), '99999999');
  });

  test('hidden IDs stay hidden and internal IDs do not leak into UI', () {
    expect(formatPublicUserId('Hidden'), 'Hidden');
    expect(formatPublicUserId('db-internal-user-uuid'), '—');
    expect(formatPublicUserId(null), '—');
  });
}
