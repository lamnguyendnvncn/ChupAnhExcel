import 'dart:io';

import '../models/task.dart';
import 'api_client.dart';
import 'basename_generator.dart';
import 'markdown_builder.dart';
import 'outbox_queue.dart';
import 'settings_store.dart';

class UploadService {
  UploadService({
    required this._outbox,
    required this._settingsStore,
    ApiClient? apiClient,
  }) : _api = apiClient ?? ApiClient();

  final OutboxQueue _outbox;
  final SettingsStore _settingsStore;
  final ApiClient _api;

  Future<String> captureAndQueue({
    required Task task,
    required String imagePath,
    required List<int> imageBytes,
  }) async {
    final existing = (await _outbox.all()).map((e) => e.basename).toSet();
    final basename = generateBasename(existing: existing);
    final markdown = buildMarkdown(task);

    await _outbox.enqueue(
      basename: basename,
      imagePath: imagePath,
      mdContent: markdown,
    );

    final settings = await _settingsStore.load();
    try {
      await _api.upload(
        settings: settings,
        basename: basename,
        imageBytes: imageBytes,
        markdown: markdown,
      );
      final items = await _outbox.all();
      final match = items.where((e) => e.basename == basename).firstOrNull;
      if (match != null) {
        await _outbox.markSuccess(match.id);
      }
      return 'sent';
    } on ApiException catch (e) {
      final items = await _outbox.all();
      final match = items.where((it) => it.basename == basename).firstOrNull;
      if (match != null) {
        await _outbox.markFailure(
          match.id,
          e.message,
          pause: e.statusCode == 401,
        );
      }
      return e.statusCode == 401 ? 'auth_error' : 'queued';
    } catch (e) {
      final items = await _outbox.all();
      final match = items.where((it) => it.basename == basename).firstOrNull;
      if (match != null) {
        await _outbox.markFailure(match.id, e.toString());
      }
      return 'queued';
    }
  }

  Future<void> processOutbox() async {
    final settings = await _settingsStore.load();
    if (settings.host.isEmpty || settings.token.isEmpty) {
      return;
    }

    final items = await _outbox.pending();
    for (final item in items) {
      try {
        final bytes = await File(item.imagePath).readAsBytes();
        await _api.upload(
          settings: settings,
          basename: item.basename,
          imageBytes: bytes,
          markdown: item.mdContent,
        );
        await _outbox.markSuccess(item.id);
      } on ApiException catch (e) {
        await _outbox.markFailure(
          item.id,
          e.message,
          pause: e.statusCode == 401,
        );
        if (e.statusCode == 401) {
          break;
        }
      } catch (e) {
        await _outbox.markFailure(item.id, e.toString());
      }
    }
  }
}
