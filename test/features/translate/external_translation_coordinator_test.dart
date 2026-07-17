import 'package:aitrans/core/ai/ai_provider.dart';
import 'package:aitrans/core/platform/external_translation_request.dart';
import 'package:aitrans/features/translate/logic/external_translation_coordinator.dart';
import 'package:aitrans/features/translate/logic/translate_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hotkey selection fills input without starting translation', () {
    final translateController = _RecordingTranslateController();
    final auxiliaryController = _RecordingAuxiliaryController();
    final container = ProviderContainer(
      overrides: [
        translateControllerProvider.overrideWith((_) => translateController),
        auxiliaryControllerProvider.overrideWith((_) => auxiliaryController),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(externalTranslationCoordinatorProvider.notifier)
        .handle(
          sequence: 1,
          source: ExternalTranslationSource.macosHotkey,
          text: 'selected by hotkey',
        );

    expect(container.read(inputTextProvider), 'selected by hotkey');
    expect(translateController.translatedTexts, isEmpty);
  });

  test('accepted request replaces input and starts main translation once', () {
    final translateController = _RecordingTranslateController();
    final auxiliaryController = _RecordingAuxiliaryController();
    final container = ProviderContainer(
      overrides: [
        translateControllerProvider.overrideWith((_) => translateController),
        auxiliaryControllerProvider.overrideWith((_) => auxiliaryController),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(externalTranslationCoordinatorProvider.notifier)
        .handle(
          sequence: 1,
          source: ExternalTranslationSource.macosService,
          text: '  selected text  ',
        );

    expect(container.read(inputTextProvider), 'selected text');
    expect(translateController.translatedTexts, ['selected text']);
    expect(auxiliaryController.loadedTexts, isEmpty);
    expect(
      container.read(externalTranslationCoordinatorProvider),
      isA<ExternalTranslationAccepted>().having(
        (state) => state.sequence,
        'sequence',
        1,
      ),
    );
  });

  test('duplicate and out-of-order requests do not start translation', () {
    final translateController = _RecordingTranslateController();
    final auxiliaryController = _RecordingAuxiliaryController();
    final container = ProviderContainer(
      overrides: [
        translateControllerProvider.overrideWith((_) => translateController),
        auxiliaryControllerProvider.overrideWith((_) => auxiliaryController),
      ],
    );
    addTearDown(container.dispose);
    final coordinator = container.read(
      externalTranslationCoordinatorProvider.notifier,
    );

    coordinator.handle(
      sequence: 2,
      source: ExternalTranslationSource.macosService,
      text: 'second',
    );
    coordinator.handle(
      sequence: 2,
      source: ExternalTranslationSource.macosService,
      text: 'duplicate',
    );
    expect(
      container.read(externalTranslationCoordinatorProvider),
      isA<ExternalTranslationIgnored>()
          .having((state) => state.sequence, 'sequence', 2)
          .having((state) => state.latestProcessedSequence, 'latest', 2),
    );

    coordinator.handle(
      sequence: 1,
      source: ExternalTranslationSource.macosService,
      text: 'older',
    );
    coordinator.handle(
      sequence: 3,
      source: ExternalTranslationSource.macosService,
      text: 'third',
    );

    expect(container.read(inputTextProvider), 'third');
    expect(translateController.translatedTexts, ['second', 'third']);
    expect(auxiliaryController.loadedTexts, isEmpty);
  });

  test('overlong request is rejected without changing input or calling AI', () {
    final translateController = _RecordingTranslateController();
    final auxiliaryController = _RecordingAuxiliaryController();
    final container = ProviderContainer(
      overrides: [
        translateControllerProvider.overrideWith((_) => translateController),
        auxiliaryControllerProvider.overrideWith((_) => auxiliaryController),
      ],
    );
    addTearDown(container.dispose);
    container.read(inputTextProvider.notifier).state = 'existing';
    final coordinator = container.read(
      externalTranslationCoordinatorProvider.notifier,
    );

    coordinator.handle(
      sequence: 4,
      source: ExternalTranslationSource.macosService,
      text: List.filled(5001, 'a').join(),
    );

    expect(container.read(inputTextProvider), 'existing');
    expect(translateController.translatedTexts, isEmpty);
    expect(auxiliaryController.loadedTexts, isEmpty);
    expect(
      container.read(externalTranslationCoordinatorProvider),
      isA<ExternalTranslationRejected>()
          .having((state) => state.sequence, 'sequence', 4)
          .having(
            (state) => state.reason,
            'reason',
            ExternalTranslationRejectionReason.textTooLong,
          )
          .having(
            (state) => state.userMessage,
            'message',
            '所选文本过长，请缩短至 5,000 字符以内',
          ),
    );

    coordinator.handle(
      sequence: 4,
      source: ExternalTranslationSource.macosService,
      text: 'x',
    );
    expect(
      container.read(externalTranslationCoordinatorProvider),
      isA<ExternalTranslationIgnored>(),
    );
    expect(translateController.translatedTexts, isEmpty);
  });

  test(
    'invalid sequence is rejected and does not advance the sequence gate',
    () {
      final translateController = _RecordingTranslateController();
      final container = ProviderContainer(
        overrides: [
          translateControllerProvider.overrideWith((_) => translateController),
          auxiliaryControllerProvider.overrideWith(
            (_) => _RecordingAuxiliaryController(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final coordinator = container.read(
        externalTranslationCoordinatorProvider.notifier,
      );

      coordinator.handle(
        sequence: 0,
        source: ExternalTranslationSource.macosService,
        text: 'invalid',
      );
      expect(
        container.read(externalTranslationCoordinatorProvider),
        isA<ExternalTranslationRejected>().having(
          (state) => state.reason,
          'reason',
          ExternalTranslationRejectionReason.invalidSequence,
        ),
      );

      coordinator.handle(
        sequence: 1,
        source: ExternalTranslationSource.macosService,
        text: 'valid',
      );
      expect(translateController.translatedTexts, ['valid']);
    },
  );
}

class _RecordingTranslateController extends TranslateController {
  _RecordingTranslateController() : super(_NullAIProvider(), null);

  final List<String> translatedTexts = [];

  @override
  void translateNow(String text) => translatedTexts.add(text);
}

class _RecordingAuxiliaryController extends AuxiliaryController {
  _RecordingAuxiliaryController() : super(_NullAIProvider());

  final List<String> loadedTexts = [];

  @override
  void loadContent(String word) => loadedTexts.add(word);
}

class _NullAIProvider extends AIProvider {
  @override
  String get name => 'null';

  @override
  Future<bool> testConnection() async => false;

  @override
  Stream<TranslationResult> translate({
    required String text,
    String from = 'auto',
    String to = 'zh',
  }) => const Stream.empty();

  @override
  Stream<List<Example>> getExamples(String word) => const Stream.empty();

  @override
  Stream<List<MovieQuote>> getMovieQuotes(String word) => const Stream.empty();

  @override
  Stream<List<ExamItem>> getExamItems(String word) => const Stream.empty();
}
