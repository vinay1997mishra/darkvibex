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

  test('owner-set IDs of any length 1–9 digits show as they are', () {
    // Mr. Wrong, 2026-11-24: even a single digit like "7".
    expect(formatPublicUserId('7'), '7');
    expect(formatPublicUserId('42'), '42');
    expect(formatPublicUserId('123456'), '123456');
    expect(formatPublicUserId('123456789'), '123456789');
  });

  test('zero and over-long IDs still fall back', () {
    expect(formatPublicUserId('0'), '—');
    expect(formatPublicUserId('000'), '—');
    expect(formatPublicUserId('1234567890'), '—');
    expect(formatPublicUserId('12a34'), '—');
  });

  test('hidden IDs stay hidden and internal IDs do not leak into UI', () {
    expect(formatPublicUserId('Hidden'), 'Hidden');
    expect(formatPublicUserId('db-internal-user-uuid'), '—');
    expect(formatPublicUserId(null), '—');
  });

  test('typed IDs for Block by ID keep digits only', () {
    expect(normalizePublicIdInput('07654001'), '07654001');
    expect(normalizePublicIdInput('ID 07654001'), '07654001');
    expect(normalizePublicIdInput('0765 4001'), '07654001');
    expect(normalizePublicIdInput(''), '');
  });
}
