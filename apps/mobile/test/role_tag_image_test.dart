import 'package:darkvibex/vip/role_tag_assets.dart';
import 'package:darkvibex/widgets/role_tag_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('role tag URLs map every role to its R2 PNG', () {
    const base =
        'https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev';
    expect(roleTagUrlForRole('coin_seller'),
        '$base/tags/role-coin-seller.png');
    expect(roleTagUrlForRole('merchant'), '$base/tags/role-merchant.png');
    expect(roleTagUrlForRole('platform_owner'),
        '$base/tags/role-official.png');
    expect(roleTagUrlForRole('admin'), '$base/tags/role-admin.png');
    expect(roleTagUrlForRole('customer_service'), '$base/tags/role-cs.png');
    expect(roleTagUrlForRole('cs'), '$base/tags/role-cs.png');
    expect(roleTagUrlForRole('cs_leader'), '$base/tags/role-cs-leader.png');
  });

  test('role tag mapping is case/whitespace tolerant, unknown roles get '
      'no tag', () {
    expect(roleTagUrlForRole('  Coin_Seller '),
        roleTagUrlForRole('coin_seller'));
    expect(roleTagUrlForRole('MERCHANT'), roleTagUrlForRole('merchant'));
    expect(roleTagUrlForRole(null), isNull);
    expect(roleTagUrlForRole(''), isNull);
    expect(roleTagUrlForRole('user'), isNull);
    expect(roleTagUrlForRole('super_admin'), isNull);
    expect(roleTagUrlForRole('room_owner'), isNull);
  });

  test('role tags are hidden by default (Vinay: in the app but not '
      'visible)', () {
    expect(kRoleTagsVisible, isFalse);
  });

  testWidgets('role tag renders nothing while hidden, even for a role '
      'that has a tag', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RoleTagImage(role: 'coin_seller', fontSize: 12),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('role tag renders nothing for a role without a tag',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RoleTagImage(role: 'user', fontSize: 12),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsNothing);
  });
}
