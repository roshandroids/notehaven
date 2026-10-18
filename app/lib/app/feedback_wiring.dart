import '../features/settings/presentation/settings_providers.dart';
import '../shared/feedback/ui_feedback.dart';

/// Binds the saved haptics/sounds toggles to the feedback service.
final feedbackPrefsOverride = feedbackPrefsProvider.overrideWith((ref) {
  final s = ref.watch(settingsProvider);
  return FeedbackPrefs(haptics: s.hapticsEnabled, sounds: s.soundsEnabled);
});
