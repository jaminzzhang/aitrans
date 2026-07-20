class ReviewAICandidate {
  ReviewAICandidate({
    required String id,
    required String term,
    required String sourceLanguage,
    required String targetLanguage,
    required this.translationCount,
    required this.consecutiveRememberedCount,
    required this.forgetCount,
    required this.overdueMinutes,
    required this.daysSinceLastReview,
  }) : id = id.trim(),
       term = term.trim(),
       sourceLanguage = sourceLanguage.trim(),
       targetLanguage = targetLanguage.trim() {
    if (this.id.isEmpty ||
        this.term.isEmpty ||
        this.sourceLanguage.isEmpty ||
        this.targetLanguage.isEmpty) {
      throw ArgumentError('Review AI candidates require non-empty fields.');
    }
    if (translationCount < 1 ||
        consecutiveRememberedCount < 0 ||
        forgetCount < 0 ||
        overdueMinutes < 0 ||
        (daysSinceLastReview != null && daysSinceLastReview! < 0)) {
      throw ArgumentError('Review AI candidate counters must be non-negative.');
    }
  }

  final String id;
  final String term;
  final String sourceLanguage;
  final String targetLanguage;
  final int translationCount;
  final int consecutiveRememberedCount;
  final int forgetCount;
  final int overdueMinutes;
  final int? daysSinceLastReview;

  Map<String, Object?> toJson() => {
    'id': id,
    'term': term,
    'sourceLanguage': sourceLanguage,
    'targetLanguage': targetLanguage,
    'translationCount': translationCount,
    'consecutiveRememberedCount': consecutiveRememberedCount,
    'forgetCount': forgetCount,
    'overdueMinutes': overdueMinutes,
    'daysSinceLastReview': daysSinceLastReview,
  };
}

class ReviewAIRankRequest {
  static const contractVersion = 1;

  ReviewAIRankRequest({required Iterable<ReviewAICandidate> candidates})
    : candidates = List.unmodifiable(candidates) {
    if (this.candidates.isEmpty || this.candidates.length > 50) {
      throw ArgumentError('Review AI requests require 1 to 50 candidates.');
    }
    final ids = this.candidates.map((candidate) => candidate.id).toSet();
    if (ids.length != this.candidates.length) {
      throw ArgumentError('Review AI candidate ids must be unique.');
    }
  }

  final List<ReviewAICandidate> candidates;

  Map<String, Object> toJson() => {
    'contractVersion': contractVersion,
    'candidates': candidates.map((candidate) => candidate.toJson()).toList(),
  };
}

class ReviewAIRankedItem {
  ReviewAIRankedItem({required String id, required String reason})
    : id = id.trim(),
      reason = reason.trim() {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(this.id) ||
        this.reason.isEmpty ||
        this.reason.runes.length > 240) {
      throw ArgumentError('Review AI ranked items are malformed.');
    }
  }

  final String id;
  final String reason;
}

class ReviewAIRankResponse {
  ReviewAIRankResponse({required Iterable<ReviewAIRankedItem> rankedItems})
    : rankedItems = List.unmodifiable(rankedItems) {
    if (this.rankedItems.isEmpty || this.rankedItems.length > 10) {
      throw ArgumentError('Review AI responses require 1 to 10 items.');
    }
    final ids = this.rankedItems.map((item) => item.id).toSet();
    if (ids.length != this.rankedItems.length) {
      throw ArgumentError('Review AI response ids must be unique.');
    }
  }

  factory ReviewAIRankResponse.fromJson(Map<String, dynamic> json) {
    try {
      if (json.length != 2 ||
          json['contractVersion'] != ReviewAIRankRequest.contractVersion ||
          json['rankedItems'] is! List) {
        throw const FormatException('Malformed review ranking response.');
      }
      final items = (json['rankedItems'] as List).map((value) {
        if (value is! Map || value.length != 2) {
          throw const FormatException('Malformed review ranking item.');
        }
        final item = value.cast<String, dynamic>();
        final id = item['id'];
        final reason = item['reason'];
        if (id is! String || reason is! String) {
          throw const FormatException('Malformed review ranking item.');
        }
        return ReviewAIRankedItem(id: id, reason: reason);
      });
      return ReviewAIRankResponse(rankedItems: items);
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException('Malformed review ranking response.');
    }
  }

  final List<ReviewAIRankedItem> rankedItems;
}

class ReviewAITextContentRequest {
  static const contractVersion = 1;

  ReviewAITextContentRequest({
    required String term,
    required String sourceLanguage,
    required String targetLanguage,
    required String primaryMeaning,
  }) : term = _requiredReviewText(term, maxRunes: 160),
       sourceLanguage = _requiredReviewText(sourceLanguage, maxRunes: 16),
       targetLanguage = _requiredReviewText(targetLanguage, maxRunes: 16),
       primaryMeaning = _requiredReviewText(primaryMeaning, maxRunes: 240);

  final String term;
  final String sourceLanguage;
  final String targetLanguage;
  final String primaryMeaning;

  Map<String, Object> toJson() => {
    'contractVersion': contractVersion,
    'term': term,
    'sourceLanguage': sourceLanguage,
    'targetLanguage': targetLanguage,
    'primaryMeaning': primaryMeaning,
  };
}

