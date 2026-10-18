# ADR-0004: Feedback service, generated sounds, motion setting

Status: accepted.

**Context:** the app should feel responsive (haptics, sound, motion) without hurting accessibility, performance or licensing of an open-source template.

**Decision:**
- `shared/feedback/` holds `UiFeedback` (interface), `FeedbackEvent` names and `DeviceUiFeedback`. Screens call `ref.read(feedbackProvider).play(event)`; tests override the provider with a fake. Haptics run only on iOS/Android (web and desktop no-op) and never throw.
- Settings (`AppSettings`: `hapticsEnabled` default on, `soundsEnabled` default off, `motion` system/reduced) live in the settings feature. `app/feedback_wiring.dart` binds them to `feedbackPrefsProvider` (composition root), keeping features independent. Without that override the service is silent.
- Sounds: tones are synthesized in code to WAV bytes (`tones.dart`), so no third-party audio is bundled and there is nothing to license. Player: `audioplayers` (MIT, publisher blue-fire.xyz, all six target platforms on pub.dev; chosen over `flutter_soloud`, which needs native build hooks and extra web setup).
- "Reduced" motion is applied by overriding `MediaQuery.disableAnimations` in `App`, so the existing `reduceMotion(context)` checks cover both the OS flag and the setting.

**Consequences / limits:**
- `BytesSource` support differs per platform in `audioplayers`; failures are swallowed, so an unsupported platform stays silent. Not verified on Windows/Linux, and no real audio or haptics were tested on device.
- Duplicate has no undo snackbar (the repository does not return the new id through `NoteActions.duplicate`).
- `SharedAxisTransition` page transitions ignore the reduce-motion setting.
