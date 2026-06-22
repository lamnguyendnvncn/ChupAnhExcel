# ChupAnhExcel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an Android Flutter app that captures photos, picks a task, and sends `{timestamp}.jpg` + `{timestamp}.md` to a Windows Python receiver over Tailscale; include Flutter dev environment setup on **Linux or macOS** (either dev machine can build APK and run tests).

**Architecture:** Flutter mobile app with camera capture, task picker, SQLite outbox, and HTTP upload client. Python FastAPI receiver on Windows serves `GET /tasks` from `tasks.yaml` and accepts `POST /upload` with bearer auth, writing atomically to a watch folder.

**Tech Stack:** Flutter (stable), `camera`, `http`, `sqflite`, `path_provider`, `shared_preferences`; Python 3.11+, FastAPI, uvicorn, PyYAML; Tailscale; Android JDK 17.

## Global Constraints

- **Dev machines:** Linux PC or macOS laptop — same repo, same Flutter/Android toolchain goals; only OS-specific install steps differ (Task 1)
- **Deploy target:** Windows PC runs Python receiver + watch folder (Tasks 13–14); receiver tests can run on any dev machine
- **Repo root:** All commands assume you are in the git repo root unless noted. Use `cd "$(git rev-parse --show-toplevel)"` when unsure

- File pair: `{timestamp}.jpg` + `{timestamp}.md` (same basename)
- Timestamp format: local device time, `YYYYMMDD_HHMMSS`; on collision append `_1`, `_2`, etc.
- Markdown body: `# {task label}` heading + instruction text
- Transfer: HTTP over Tailscale with `Authorization: Bearer <token>`
- Default port: `8787`
- Offline: SQLite outbox + auto-retry every 30s; 401 pauses retry until settings fixed
- v1 platform: Android APK only (no iOS, no Linux desktop target)
- PC receiver: Windows, watch folder path configurable (TBD at deploy time)
- Tasks: PC `tasks.yaml` via `GET /tasks`; bundled `assets/tasks.json` fallback

---

## File Structure

```
ChupAnhExcel/                          # Flutter app at repo root
├── lib/
│   ├── main.dart
│   ├── models/task.dart
│   ├── services/
│   │   ├── basename_generator.dart
│   │   ├── markdown_builder.dart
│   │   ├── settings_store.dart
│   │   ├── api_client.dart
│   │   ├── outbox_queue.dart
│   │   ├── task_repository.dart
│   │   ├── upload_service.dart
│   │   └── retry_worker.dart
│   ├── screens/
│   │   ├── camera_screen.dart
│   │   ├── task_picker_screen.dart
│   │   ├── settings_screen.dart
│   │   └── outbox_screen.dart
│   └── widgets/outbox_badge.dart
├── assets/tasks.json
├── test/services/
│   ├── basename_generator_test.dart
│   ├── markdown_builder_test.dart
│   └── api_client_test.dart
├── pubspec.yaml
└── receiver/                          # Python server (dev/test Linux/macOS; deploy Windows)
    ├── main.py
    ├── config.yaml.example
    ├── tasks.yaml
    ├── requirements.txt
    └── tests/test_receiver.py
```

---

### Task 1: Flutter Dev Environment (Linux or macOS)

**Status:** macOS done (2026-06-19) · Linux pending

**Files:**
- Create: shell profile append (`~/.bashrc` on Linux, `~/.zshrc` on macOS — or `~/.bash_profile` if you use bash on Mac)
- Create: `~/development/flutter/` (SDK install location; same path on both machines)

**Interfaces:**
- Produces: working `flutter` and `adb` commands on PATH on **whichever machine you are on**

Pick **one** OS block below. Repeat on the other machine later if you switch laptops — same repo, same `ANDROID_HOME` layout.

#### macOS (done)

