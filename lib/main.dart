import 'package:flutter/material.dart';

import 'screens/camera_screen.dart';
import 'screens/outbox_screen.dart';
import 'screens/settings_screen.dart';
import 'services/api_client.dart';
import 'services/outbox_queue.dart';
import 'services/retry_worker.dart';
import 'services/settings_store.dart';
import 'services/task_repository.dart';
import 'services/upload_service.dart';
import 'widgets/outbox_badge.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final outbox = OutboxQueue();
  await outbox.init();
  final settingsStore = SettingsStore();
  final apiClient = ApiClient();
  final uploadService = UploadService(
    outbox: outbox,
    settingsStore: settingsStore,
    apiClient: apiClient,
  );
  final retryWorker = RetryWorker(uploadService: uploadService);
  retryWorker.start();

  runApp(ChupAnhExcelApp(
    outbox: outbox,
    settingsStore: settingsStore,
    uploadService: uploadService,
    taskRepository: TaskRepository(apiClient: apiClient),
    apiClient: apiClient,
  ));
}

class ChupAnhExcelApp extends StatelessWidget {
  const ChupAnhExcelApp({
    super.key,
    required this.outbox,
    required this.settingsStore,
    required this.uploadService,
    required this.taskRepository,
    required this.apiClient,
  });

  final OutboxQueue outbox;
  final SettingsStore settingsStore;
  final UploadService uploadService;
  final TaskRepository taskRepository;
  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChupAnhExcel',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: _AppHome(
        outbox: outbox,
        settingsStore: settingsStore,
        uploadService: uploadService,
        taskRepository: taskRepository,
        apiClient: apiClient,
      ),
    );
  }
}

class _AppHome extends StatelessWidget {
  const _AppHome({
    required this.outbox,
    required this.settingsStore,
    required this.uploadService,
    required this.taskRepository,
    required this.apiClient,
  });

  final OutboxQueue outbox;
  final SettingsStore settingsStore;
  final UploadService uploadService;
  final TaskRepository taskRepository;
  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return CameraScreen(
      uploadService: uploadService,
      taskRepository: taskRepository,
      settingsStore: settingsStore,
      outboxBadge: OutboxBadge(
        outbox: outbox,
        onTap: () => _openOutbox(context),
      ),
      onOpenOutbox: () => _openOutbox(context),
      onOpenSettings: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SettingsScreen(
              settingsStore: settingsStore,
              apiClient: apiClient,
            ),
          ),
        );
      },
    );
  }

  void _openOutbox(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OutboxScreen(
          outbox: outbox,
          uploadService: uploadService,
        ),
      ),
    );
  }
}