class ReviewAIEverydayUsage {
  ReviewAIEverydayUsage({
    required String situation,
    required String original,
    required String translation,
  }) : situation = _requiredReviewText(situation, maxRunes: 120),
       original = _requiredReviewText(original, maxRunes: 400),
       translation = _requiredReviewText(translation, maxRunes: 400);

  final String situation;
  final String original;
  final String translation;
}

class ReviewAIFictionalDialogue {
  ReviewAIFictionalDialogue({
    required String dialogue,
    required String translation,
  }) : dialogue = _requiredReviewText(dialogue, maxRunes: 400),
       translation = _requiredReviewText(translation, maxRunes: 400);

  final String dialogue;
  final String translation;
}

class ReviewAITextContentResponse {
  ReviewAITextContentResponse({
    required Iterable<ReviewAIEverydayUsage> everydayUsages,
    required this.fictionalDialogue,
  }) : everydayUsages = List.unmodifiable(everydayUsages) {
    if (this.everydayUsages.isEmpty || this.everydayUsages.length > 3) {
      throw ArgumentError('Review text requires 1 to 3 everyday usages.');
    }
  }

  factory ReviewAITextContentResponse.fromJson(Map<String, dynamic> json) {
    try {
      if (json.length != 3 ||
          json['contractVersion'] !=
              ReviewAITextContentRequest.contractVersion ||
          json['everydayUsages'] is! List ||
          json['fictionalDialogue'] is! Map) {
        throw const FormatException('Malformed review text response.');
      }
      final usages = (json['everydayUsages'] as List).map((value) {
        if (value is! Map || value.length != 3) {
          throw const FormatException('Malformed everyday usage.');
        }
        final item = value.cast<String, dynamic>();
        if (item.keys.toSet().difference({
          'situation',
          'original',
          'translation',
        }).isNotEmpty) {
          throw const FormatException('Malformed everyday usage.');
        }
        final situation = item['situation'];
        final original = item['original'];
        final translation = item['translation'];
        if (situation is! String ||
            original is! String ||
            translation is! String) {
          throw const FormatException('Malformed everyday usage.');
        }
        return ReviewAIEverydayUsage(
          situation: situation,
          original: original,
          translation: translation,
        );
      });
      final dialogueJson = (json['fictionalDialogue'] as Map)
          .cast<String, dynamic>();
      if (dialogueJson.length != 2 ||
          dialogueJson.keys.toSet().difference({
            'dialogue',
            'translation',
          }).isNotEmpty ||
          dialogueJson['dialogue'] is! String ||
          dialogueJson['translation'] is! String) {
        throw const FormatException('Malformed fictional dialogue.');
      }
      return ReviewAITextContentResponse(
        everydayUsages: usages,
        fictionalDialogue: ReviewAIFictionalDialogue(
          dialogue: dialogueJson['dialogue'] as String,
          translation: dialogueJson['translation'] as String,
        ),
      );
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException('Malformed review text response.');
    }
  }

  final List<ReviewAIEverydayUsage> everydayUsages;
  final ReviewAIFictionalDialogue fictionalDialogue;
}

enum ReviewAIImageCapability { unsupported, supported }

class ReviewAIImageRequest {
  static const contractVersion = 1;

  ReviewAIImageRequest({
    required String term,
    required String sourceLanguage,
    required String targetLanguage,
    required String primaryMeaning,
  }) : term = _requiredReviewText(term, maxRunes: 160),
       sourceLanguage = _requiredReviewText(sourceLanguage, maxRunes: 16),
       targetLanguage = _requiredReviewText(targetLanguage, maxRunes: 16),
       primaryMeaning = _requiredReviewText(primaryMeaning, maxRunes: 240);

  final String term;
  final String sourceLanguage;
  final String targetLanguage;
  final String primaryMeaning;

  Map<String, Object> toJson() => {
    'contractVersion': contractVersion,
    'term': term,
    'sourceLanguage': sourceLanguage,
    'targetLanguage': targetLanguage,
    'primaryMeaning': primaryMeaning,
  };
}

class ReviewAIImageResponse {
  static const maxBytes = 8 * 1024 * 1024;
  static const supportedMediaTypes = {'image/png', 'image/jpeg'};

  ReviewAIImageResponse({
    required String mediaType,
    required Iterable<int> bytes,
  }) : mediaType = mediaType.trim().toLowerCase(),
       bytes = List<int>.unmodifiable(bytes) {
    if (!supportedMediaTypes.contains(this.mediaType) ||
        this.bytes.isEmpty ||
        this.bytes.length > maxBytes ||
        this.bytes.any((byte) => byte < 0 || byte > 255) ||
        !_hasExpectedSignature(this.mediaType, this.bytes)) {
      throw ArgumentError('Review image response is malformed.');
    }
  }

  final String mediaType;
  final List<int> bytes;

  static bool _hasExpectedSignature(String mediaType, List<int> bytes) {
    final signature = switch (mediaType) {
      'image/png' => const [137, 80, 78, 71, 13, 10, 26, 10],
      'image/jpeg' => const [255, 216, 255],
      _ => const <int>[],
    };
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) return false;
    }
    return signature.isNotEmpty;
  }
}

String _requiredReviewText(String value, {required int maxRunes}) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.runes.length > maxRunes) {
    throw ArgumentError('Review AI text field is malformed.');
  }
  return normalized;
}
