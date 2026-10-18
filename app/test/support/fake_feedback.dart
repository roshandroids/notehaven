import 'package:notehaven_app/shared/feedback/ui_feedback.dart';

/// Records events instead of vibrating or playing sound.
class FakeUiFeedback implements UiFeedback {
  final events = <FeedbackEvent>[];

  @override
  void play(FeedbackEvent event) => events.add(event);
}