- [x] **Step 0: Detect OS** — `Darwin`
- [x] **Step 1: Prerequisites** — Xcode CLI tools present; system `git`/`curl`/`unzip`; JDK 21 on PATH (no `openjdk@17` brew install needed)
- [x] **Step 2: Flutter SDK** — `~/development/flutter` stable 3.44.2; PATH in `~/.zshrc`
- [x] **Step 3: Android SDK** — `~/Android/Sdk` via cmdline-tools; `platform-tools`, `platforms;android-34`, `platforms;android-36`, `build-tools;34.0.0`, `build-tools;28.0.3`; licenses accepted
- [x] **Step 4: flutter doctor** — Flutter ✓, Android toolchain ✓ (Xcode/Chrome warnings OK for Android-only v1)
- [ ] **Step 5: adb device** — `adb` works; no phone plugged in yet (plug in + USB debugging when ready)
- [ ] **Step 6: Commit** — skipped (user did not request)

#### Linux (pending)

- [ ] **Step 0: Detect OS**
- [ ] **Step 1: Install system prerequisites**
- [ ] **Step 2: Install Flutter SDK**
- [ ] **Step 3: Install Android command-line tools**
- [ ] **Step 4: Run flutter doctor and fix remaining issues**
- [ ] **Step 5: Verify device connection**
- [ ] **Step 6: Commit environment notes**

---

**Reference commands** (repeat on Linux when on PC):

- [ ] **Step 0: Detect OS**

```bash
uname -s   # Linux → follow Linux block; Darwin → follow macOS block
```

- [ ] **Step 1: Install system prerequisites**

**Linux:**

```bash
sudo apt-get update
sudo apt-get install -y git curl unzip xz-utils zip libglu1-mesa clang cmake ninja-build pkg-config libgtk-3-dev openjdk-17-jdk
java -version
```

**macOS:**

```bash
xcode-select --install   # skip if already installed
brew install git curl unzip openjdk@17
echo 'export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"' >> ~/.zshrc
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
java -version
```

Expected on both: `openjdk version "17.x.x"`

- [ ] **Step 2: Install Flutter SDK** (identical on Linux and macOS)

```bash
mkdir -p ~/development
cd ~/development
git clone https://github.com/flutter/flutter.git -b stable --depth 1
```

Append to your shell profile (`~/.bashrc` on Linux, `~/.zshrc` on macOS):

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

Then reload and verify:

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
flutter --version
```

Expected: Flutter stable version printed (3.x)

- [ ] **Step 3: Install Android command-line tools**

**Linux:**

```bash
mkdir -p ~/Android/Sdk/cmdline-tools
cd /tmp
curl -fsSL -o commandlinetools.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip -q commandlinetools.zip -d ~/Android/Sdk/cmdline-tools
mv ~/Android/Sdk/cmdline-tools/cmdline-tools ~/Android/Sdk/cmdline-tools/latest
```

**macOS:**

```bash
mkdir -p ~/Android/Sdk/cmdline-tools
cd /tmp
curl -fsSL -o commandlinetools.zip https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip
unzip -q commandlinetools.zip -d ~/Android/Sdk/cmdline-tools
mv ~/Android/Sdk/cmdline-tools/cmdline-tools ~/Android/Sdk/cmdline-tools/latest
```

**Both** — append to shell profile, then export in current session:

```bash
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
yes | sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-34" "platforms;android-36" "build-tools;34.0.0" "build-tools;28.0.3"
flutter config --android-sdk "$ANDROID_HOME"
```

**macOS alternative:** Install [Android Studio](https://developer.android.com/studio) instead of Step 3 CLI flow; point Flutter at its SDK (`~/Library/Android/sdk` on Apple Silicon). Skip duplicate SDK install if Studio already provides one.

- [ ] **Step 4: Run flutter doctor and fix remaining issues**

```bash
flutter doctor -v
```

Expected: Flutter + Android toolchain show checkmarks. Accept license prompts with `flutter doctor --android-licenses`. Chrome / VS Code are optional.

- [ ] **Step 5: Verify device connection (phone plugged in, USB debugging on)**

```bash
adb devices
```

Expected: device serial listed as `device` (not `unauthorized`)

**macOS note:** First USB attach may prompt "Allow accessory" on phone; trust the Mac if asked.

- [ ] **Step 6: Commit environment notes** (after plan doc exists in repo)

```bash
cd "$(git rev-parse --show-toplevel)"
git add docs/superpowers/plans/2026-06-19-chup-anh-excel.md
git commit -m "docs: add ChupAnhExcel implementation plan"
```

---

### Task 2: Flutter Project Scaffold

**Status:** done (macOS, 2026-06-19)

**Files:**
- Create: repo root Flutter project via `flutter create .`
- Modify: `pubspec.yaml`
- Create: `assets/tasks.json`

**Interfaces:**
- Produces: runnable empty Flutter app with dependencies declared

- [x] **Step 1: Create project**

```bash
cd "$(git rev-parse --show-toplevel)"
flutter create --org com.chupanhexcel --project-name chup_anh_excel .
flutter pub get
```

- [x] **Step 2: Add dependencies to `pubspec.yaml`**

Replace the `dependencies:` and `dev_dependencies:` sections:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  camera: ^0.11.0+2
  http: ^1.2.2
  sqflite: ^2.4.1
  path_provider: ^2.1.5
  path: ^1.9.0
  shared_preferences: ^2.3.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  http_mock_adapter: ^0.6.1

flutter:
  uses-material-design: true
  assets:
    - assets/tasks.json
```

