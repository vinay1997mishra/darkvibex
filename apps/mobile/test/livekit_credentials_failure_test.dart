import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:darkvibex/infra/livekit_rtc.dart';
import 'package:darkvibex/infra/realtime.dart';

void main() {
  test('LiveKit credential failure leaves the adapter in a retryable failed state',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"ok":false,"error":"voice_not_configured"}');
      await request.response.close();
    });

    final adapter = LiveKitRtcAdapter(
      apiBase: Uri(
        scheme: 'http',
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
      ),
    );
    addTearDown(() async {
      adapter.dispose();
      await server.close(force: true);
    });

    await expectLater(
      adapter.join('test-room', 'test-user', authToken: 'test-session'),
      throwsA(isA<StateError>()),
    );
    expect(adapter.state, RtcConnectionState.failed);
  });
}
