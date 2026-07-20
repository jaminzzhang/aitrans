import 'package:unorm_dart/unorm_dart.dart' as unorm;

import '../../translate/models/translation_presentation.dart';

class ReviewIdentity {
  static const int schemaVersion = 1;

  final String normalizedTerm;
  final TranslationSourceLanguage actualSourceLanguage;
  final TranslationSourceLanguage targetLanguage;

  const ReviewIdentity._({
    required this.normalizedTerm,
    required this.actualSourceLanguage,
    required this.targetLanguage,
  });

  factory ReviewIdentity.create({
    required String correctedTerm,
    required TranslationSourceLanguage actualSourceLanguage,
    required TranslationSourceLanguage targetLanguage,
  }) {
    if (actualSourceLanguage == TranslationSourceLanguage.unknown) {
      throw ArgumentError.value(
        actualSourceLanguage,
        'actualSourceLanguage',
        'A known source language is required.',
      );
    }
    if (targetLanguage == TranslationSourceLanguage.unknown) {
      throw ArgumentError.value(
        targetLanguage,
        'targetLanguage',
        'A known target language is required.',
      );
    }

    final normalizedTerm = _normalize(correctedTerm);
    if (normalizedTerm.isEmpty) {
      throw ArgumentError('A non-empty corrected term is required.');
    }

    return ReviewIdentity._(
      normalizedTerm: normalizedTerm,
      actualSourceLanguage: actualSourceLanguage,
      targetLanguage: targetLanguage,
    );
  }

  factory ReviewIdentity.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported review identity schema.');
    }

    final term = json['term'];
    final sourceLanguage = json['sourceLanguage'];
    final targetLanguage = json['targetLanguage'];
    if (term is! String ||
        sourceLanguage is! String ||
        targetLanguage is! String) {
      throw const FormatException('Malformed review identity.');
    }

    final parsedSourceLanguage = TranslationSourceLanguage.parse(
      sourceLanguage,
    );
    final parsedTargetLanguage = TranslationSourceLanguage.parse(
      targetLanguage,
    );
    if (parsedSourceLanguage == TranslationSourceLanguage.unknown ||
        parsedTargetLanguage == TranslationSourceLanguage.unknown) {
      throw const FormatException('Unknown review identity language.');
    }

    try {
      return ReviewIdentity.create(
        correctedTerm: term,
        actualSourceLanguage: parsedSourceLanguage,
        targetLanguage: parsedTargetLanguage,
      );
    } on ArgumentError {
      throw const FormatException('Malformed review identity term.');
    }
  }

  Map<String, Object> toJson() => {
    'schemaVersion': schemaVersion,
    'term': normalizedTerm,
    'sourceLanguage': actualSourceLanguage.name,
    'targetLanguage': targetLanguage.name,
  };

  static String _normalize(String value) {
    return unorm
        .nfkc(value)
        .trim()
        .replaceAll(RegExp(r'\s+', unicode: true), ' ')
        .toLowerCase();
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ReviewIdentity &&
            normalizedTerm == other.normalizedTerm &&
            actualSourceLanguage == other.actualSourceLanguage &&
            targetLanguage == other.targetLanguage;
  }

  @override
  int get hashCode =>
      Object.hash(normalizedTerm, actualSourceLanguage, targetLanguage);
}
