import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/task.dart';
import 'api_client.dart';
import 'settings_store.dart';

class TaskRepository {
  TaskRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<Task>> loadTasks(AppSettings settings) async {
    if (settings.host.isNotEmpty && settings.token.isNotEmpty) {
      try {
        return await _api.fetchTasks(settings);
      } catch (_) {
        // fall through to bundled tasks
      }
    }
    return _loadBundledTasks();
  }

  Future<List<Task>> _loadBundledTasks() async {
    final raw = await rootBundle.loadString('assets/tasks.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = decoded['tasks'] as List<dynamic>;
    return list
        .map((item) => Task.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
