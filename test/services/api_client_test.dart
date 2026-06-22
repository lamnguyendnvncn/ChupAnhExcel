import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:chup_anh_excel/services/api_client.dart';
import 'package:chup_anh_excel/services/settings_store.dart';

void main() {
  test('fetchTasks parses JSON response', () async {
    final client = ApiClient(
      httpClient: _FakeClient(
        getHandler: (url, headers) {
          expect(headers?['Authorization'], 'Bearer test-token');
          return http.Response(
            '{"tasks":[{"id":"a","label":"A","instructions":"Do A"}]}',
            200,
          );
        },
      ),
    );

    final tasks = await client.fetchTasks(
      AppSettings(host: '100.64.0.1', port: 8787, token: 'test-token'),
    );

    expect(tasks.length, 1);
    expect(tasks.first.id, 'a');
    expect(tasks.first.label, 'A');
  });

  test('upload sends multipart with bearer token', () async {
    String? capturedAuth;
    String? capturedBasename;

    final client = ApiClient(
      httpClient: _FakeClient(
        sendHandler: (request) async {
          capturedAuth = request.headers['Authorization'];
          final streamed = request.finalize();
          final bytes = await streamed.toBytes();
          final text = String.fromCharCodes(bytes);
          if (text.contains('name="basename"')) {
            capturedBasename = 'seen';
          }
          return http.StreamedResponse(
            Stream.value(bytes),
            200,
          );
        },
      ),
    );

    await client.upload(
      settings: AppSettings(host: '100.64.0.1', port: 8787, token: 'secret'),
      basename: '20250619_143022',
      imageBytes: [0xFF, 0xD8, 0xFF],
      markdown: '# Test\n\nDo thing.',
    );

    expect(capturedAuth, 'Bearer secret');
    expect(capturedBasename, 'seen');
  });
}

class _FakeClient extends http.BaseClient {
  _FakeClient({this.getHandler, this.sendHandler});

  final http.Response Function(Uri url, Map<String, String>? headers)?
      getHandler;
  final Future<http.StreamedResponse> Function(http.BaseRequest request)?
      sendHandler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (sendHandler != null) {
      return sendHandler!(request);
    }
    if (request.method == 'GET' && getHandler != null) {
      final response = getHandler!(request.url, request.headers);
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
      );
    }
    throw UnimplementedError('No handler for ${request.method} ${request.url}');
  }
}
