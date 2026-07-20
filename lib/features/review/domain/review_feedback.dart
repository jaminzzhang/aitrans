enum ReviewFeedback { forgotten, fuzzy, remembered }

class ReviewFeedbackEvent {
  ReviewFeedbackEvent({required String id, required this.feedback})
    : id = id.trim() {
    if (this.id.isEmpty) {
      throw ArgumentError('A feedback event id is required.');
    }
  }

  final String id;
  final ReviewFeedback feedback;
}
