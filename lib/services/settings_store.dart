import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  AppSettings({
    required this.host,
    required this.port,
    required this.token,
  });

  final String host;
  final int port;
  final String token;

  static const defaultPort = 8787;

  String get baseUrl => 'http://$host:$port';

  AppSettings copyWith({String? host, int? port, String? token}) {
    return AppSettings(
      host: host ?? this.host,
      port: port ?? this.port,
      token: token ?? this.token,
    );
  }
}

class SettingsStore {
  static const _hostKey = 'pc_host';
  static const _portKey = 'pc_port';
  static const _tokenKey = 'bearer_token';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      host: prefs.getString(_hostKey) ?? '',
      port: prefs.getInt(_portKey) ?? AppSettings.defaultPort,
      token: prefs.getString(_tokenKey) ?? '',
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, settings.host);
    await prefs.setInt(_portKey, settings.port);
    await prefs.setString(_tokenKey, settings.token);
  }
}
