import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/task.dart';
import '../services/settings_store.dart';
import '../services/task_repository.dart';
import '../services/upload_service.dart';
import 'task_picker_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    required this.uploadService,
    required this.taskRepository,
    required this.settingsStore,
    this.outboxBadge,
    this.onOpenSettings,
    this.onOpenOutbox,
  });

  final UploadService uploadService;
  final TaskRepository taskRepository;
  final SettingsStore settingsStore;
  final Widget? outboxBadge;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenOutbox;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _initializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No cameras found');
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _initializing = false;
      });
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    try {
      final file = await controller.takePicture();
      if (!mounted) return;

      final usePhoto = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Use this photo?'),
          content: Image.file(File(file.path), fit: BoxFit.contain),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Retake'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Use photo'),
            ),
          ],
        ),
      );
      if (usePhoto != true || !mounted) return;

      final settings = await widget.settingsStore.load();
      final tasks = await widget.taskRepository.loadTasks(settings);
      if (!mounted) return;

      final task = await Navigator.push<Task>(
        context,
        MaterialPageRoute(
          builder: (context) => TaskPickerScreen(
            tasks: tasks,
            onSelected: (selected) => Navigator.pop(context, selected),
          ),
        ),
      );
      if (task == null || !mounted) return;

      final bytes = await File(file.path).readAsBytes();
      final dir = await getTemporaryDirectory();
      final dest = File(
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await File(file.path).copy(dest.path);

      final result = await widget.uploadService.captureAndQueue(
        task: task,
        imagePath: dest.path,
        imageBytes: bytes,
      );

      if (!mounted) return;
      final message = switch (result) {
        'sent' => 'Sent',
        'auth_error' => 'Bad token — fix settings',
        _ => 'Queued',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Capture failed: $e')),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChupAnhExcel'),
        actions: [
          if (widget.outboxBadge != null) widget.outboxBadge!,
          IconButton(
            icon: const Icon(Icons.inbox_outlined),
            onPressed: widget.onOpenOutbox,
            tooltip: 'Outbox',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: widget.onOpenSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _controller?.value.isInitialized == true
          ? FloatingActionButton(
              onPressed: _capture,
              child: const Icon(Icons.camera_alt),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _initializing = true;
                    _error = null;
                  });
                  _initCamera();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: Text('Camera unavailable'));
    }
    return CameraPreview(controller);
  }
}
