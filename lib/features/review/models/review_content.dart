import '../../../core/ai/review_ai_models.dart';

enum ReviewMovieContentKind { fictionalScene, approvedQuote }

class ReviewEverydayUsage {
  ReviewEverydayUsage({
    required String situation,
    required String original,
    required String translation,
  }) : situation = _requiredText(situation, maxRunes: 120),
       original = _requiredText(original, maxRunes: 400),
       translation = _requiredText(translation, maxRunes: 400);

  factory ReviewEverydayUsage.fromJson(Map<String, dynamic> json) {
    if (json.length != 3 ||
        json.keys.toSet().difference({
          'situation',
          'original',
          'translation',
        }).isNotEmpty ||
        json['situation'] is! String ||
        json['original'] is! String ||
        json['translation'] is! String) {
      throw const FormatException('Malformed review usage.');
    }
    return ReviewEverydayUsage(
      situation: json['situation'] as String,
      original: json['original'] as String,
      translation: json['translation'] as String,
    );
  }

  final String situation;
  final String original;
  final String translation;

  Map<String, Object> toJson() => {
    'situation': situation,
    'original': original,
    'translation': translation,
  };
}

class ReviewMovieContent {
  factory ReviewMovieContent.fictionalScene({
    required String dialogue,
    required String translation,
  }) {
    return ReviewMovieContent._(
      kind: ReviewMovieContentKind.fictionalScene,
      dialogue: _requiredText(dialogue, maxRunes: 400),
      translation: _requiredText(translation, maxRunes: 400),
    );
  }

  factory ReviewMovieContent.approvedQuote({
    required String workTitle,
    required String sourceReference,
    required String rightsReference,
    required String dialogue,
    required String translation,
  }) {
    return ReviewMovieContent._(
      kind: ReviewMovieContentKind.approvedQuote,
      workTitle: _requiredText(workTitle, maxRunes: 200),
      sourceReference: _requiredText(sourceReference, maxRunes: 240),
      rightsReference: _requiredText(rightsReference, maxRunes: 240),
      dialogue: _requiredText(dialogue, maxRunes: 400),
      translation: _requiredText(translation, maxRunes: 400),
    );
  }

  const ReviewMovieContent._({
    required this.kind,
    required this.dialogue,
    required this.translation,
    this.workTitle,
    this.sourceReference,
    this.rightsReference,
  });

  factory ReviewMovieContent.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    if (kind == ReviewMovieContentKind.fictionalScene.name) {
      if (json.length != 3 ||
          json.keys.toSet().difference({
            'kind',
            'dialogue',
            'translation',
          }).isNotEmpty ||
          json['dialogue'] is! String ||
          json['translation'] is! String) {
        throw const FormatException('Malformed fictional dialogue.');
      }
      return ReviewMovieContent.fictionalScene(
        dialogue: json['dialogue'] as String,
        translation: json['translation'] as String,
      );
    }
    if (kind == ReviewMovieContentKind.approvedQuote.name) {
      if (json.length != 6 ||
          json.keys.toSet().difference({
            'kind',
            'workTitle',
            'sourceReference',
            'rightsReference',
            'dialogue',
            'translation',
          }).isNotEmpty ||
          json['workTitle'] is! String ||
          json['sourceReference'] is! String ||
          json['rightsReference'] is! String ||
          json['dialogue'] is! String ||
          json['translation'] is! String) {
        throw const FormatException('Malformed approved quote.');
      }
      return ReviewMovieContent.approvedQuote(
        workTitle: json['workTitle'] as String,
        sourceReference: json['sourceReference'] as String,
        rightsReference: json['rightsReference'] as String,
        dialogue: json['dialogue'] as String,
        translation: json['translation'] as String,
      );
    }
    throw const FormatException('Unknown movie content identity.');
  }

  final ReviewMovieContentKind kind;
  final String dialogue;
  final String translation;
  final String? workTitle;
  final String? sourceReference;
  final String? rightsReference;

  String get displayLabel => switch (kind) {
    ReviewMovieContentKind.fictionalScene => '影视化场景对白',
    ReviewMovieContentKind.approvedQuote => '已批准影片台词',
  };

  Map<String, Object> toJson() => switch (kind) {
    ReviewMovieContentKind.fictionalScene => {
      'kind': kind.name,
      'dialogue': dialogue,
      'translation': translation,
    },
    ReviewMovieContentKind.approvedQuote => {
      'kind': kind.name,
      'workTitle': workTitle!,
      'sourceReference': sourceReference!,
      'rightsReference': rightsReference!,
      'dialogue': dialogue,
      'translation': translation,
    },
  };
}

class ReviewTextContent {
  static const schemaVersion = 1;

  ReviewTextContent({
    required Iterable<ReviewEverydayUsage> everydayUsages,
    required this.movieContent,
  }) : everydayUsages = List.unmodifiable(everydayUsages) {
    if (this.everydayUsages.isEmpty || this.everydayUsages.length > 3) {
      throw ArgumentError('Review content requires 1 to 3 usages.');
    }
  }

  factory ReviewTextContent.fromAI(ReviewAITextContentResponse response) {
    return ReviewTextContent(
      everydayUsages: response.everydayUsages.map(
        (usage) => ReviewEverydayUsage(
          situation: usage.situation,
          original: usage.original,
          translation: usage.translation,
        ),
      ),
      movieContent: ReviewMovieContent.fictionalScene(
        dialogue: response.fictionalDialogue.dialogue,
        translation: response.fictionalDialogue.translation,
      ),
    );
  }

  factory ReviewTextContent.fromJson(Map<String, dynamic> json) {
    try {
      if (json.length != 3 ||
          json['schemaVersion'] != schemaVersion ||
          json['everydayUsages'] is! List ||
          json['movieContent'] is! Map) {
        throw const FormatException('Malformed review content.');
      }
      return ReviewTextContent(
        everydayUsages: (json['everydayUsages'] as List).map((value) {
          if (value is! Map) {
            throw const FormatException('Malformed review usage.');
          }
          return ReviewEverydayUsage.fromJson(value.cast<String, dynamic>());
        }),
        movieContent: ReviewMovieContent.fromJson(
          (json['movieContent'] as Map).cast<String, dynamic>(),
        ),
      );
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException('Malformed review content.');
    }
  }

  final List<ReviewEverydayUsage> everydayUsages;
  final ReviewMovieContent movieContent;

  Map<String, Object> toJson() => {
    'schemaVersion': schemaVersion,
    'everydayUsages': everydayUsages.map((usage) => usage.toJson()).toList(),
    'movieContent': movieContent.toJson(),
  };
}

String _requiredText(String value, {required int maxRunes}) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.runes.length > maxRunes) {
    throw ArgumentError('Review content field is malformed.');
  }
  return normalized;
}
