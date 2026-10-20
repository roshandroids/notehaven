# 0005 — Local crash log, manual update check, custom sounds

## Decision
- **Crash handling:** `main` installs `FlutterError.onError` and `PlatformDispatcher.onError` before anything else runs. The last 20 errors are stored in `shared_preferences` on the device only. Nothing is uploaded; users can view, share or clear them in Settings. Release builds show a plain message instead of the red error screen.
- **Update check:** a button in Settings asks GitHub's "latest release" API once per tap. There is no check at launch, so the app makes no network calls on its own. The current version is the top CHANGELOG heading (a test keeps it equal to `pubspec.yaml`).
- **Custom sounds:** the user picks an audio file (max 2 MB) per event. It is copied to `<support>/sounds/<event>.<ext>`, because picker paths live in the cache, which can be cleared. The file's presence is the setting, so no settings schema change. Missing file means the built-in tone. Not offered on web.
- **Licenses:** Flutter's license page lists package licenses; `registerExtraLicenses` adds the app, unDraw and Google Fonts.

## Why
Opt-in, local-first: no telemetry service to run, no data leaves the device unless the user shares it.
