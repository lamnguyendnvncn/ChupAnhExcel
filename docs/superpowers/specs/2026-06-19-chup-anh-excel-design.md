# ChupAnhExcel — Design Spec

**Date:** 2026-06-19  
**Status:** Approved  
**Scope:** v1 Android-first; iOS/TestFlight deferred

## Summary

Mobile app captures a photo, user picks a predefined task, app sends `{timestamp}.jpg` + `{timestamp}.md` to a Windows PC over HTTP via Tailscale. PC receiver saves files to a configurable watch folder for ChatGPT Computer Use. Task list is managed on the PC; the app caches tasks and queues uploads when offline.

## Goals

- Fast capture → task pick → send workflow
- Cross-platform foundation (Flutter) with Android APK as v1 delivery target
- Reliable delivery over Tailscale with bearer-token auth
- Offline resilience via local outbox queue with auto-retry
- Develop and build on Linux or macOS; run receiver on Windows

## Non-Goals (v1)

- iOS TestFlight build (spec'd for later, not implemented in v1)
- Linux desktop target
- In-app task editing
- ChatGPT integration testing
- Automated E2E tests

## Architecture

```
[Android App]                    [Windows PC]
  Camera                            Tailscale
    → pick task                       ↓
    → build .jpg + .md         Python FastAPI
    → POST /upload  ──Tailscale──►  validate token
    → queue if fail                 save pair to watch folder
                                    serve GET /tasks
                                          ↓
                                   ChatGPT Computer Use
```

### Mobile modules

| Module | Responsibility |
|--------|----------------|
| `CameraScreen` | Camera preview, capture, confirm/retake |
| `TaskPicker` | Display tasks from API or bundled fallback |
| `UploadService` | Multipart POST with bearer auth |
| `OutboxQueue` | SQLite persistence, background retry |
| `SettingsScreen` | PC host, port, token, test connection |

### PC receiver

| Endpoint | Behavior |
|----------|----------|
| `GET /tasks` | Return task list from `tasks.yaml` as JSON |
| `POST /upload` | Accept image + markdown, write atomically to watch folder |

Bind server to Tailscale interface only. Config: watch folder path, bearer token, port (default `8787`).

### Linux / macOS dev role

Flutter SDK + Android toolchain for development and APK builds on **Linux or macOS**. No desktop app target in v1. Same repo clones on both machines; only Task 1 install steps differ by OS.

## Key Decisions

| Item | Choice |
|------|--------|
| Mobile stack | Flutter |
| PC receiver | Python FastAPI |
| File pair | `{timestamp}.jpg` + `{timestamp}.md` |
| Timestamp format | Local time, `YYYYMMDD_HHMMSS` |
| Task storage | `tasks.yaml` on PC; bundled `assets/tasks.json` fallback in app |
| Transfer | Tailscale mesh VPN |
| Security | Tailscale + `Authorization: Bearer <token>` |
| Offline behavior | SQLite outbox + auto-retry |
| v1 platform | Android APK |
| PC OS | Windows (watch folder path TBD) |

## User Flow

1. Open app → camera preview
2. Tap shutter → confirm or retake
3. Pick task from multiple-choice list
4. App builds markdown file, queues upload
5. On success → toast, return to camera
6. On failure → item stays in outbox, auto-retry on interval and when network returns

## Data Formats

### Filename

```
20250619_143022.jpg
20250619_143022.md
```

Use local device time. On collision (same second), append `_1`, `_2`, etc.

### Markdown file (`.md`)

```markdown
# Extract table to Excel

Read the attached image. Extract all table data into a structured format.
Preserve column headers. Output as CSV-ready data.
```

- `# {task label}` — heading from selected task
- Body — instruction text from same task entry

### `tasks.yaml` (PC)

```yaml
tasks:
  - id: extract-excel
    label: Extract table to Excel
    instructions: |
      Read the attached image. Extract all table data into a structured format.
      Preserve column headers. Output as CSV-ready data.
  - id: summarize-receipt
    label: Summarize receipt
    instructions: |
      Read the attached image. List items, prices, and total.
```

### `GET /tasks` response

```json
{
  "tasks": [
    {
      "id": "extract-excel",
      "label": "Extract table to Excel",
      "instructions": "Read the attached image..."
    }
  ]
}
```

### `POST /upload`

```
POST /upload
Authorization: Bearer <token>
Content-Type: multipart/form-data

Fields:
  basename: "20250619_143022"
  image: (jpeg bytes)
  markdown: (utf-8 string)
```

PC writes:
- `{watch_folder}/20250619_143022.jpg`
- `{watch_folder}/20250619_143022.md`

Files are written atomically (write to `.tmp`, then rename) so the watch folder never contains incomplete pairs.

## Settings (v1)

- PC host (Tailscale IP or MagicDNS hostname)
- Port (default `8787`)
- Bearer token
- "Test connection" button → `GET /tasks`

## Outbox Queue

SQLite schema:

```
id, basename, image_path, md_content, created_at, attempts, last_error
```

- Retry every 30 seconds when pending items exist
- No max attempt cap in v1 (user can delete stuck items from outbox UI)
- 401 responses: stop retrying until token is fixed in settings
- Survives app kill (persistent on disk)

Outbox UI: badge on home screen; tap to view pending items, manual retry, or delete.

## Error Handling

| Situation | Behavior |
|-----------|----------|
| Camera permission denied | Block screen, link to system settings |
| No tasks from PC | Use bundled `assets/tasks.json` |
| PC unreachable on send | Save to outbox, show "Queued" |
| Upload 401 | Show "Bad token", pause retry until settings updated |
| Upload 413 / disk full | Show error, keep in outbox |
| Tailscale down | Queue only, retry when connectivity returns |
| App killed mid-upload | Outbox item persists, retry on next launch |

## Flutter Dev Setup (Linux or macOS)

Implementation phase installs and verifies on whichever dev machine you use (Linux PC or macOS laptop). See plan Task 1 for OS-specific commands; goals are identical:

1. Install Flutter SDK (stable channel)
2. Run `flutter doctor` and resolve Android toolchain gaps
3. Install Android SDK (Android Studio or command-line tools)
4. Accept SDK licenses
5. Enable USB debugging on Android device
6. Verify `flutter devices` sees the phone
7. `flutter run` for debug deploy
8. `flutter build apk --release` for distributable APK

Prerequisites to verify: `git`, `curl`, `unzip`, JDK 17, Android SDK, `adb`.

**macOS:** `brew` + `openjdk@17` or Android Studio; shell profile usually `~/.zshrc`.  
**Linux:** `apt` packages per plan Task 1; shell profile usually `~/.bashrc`.

Project bootstrap:

```
flutter create --org com.chupanhexcel --project-name chup_anh_excel .
# add dependencies: camera, http, sqflite, path_provider
```

## Testing (v1)

| Layer | Scope |
|-------|-------|
| Unit | Markdown builder, basename generator, API client (mocked) |
| Manual | Real Android device: camera → pick task → upload → files on PC |
| Deferred | iOS simulator, E2E automation, ChatGPT integration |

## Future (post-v1)

- iOS build + TestFlight distribution
- Finalize Windows watch folder path for ChatGPT Computer Use
- Optional: in-app task preview, image compression settings
- Optional: gallery copy of sent photos

## Alternatives Considered

| Option | Verdict |
|--------|---------|
| Local WiFi HTTP only | Rejected — fails on mobile data / away from home |
| Cloud sync (Drive/Dropbox) | Rejected — extra auth, latency, complexity |
| Syncthing | Rejected — heavy for one-way push |
| Hardcoded task list | Rejected — requires rebuild to change tasks |
| `.txt` task file | Rejected — user chose `.md` markdown |
| Node.js receiver | Viable but no advantage over Python for file-drop use case |

**Recommended approach:** Flutter + Python FastAPI receiver over Tailscale with bearer auth.
