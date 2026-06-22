import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/settings_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settingsStore,
    required this.apiClient,
  });

  final SettingsStore settingsStore;
  final ApiClient apiClient;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _tokenController = TextEditingController();
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await widget.settingsStore.load();
    _hostController.text = settings.host;
    _portController.text = settings.port.toString();
    _tokenController.text = settings.token;
    setState(() {});
  }

  Future<void> _save() async {
    final settings = AppSettings(
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? AppSettings.defaultPort,
      token: _tokenController.text.trim(),
    );
    await widget.settingsStore.save(settings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() => _status = 'Testing...');
    final settings = AppSettings(
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? AppSettings.defaultPort,
      token: _tokenController.text.trim(),
    );
    try {
      final tasks = await widget.apiClient.fetchTasks(settings);
      setState(() => _status = 'OK — ${tasks.length} tasks');
    } catch (e) {
      setState(() => _status = 'Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: 'PC host (Tailscale IP or hostname)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _portController,
            decoration: const InputDecoration(labelText: 'Port'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tokenController,
            decoration: const InputDecoration(labelText: 'Bearer token'),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(onPressed: _save, child: const Text('Save')),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _testConnection,
                child: const Text('Test connection'),
              ),
            ],
          ),
          if (_status != null) ...[
            const SizedBox(height: 16),
            Text(_status!),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    super.dispose();
  }
}