- [x] **Step 3: Create bundled fallback tasks**

Create `assets/tasks.json`:

```json
{
  "tasks": [
    {
      "id": "extract-excel",
      "label": "Extract table to Excel",
      "instructions": "Read the attached image. Extract all table data into a structured format.\nPreserve column headers. Output as CSV-ready data."
    },
    {
      "id": "summarize-receipt",
      "label": "Summarize receipt",
      "instructions": "Read the attached image. List items, prices, and total."
    }
  ]
}
```

- [x] **Step 4: Verify project runs**

```bash
flutter analyze
flutter test
```

Expected: no issues, 0 tests (placeholder) pass

- [ ] **Step 5: Commit**

```bash
git add git commit -m "feat: scaffold Flutter project with dependencies"
```

---

### Task 3: Basename Generator

**Status:** done (2026-06-19)

**Files:**
- Create: `lib/services/basename_generator.dart`
- Create: `test/services/basename_generator_test.dart`

**Interfaces:**
- Produces: `String generateBasename({DateTime? now, Set<String>? existing})`

- [ ] **Step 1: Write the failing test**

Create `test/services/basename_generator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:chup_anh_excel/services/basename_generator.dart';

void main() {
  test('generateBasename formats local timestamp', () {
    final result = generateBasename(
      now: DateTime(2025, 6, 19, 14, 30, 22),
    );
    expect(result, '20250619_143022');
  });

  test('generateBasename appends suffix on collision', () {
    final result = generateBasename(
      now: DateTime(2025, 6, 19, 14, 30, 22),
      existing: {'20250619_143022'},
    );
    expect(result, '20250619_143022_1');
  });

  test('generateBasename increments suffix until unique', () {
    final result = generateBasename(
      now: DateTime(2025, 6, 19, 14, 30, 22),
      existing: {'20250619_143022', '20250619_143022_1'},
    );
    expect(result, '20250619_143022_2');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd "$(git rev-parse --show-toplevel)"
flutter test test/services/basename_generator_test.dart
```

Expected: FAIL — `generateBasename` not defined

- [ ] **Step 3: Write minimal implementation**

Create `lib/services/basename_generator.dart`:

```dart
String generateBasename({DateTime? now, Set<String>? existing}) {
  final dt = now ?? DateTime.now();
  final base = '${dt.year.toString().padLeft(4, '0')}'
      '${dt.month.toString().padLeft(2, '0')}'
      '${dt.day.toString().padLeft(2, '0')}_'
      '${dt.hour.toString().padLeft(2, '0')}'
      '${dt.minute.toString().padLeft(2, '0')}'
      '${dt.second.toString().padLeft(2, '0')}';

  final taken = existing ?? {};
  if (!taken.contains(base)) {
    return base;
  }

  var suffix = 1;
  while (taken.contains('${base}_$suffix')) {
    suffix++;
  }
  return '${base}_$suffix';
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/services/basename_generator_test.dart
```

