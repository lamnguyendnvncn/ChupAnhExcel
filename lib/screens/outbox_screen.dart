import 'package:flutter/material.dart';

import '../services/outbox_queue.dart';
import '../services/upload_service.dart';

class OutboxScreen extends StatefulWidget {
  const OutboxScreen({
    super.key,
    required this.outbox,
    required this.uploadService,
  });

  final OutboxQueue outbox;
  final UploadService uploadService;

  @override
  State<OutboxScreen> createState() => _OutboxScreenState();
}

class _OutboxScreenState extends State<OutboxScreen> {
  List<OutboxItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final items = await widget.outbox.all();
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  Future<void> _retryAll() async {
    await widget.uploadService.processOutbox();
    await _refresh();
  }

  Future<void> _delete(int id) async {
    await widget.outbox.delete(id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outbox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _retryAll,
            tooltip: 'Retry all',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No pending uploads'))
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return ListTile(
                      title: Text(item.basename),
                      subtitle: Text(
                        'Attempts: ${item.attempts}'
                        '${item.lastError != null ? '\n${item.lastError}' : ''}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(item.id),
                      ),
                    );
                  },
                ),
    );
  }
}
