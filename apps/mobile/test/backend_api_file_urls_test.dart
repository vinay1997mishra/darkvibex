import 'package:darkvibex/infra/backend_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const api = BackendApi();

  test('private user-info keys route to /api/user-files', () {
    expect(BackendApi.isPrivateUserFileKey('users/u123/dp/1.jpg'), isTrue);
    expect(
      BackendApi.isPrivateUserFileKey('users/u123/id-number/1.png'),
      isTrue,
    );
    expect(BackendApi.isPrivateUserFileKey('users/u123/sms/1.webp'), isTrue);
    expect(
      BackendApi.isPrivateUserFileKey('users/u123/misc/1.jpg'),
      isTrue,
    );
    expect(
      api.fileUrl('users/u123/dp/1731936000000.jpg'),
      '${BackendApi.origin}/api/user-files?key=users%2Fu123%2Fdp%2F1731936000000.jpg',
    );
    expect(
      api.userFileUrl('users/u123/id-number/1.jpg'),
      '${BackendApi.origin}/api/user-files?key=users%2Fu123%2Fid-number%2F1.jpg',
    );
  });

  test('public keys keep using /api/files', () {
    // Old public DP keys (users/<id>/avatar-...) stay on /api/files.
    expect(
      BackendApi.isPrivateUserFileKey('users/u123/avatar-1.jpg'),
      isFalse,
    );
    expect(
      api.fileUrl('users/u123/avatar-1.jpg'),
      '${BackendApi.origin}/api/files?key=users%2Fu123%2Favatar-1.jpg',
    );
    expect(
      BackendApi.isPrivateUserFileKey('vehicles/vip5-deer.mp4'),
      isFalse,
    );
    expect(
      api.fileUrl('vehicles/vip5-deer.mp4'),
      '${BackendApi.origin}/api/files?key=vehicles%2Fvip5-deer.mp4',
    );
    expect(BackendApi.isPrivateUserFileKey(''), isFalse);
    expect(BackendApi.isPrivateUserFileKey('users/u123/dp/'), isFalse);
  });
}
