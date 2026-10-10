import 'dart:convert';
import 'dart:io';

class BackendApi {
  const BackendApi();

  static const String origin = String.fromEnvironment(
    'DARKVIBEX_API_ORIGIN',
    defaultValue: '',
  );

  bool get configured => origin.trim().isNotEmpty;

  Future<Map<String, dynamic>?> health() async {
    if (!configured) return null;
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('$origin/health'));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final value = jsonDecode(text);
      return value is Map<String, dynamic> ? value : null;
    } finally {
      client.close(force: true);
    }
  }

  Future<List<Map<String, dynamic>>> listRooms() async {
    if (!configured) return const <Map<String, dynamic>>[];
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('$origin/api/rooms'));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) return const <Map<String, dynamic>>[];
      final value = jsonDecode(text);
      if (value is! Map<String, dynamic>) return const <Map<String, dynamic>>[];
      final rows = value['rooms'];
      if (rows is! List) return const <Map<String, dynamic>>[];
      return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
    } finally {
      client.close(force: true);
    }
  }
}
