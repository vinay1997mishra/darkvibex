import 'package:darkvibex/vip/role_tag_assets.dart';
import 'package:darkvibex/widgets/role_tag_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('role tag URLs map every slug to its R2 PNG', () {
    const base =
        'https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev';
    expect(kRoleTagSlugs, hasLength(6));
    for (final slug in kRoleTagSlugs) {
      expect(roleTagUrlForSlug(slug), '$base/tags/role-$slug.png');
    }
    expect(kRoleTagLabels['coin-seller'], 'Coin Seller');
    expect(kRoleTagLabels['cs-leader'], 'CS Leader');
    expect(kRoleTagLabels['official'], 'Official');
  });

  test('role tag mapping is case/whitespace tolerant, unknown slugs get '
      'no tag', () {
    expect(roleTagUrlForSlug('  Coin-Seller '),
        roleTagUrlForSlug('coin-seller'));
    expect(roleTagUrlForSlug('MERCHANT'), roleTagUrlForSlug('merchant'));
    expect(roleTagUrlForSlug(null), isNull);
    expect(roleTagUrlForSlug(''), isNull);
    expect(roleTagUrlForSlug('coin_seller'), isNull);
    expect(roleTagUrlForSlug('user'), isNull);
    expect(roleTagUrlForSlug('super_admin'), isNull);
    expect(roleTagUrlForSlug('platform_owner'), isNull);
  });

  testWidgets('role tag renders an Image when a tag is assigned',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RoleTagImage(roleTag: 'coin-seller', fontSize: 12),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).height, 18);
  });

  testWidgets('role tag renders nothing when no tag is assigned',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RoleTagImage(roleTag: null, fontSize: 12),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('role tag renders nothing for an unknown slug',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RoleTagImage(roleTag: 'user', fontSize: 12),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsNothing);
  });
}
