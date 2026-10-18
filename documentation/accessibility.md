# Accessibility

Built in and tested (`app/test/features/notes/responsive_accessibility_test.dart`):
- Each note card is a single screen-reader stop (title, body, edit time) with **Copy note** and **Delete note** custom actions, so swipe-only actions are reachable without gestures.
- Selected note is announced as selected in split view.
- Tap-target guidelines (Android 48 dp, iOS 44 pt) and labeled-tap-target checks run in CI.
- Search uses a `TextField` instead of Material `SearchBar`, because `SearchBar`'s inner field reports a 24 px tap target.
- Decorative animations are skipped when the OS "reduce motion" setting is on.
- Color themes are Material 3 schemes from FlexColorScheme; light, dark and system modes are available.

Drawings: the sketch pad has tooltips on every tool, labeled color swatches, and the embedded thumbnail is one labeled, tappable stop ("Drawing. Double tap to edit."). Freehand drawing itself needs touch, pen or mouse and cannot be done by screen reader alone; text notes remain fully usable.

Not yet done / not verified:
- No manual run with TalkBack, VoiceOver or a desktop screen reader (automated checks only).
- Contrast of every FlexColorScheme preset is not audited (the contrast guideline is not in the test suite yet).
- Large text scale (200%) layouts are not tested.
- Voice input, and accessible labels inside the future rich editor, are planned.