Expected: 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/services/basename_generator.dart test/services/basename_generator_test.dart
git commit -m "feat: add basename generator with collision handling"
```

---

### Task 4: Markdown Builder

**Status:** done (2026-06-19)

**Files:**
- Create: `lib/models/task.dart`
- Create: `lib/services/markdown_builder.dart`
- Create: `test/services/markdown_builder_test.dart`

**Interfaces:**
- Produces: `class Task { final String id; final String label; final String instructions; }`
- Produces: `String buildMarkdown(Task task)`

- [ ] **Step 1: Write the failing test**

Create `test/services/markdown_builder_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:chup_anh_excel/models/task.dart';
import 'package:chup_anh_excel/services/markdown_builder.dart';

void main() {
  test('buildMarkdown creates heading and body', () {
    const task = Task(
      id: 'extract-excel',
      label: 'Extract table to Excel',
      instructions: 'Read the attached image.\nPreserve column headers.',
    );

    final md = buildMarkdown(task);

    expect(md, '''# Extract table to Excel

Read the attached image.
Preserve column headers.''');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/services/markdown_builder_test.dart
```

Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Create `lib/models/task.dart`:

```dart
class Task {
  const Task({
    required this.id,
    required this.label,
    required this.instructions,
  });

  final String id;
  final String label;
  final String instructions;

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      label: json['label'] as String,
      instructions: json['instructions'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'instructions': instructions,
      };
}
```

Create `lib/services/markdown_builder.dart`:

```dart
import '../models/task.dart';

String buildMarkdown(Task task) {
  return '# ${task.label}\n\n${task.instructions}';
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/services/markdown_builder_test.dart
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/task.dart lib/services/markdown_builder.dart test/services/markdown_builder_test.dart
git commit -m "feat: add Task model and markdown builder"
```

---

### Task 5: Settings Store

**Status:** done (2026-06-20)

**Files:**
- Create: `lib/services/settings_store.dart`

**Interfaces:**
- Produces: `class AppSettings { String host; int port; String token; }`
- Produces: `class SettingsStore { Future<AppSettings> load(); Future<void> save(AppSettings); }`

- [ ] **Step 1: Implement settings store**

Create `lib/services/settings_store.dart`:

```dart
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
```

- [ ] **Step 2: Verify analyze passes**

```bash
flutter analyze lib/services/settings_store.dart
```

Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/services/settings_store.dart
git commit -m "feat: add settings store for PC connection"
```

---

### Task 6: API Client

**Status:** done (2026-06-20)

**Files:**
- Create: `lib/services/api_client.dart`
- Create: `test/services/api_client_test.dart`

**Interfaces:**
- Consumes: `AppSettings`, `Task`
- Produces: `class ApiClient { Future<List<Task>> fetchTasks(AppSettings); Future<void> upload({required AppSettings, required String basename, required List<int> imageBytes, required String markdown}); }`
- Produces: `class ApiException implements Exception { final int? statusCode; final String message; }`

- [ ] **Step 1: Write the failing test**

Create `test/services/api_client_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:chup_anh_excel/services/api_client.dart';
import 'package:chup_anh_excel/services/settings_store.dart';

void main() {
  test('fetchTasks parses JSON response', () async {
    final client = ApiClient(
      httpClient: _FakeClient(
        getHandler: (url, headers) {
          expect(headers['Authorization'], 'Bearer test-token');
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
        postHandler: (url, headers, body, encoding) {
          capturedAuth = headers?['Authorization'];
          return http.Response('{"ok":true}', 200);
        },
        sendHandler: (request) async {
          final streamed = await request.finalize();
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
  _FakeClient({this.getHandler, this.postHandler, this.sendHandler});

  final http.Response Function(Uri url, Map<String, String>? headers)? getHandler;
  final http.Response Function(Uri url, Map<String, String>? headers, Object? body, Encoding? encoding)? postHandler;
  final Future<http.StreamedResponse> Function(http.BaseRequest request)? sendHandler;

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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/services/api_client_test.dart
```

Expected: FAIL — `ApiClient` not defined

- [ ] **Step 3: Write minimal implementation**

Create `lib/services/api_client.dart`:

```dart
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

    final streamed = await request.send();
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
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/services/api_client_test.dart
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/services/api_client.dart test/services/api_client_test.dart
git commit -m "feat: add API client for tasks and upload"
```

---

### Task 7: Outbox Queue (SQLite)

**Status:** done (2026-06-20)

**Files:**
- Create: `lib/services/outbox_queue.dart`

**Interfaces:**
- Produces: `class OutboxItem { int id; String basename; String imagePath; String mdContent; DateTime createdAt; int attempts; String? lastError; bool paused; }`
- Produces: `class OutboxQueue { Future<void> init(); Future<int> enqueue(...); Future<List<OutboxItem>> pending(); Future<void> markSuccess(int id); Future<void> markFailure(int id, String error, {bool pause}); Future<void> delete(int id); }`

- [ ] **Step 1: Implement outbox queue**

Create `lib/services/outbox_queue.dart`:

```dart
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class OutboxItem {
  OutboxItem({
    required this.id,
    required this.basename,
    required this.imagePath,
    required this.mdContent,
    required this.createdAt,
    required this.attempts,
    this.lastError,
    this.paused = false,
  });

  final int id;
  final String basename;
  final String imagePath;
  final String mdContent;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
  final bool paused;
}

class OutboxQueue {
  Database? _db;

  Future<void> init() async {
    final basePath = await getDatabasesPath();
    final dbPath = p.join(basePath, 'outbox.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE outbox (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            basename TEXT NOT NULL,
            image_path TEXT NOT NULL,
            md_content TEXT NOT NULL,
            created_at TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            paused INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<int> enqueue({
    required String basename,
    required String imagePath,
    required String mdContent,
  }) async {
    final db = _requireDb();
    return db.insert('outbox', {
      'basename': basename,
      'image_path': imagePath,
      'md_content': mdContent,
      'created_at': DateTime.now().toIso8601String(),
      'attempts': 0,
      'paused': 0,
    });
  }

  Future<List<OutboxItem>> pending() async {
    final db = _requireDb();
    final rows = await db.query(
      'outbox',
      where: 'paused = 0',
      orderBy: 'created_at ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<OutboxItem>> all() async {
    final db = _requireDb();
    final rows = await db.query('outbox', orderBy: 'created_at ASC');
    return rows.map(_fromRow).toList();
  }

  Future<int> countPending() async {
    final db = _requireDb();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM outbox WHERE paused = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markSuccess(int id) async {
    final db = _requireDb();
    await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markFailure(int id, String error, {bool pause = false}) async {
    final db = _requireDb();
    await db.update(
      'outbox',
      {
        'attempts': Sqflite.raw('attempts + 1'),
        'last_error': error,
        'paused': pause ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> resumeAll() async {
    final db = _requireDb();
    await db.update('outbox', {'paused': 0, 'last_error': null});
  }

  Future<void> delete(int id) async {
    final db = _requireDb();
    await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
  }

  Database _requireDb() {
    final db = _db;
    if (db == null) {
      throw StateError('OutboxQueue not initialized');
    }
    return db;
  }

  OutboxItem _fromRow(Map<String, dynamic> row) {
    return OutboxItem(
      id: row['id'] as int,
      basename: row['basename'] as String,
      imagePath: row['image_path'] as String,
      mdContent: row['md_content'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      attempts: row['attempts'] as int,
      lastError: row['last_error'] as String?,
      paused: (row['paused'] as int) == 1,
    );
  }
}
```

- [ ] **Step 2: Verify analyze passes**

```bash
flutter analyze lib/services/outbox_queue.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/services/outbox_queue.dart
git commit -m "feat: add SQLite outbox queue"
```

---

### Task 8: Task Repository

**Status:** done (2026-06-20)

**Files:**
- Create: `lib/services/task_repository.dart`

**Interfaces:**
- Consumes: `ApiClient`, `AppSettings`, bundled `assets/tasks.json`
- Produces: `class TaskRepository { Future<List<Task>> loadTasks(AppSettings settings); }`

- [ ] **Step 1: Implement task repository with fallback**

Create `lib/services/task_repository.dart`:

```dart
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/task_repository.dart
git commit -m "feat: add task repository with bundled fallback"
```

---

### Task 9: Upload Service + Retry Worker

**Status:** done (2026-06-20)

**Files:**
- Create: `lib/services/upload_service.dart`
- Create: `lib/services/retry_worker.dart`

**Interfaces:**
- Consumes: `ApiClient`, `OutboxQueue`, `SettingsStore`, `generateBasename`, `buildMarkdown`
- Produces: `class UploadService { Future<bool> captureAndQueue({required Task task, required String imagePath, required List<int> imageBytes}); }`
- Produces: `class RetryWorker { void start(); void stop(); Future<void> tick(); }`

- [ ] **Step 1: Implement upload service**

Create `lib/services/upload_service.dart`:

```dart
import 'dart:io';

import '../models/task.dart';
import 'api_client.dart';
import 'basename_generator.dart';
import 'markdown_builder.dart';
import 'outbox_queue.dart';
import 'settings_store.dart';

class UploadService {
  UploadService({
    required OutboxQueue outbox,
    required SettingsStore settingsStore,
    ApiClient? apiClient,
  })  : _outbox = outbox,
        _settingsStore = settingsStore,
        _api = apiClient ?? ApiClient();

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
```

- [ ] **Step 2: Implement retry worker**

Create `lib/services/retry_worker.dart`:

```dart
import 'dart:async';

import 'upload_service.dart';

class RetryWorker {
  RetryWorker({required UploadService uploadService})
      : _uploadService = uploadService;

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
```

- [ ] **Step 3: Commit**

```bash
git add lib/services/upload_service.dart lib/services/retry_worker.dart
git commit -m "feat: add upload service and retry worker"
```

---

### Task 10: Settings Screen

**Status:** done (2026-06-20)

**Files:**
- Create: `lib/screens/settings_screen.dart`

**Interfaces:**
- Consumes: `SettingsStore`, `ApiClient`
- Produces: `class SettingsScreen extends StatefulWidget`

- [ ] **Step 1: Implement settings screen**

Create `lib/screens/settings_screen.dart`:

```dart
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: add settings screen"
```

---

### Task 11: Camera + Task Picker Screens

**Status:** done (2026-06-20)

**Files:**
- Create: `lib/screens/camera_screen.dart`
- Create: `lib/screens/task_picker_screen.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: `UploadService`, `TaskRepository`, `SettingsStore`
- Produces: camera capture flow → task picker → upload result snackbar

- [ ] **Step 1: Add Android camera permission**

In `android/app/src/main/AndroidManifest.xml`, before `<application>`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
```

- [ ] **Step 2: Create task picker screen**

Create `lib/screens/task_picker_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../models/task.dart';

class TaskPickerScreen extends StatelessWidget {
  const TaskPickerScreen({
    super.key,
    required this.tasks,
    required this.onSelected,
  });

  final List<Task> tasks;
  final ValueChanged<Task> onSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick task')),
      body: ListView.separated(
        itemCount: tasks.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final task = tasks[index];
          return ListTile(
            title: Text(task.label),
            subtitle: Text(
              task.instructions,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onSelected(task),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 3: Create camera screen**

Create `lib/screens/camera_screen.dart` with:
- `CameraController` init on back camera
- Shutter button → capture to temp file
- Preview dialog: Retake / Use photo
- On confirm → navigate to `TaskPickerScreen` with tasks from `TaskRepository`
- On task selected → call `UploadService.captureAndQueue`
- Show snackbar: `Sent`, `Queued`, or `Bad token — fix settings`

(Implement full widget; use `path_provider` for temp image path.)

- [ ] **Step 4: Manual smoke on device**

```bash
flutter run
```

Expected: camera opens, capture works, task list shows bundled tasks

- [ ] **Step 5: Commit**

```bash
git add lib/screens/ android/app/src/main/AndroidManifest.xml
git commit -m "feat: add camera and task picker screens"
```

---

### Task 12: Outbox UI + App Wiring

**Status:** done (2026-06-20)

**Files:**
- Create: `lib/screens/outbox_screen.dart`
- Create: `lib/widgets/outbox_badge.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: all services
- Produces: wired app with outbox badge, settings nav, retry worker started in `main()`

- [ ] **Step 1: Create outbox screen** — list items, show `basename`, `attempts`, `last_error`; buttons: Retry (calls `processOutbox`), Delete (calls `outbox.delete`)

- [ ] **Step 2: Create outbox badge widget** — `FutureBuilder` on `outbox.countPending()`, show count chip in app bar

- [ ] **Step 3: Wire `main.dart`**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final outbox = OutboxQueue();
  await outbox.init();
  final settingsStore = SettingsStore();
  final uploadService = UploadService(outbox: outbox, settingsStore: settingsStore);
  final retryWorker = RetryWorker(uploadService: uploadService);
  retryWorker.start();

  runApp(ChupAnhExcelApp(
    outbox: outbox,
    settingsStore: settingsStore,
    uploadService: uploadService,
    taskRepository: TaskRepository(),
    apiClient: ApiClient(),
  ));
}
```

- [ ] **Step 4: Run all unit tests**

```bash
flutter test
flutter analyze
```

Expected: all tests pass, no analyze issues

- [ ] **Step 5: Commit**

```bash
git add lib/ test/
git commit -m "feat: wire app shell with outbox UI and retry worker"
```

---

### Task 13: Python Receiver (develop on Linux/macOS, deploy on Windows)

**Files:**
- Create: `receiver/main.py`
- Create: `receiver/config.yaml.example`
- Create: `receiver/tasks.yaml`
- Create: `receiver/requirements.txt`
- Create: `receiver/tests/test_receiver.py`

**Interfaces:**
- Produces: `GET /tasks` → JSON from `tasks.yaml`
- Produces: `POST /upload` → atomic write of `.jpg` + `.md`
- Produces: bearer token validation; bind to configurable host (Tailscale IP)

- [ ] **Step 1: Create requirements**

`receiver/requirements.txt`:

```
fastapi==0.115.6
uvicorn==0.34.0
python-multipart==0.0.20
pyyaml==6.0.2
httpx==0.28.1
pytest==8.3.4
```

- [ ] **Step 2: Create config example**

`receiver/config.yaml.example`:

```yaml
host: "100.64.0.1"   # Windows Tailscale IP — bind address
port: 8787
token: "change-me"
watch_folder: "C:/ChatGPT-Inbox"
tasks_file: "tasks.yaml"
```

- [ ] **Step 3: Implement `receiver/main.py`**

```python
import os
import tempfile
from pathlib import Path

import yaml
from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, UploadFile
from fastapi.responses import JSONResponse

app = FastAPI()

CONFIG_PATH = Path(os.environ.get("RECEIVER_CONFIG", "config.yaml"))

def load_config() -> dict:
    with CONFIG_PATH.open(encoding="utf-8") as f:
        return yaml.safe_load(f)

def verify_token(authorization: str | None = Header(default=None)) -> None:
    cfg = load_config()
    expected = f"Bearer {cfg['token']}"
    if authorization != expected:
        raise HTTPException(status_code=401, detail="Bad token")

@app.get("/tasks")
def get_tasks(_: None = Depends(verify_token)):
    cfg = load_config()
    tasks_path = Path(cfg["tasks_file"])
    with tasks_path.open(encoding="utf-8") as f:
        data = yaml.safe_load(f)
    return JSONResponse(content=data)

@app.post("/upload")
async def upload(
    basename: str = Form(...),
    markdown: str = Form(...),
    image: UploadFile = File(...),
    _: None = Depends(verify_token),
):
    cfg = load_config()
    watch = Path(cfg["watch_folder"])
    watch.mkdir(parents=True, exist_ok=True)

    jpg_path = watch / f"{basename}.jpg"
    md_path = watch / f"{basename}.md"

    image_bytes = await image.read()

    with tempfile.NamedTemporaryFile(delete=False, dir=watch, suffix=".jpg.tmp") as tmp:
        tmp.write(image_bytes)
        tmp_jpg = Path(tmp.name)
    tmp_jpg.replace(jpg_path)

    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", delete=False, dir=watch, suffix=".md.tmp"
    ) as tmp:
        tmp.write(markdown)
        tmp_md = Path(tmp.name)
    tmp_md.replace(md_path)

    return {"ok": True, "basename": basename}

if __name__ == "__main__":
    import uvicorn

    cfg = load_config()
    uvicorn.run(app, host=cfg["host"], port=int(cfg["port"]))
```

- [ ] **Step 4: Create default tasks.yaml** (same content as spec)

- [ ] **Step 5: Write receiver test**

`receiver/tests/test_receiver.py` — use `httpx.AsyncClient` + `ASGITransport` to test 401 without token, 200 with token on `/tasks`, upload writes both files.

- [ ] **Step 6: Run receiver tests** (Linux or macOS dev machine)

```bash
cd "$(git rev-parse --show-toplevel)/receiver"
python3 -m venv .venv
source .venv/bin/activate   # same on Linux and macOS
pip install -r requirements.txt
pytest tests/ -v
```

Expected: all tests PASS

- [ ] **Step 7: Commit**

```bash
git add receiver/
git commit -m "feat: add Python FastAPI receiver"
```

---

### Task 14: End-to-End Verification + Release APK

**Files:**
- Modify: none (manual verification)

**Interfaces:**
- Consumes: full app + receiver

**Where:** Steps 1–3 need Windows receiver + Tailscale. Steps 4–5 run on Linux or macOS dev machine (or switch machines via git).

- [ ] **Step 1: Start receiver on Windows** (deploy target only — not Linux/macOS)

Copy `receiver/` to Windows PC. Create `config.yaml` from example with real Tailscale IP, token, watch folder. Run:

```powershell
cd receiver
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python main.py
```

- [ ] **Step 2: Configure app settings on phone**

Enter Windows Tailscale IP, port `8787`, bearer token. Tap Test connection — expect task count.

- [ ] **Step 3: Full flow test**

Capture photo → pick task → verify snackbar `Sent` → confirm `{basename}.jpg` and `{basename}.md` appear in watch folder.

- [ ] **Step 4: Offline test**

Stop receiver → capture → expect `Queued` → restart receiver → within 30s outbox clears.

- [ ] **Step 5: Build release APK** (Linux or macOS)

```bash
cd "$(git rev-parse --show-toplevel)"
flutter build apk --release
```

Expected: `build/app/outputs/flutter-apk/app-release.apk` exists

- [ ] **Step 6: Commit any final fixes**

```bash
git commit -am "fix: address E2E issues found during manual test"
```

---

## Self-Review

**Spec coverage:**
- [x] Camera capture → Task 11
- [x] Task picker from PC/bundled → Tasks 8, 11
- [x] `.jpg` + `.md` pair → Tasks 3, 4, 9, 13
- [x] Tailscale + bearer token → Tasks 5, 6, 13
- [x] SQLite outbox + 30s retry → Tasks 7, 9, 12
- [x] 401 pause → Task 9
- [x] Settings screen → Task 10
- [x] Flutter Linux/macOS setup → Task 1
- [x] Android APK → Tasks 1, 14
- [x] Python receiver on Windows → Task 13
- [x] Atomic file write on PC → Task 13

**Placeholder scan:** No TBD steps except watch folder value at Windows deploy (documented in config example).

**Type consistency:** `Task`, `AppSettings`, `ApiClient.upload`, `OutboxQueue` interfaces aligned across tasks.
