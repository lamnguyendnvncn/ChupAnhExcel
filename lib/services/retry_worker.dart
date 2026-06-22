import 'dart:async';

import 'upload_service.dart';

class RetryWorker {
  RetryWorker({required this._uploadService});

  final UploadService _uploadService;
  Timer? _timer;

  void start() {
    _timer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => _uploadService.processOutbox(),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> tick() => _uploadService.processOutbox();
}
