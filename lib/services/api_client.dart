import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/task.dart';
import 'settings_store.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Future<List<Task>> fetchTasks(AppSettings settings) async {
    final uri = Uri.parse('${settings.baseUrl}/tasks');
    final response = await _http.get(
      uri,
      headers: _authHeaders(settings),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to fetch tasks', statusCode: response.statusCode);
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final list = decoded['tasks'] as List<dynamic>;
    return list
        .map((item) => Task.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> upload({
    required AppSettings settings,
    required String basename,
    required List<int> imageBytes,
    required String markdown,
  }) async {
    final uri = Uri.parse('${settings.baseUrl}/upload');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_authHeaders(settings))
      ..fields['basename'] = basename
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: '$basename.jpg',
      ))
      ..fields['markdown'] = markdown;

    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 401) {
      throw ApiException('Bad token', statusCode: 401);
    }
    if (response.statusCode != 200) {
      throw ApiException('Upload failed', statusCode: response.statusCode);
    }
  }

  Map<String, String> _authHeaders(AppSettings settings) {
    return {
      'Authorization': 'Bearer ${settings.token}',
    };
  }
}
