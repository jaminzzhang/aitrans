import 'dart:io';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/external_translation_config.dart';
import '../../../core/platform/external_translation_platform_bridge.dart';
import '../../../core/platform/external_translation_request.dart';
import 'translate_controller.dart';

final externalTranslationConfigProvider = Provider<ExternalTranslationConfig>(
  (ref) => ExternalTranslationConfig(),
);

final externalTranslationRequestValidatorProvider =
    Provider<ExternalTranslationRequestValidator>((ref) {
      return ExternalTranslationRequestValidator(
        ref.watch(externalTranslationConfigProvider),
      );
    });

sealed class ExternalTranslationHandlingState {
  const ExternalTranslationHandlingState();
}

final class ExternalTranslationIdle extends ExternalTranslationHandlingState {
  const ExternalTranslationIdle();
}

final class ExternalTranslationAccepted
    extends ExternalTranslationHandlingState {
  final int sequence;

  const ExternalTranslationAccepted(this.sequence);
}

final class ExternalTranslationRejected
    extends ExternalTranslationHandlingState {
  final int sequence;
  final ExternalTranslationRejectionReason reason;
  final String? userMessage;

  const ExternalTranslationRejected({
    required this.sequence,
    required this.reason,
    this.userMessage,
  });
}

final class ExternalTranslationIgnored
    extends ExternalTranslationHandlingState {
  final int sequence;
  final int latestProcessedSequence;

  const ExternalTranslationIgnored({
    required this.sequence,
    required this.latestProcessedSequence,
  });
}

final class ExternalTranslationCoordinator
    extends StateNotifier<ExternalTranslationHandlingState> {
  ExternalTranslationCoordinator(this.ref)
    : super(const ExternalTranslationIdle());

  final Ref ref;
  int _latestProcessedSequence = 0;

  void handle({
    required int sequence,
    required ExternalTranslationSource source,
    required String text,
  }) {
    if (sequence > 0 && sequence <= _latestProcessedSequence) {
      state = ExternalTranslationIgnored(
        sequence: sequence,
        latestProcessedSequence: _latestProcessedSequence,
      );
      return;
    }

    final result = ref
        .read(externalTranslationRequestValidatorProvider)
        .validate(sequence: sequence, source: source, text: text);
    if (sequence > 0) _latestProcessedSequence = sequence;

    if (result case RejectedExternalTranslationRequest()) {
      state = ExternalTranslationRejected(
        sequence: sequence,
        reason: result.reason,
        userMessage: result.userMessage,
      );
      return;
    }

    final request = (result as AcceptedExternalTranslationRequest).request;
    ref.read(inputTextProvider.notifier).state = request.text;
    ref.read(auxiliaryControllerProvider.notifier).clear();
    ref.read(translateControllerProvider.notifier).translateNow(request.text);
    state = ExternalTranslationAccepted(request.sequence);
  }
}

final externalTranslationCoordinatorProvider =
    StateNotifierProvider<
      ExternalTranslationCoordinator,
      ExternalTranslationHandlingState
    >((ref) => ExternalTranslationCoordinator(ref));

final externalTranslationPlatformBridgeProvider =
    Provider<ExternalTranslationPlatformBridge?>((ref) {
      if (!Platform.isMacOS) return null;
      final bridge = ExternalTranslationPlatformBridge();
      unawaited(
        (() async {
          try {
            await bridge.start((event) {
              ref
                  .read(externalTranslationCoordinatorProvider.notifier)
                  .handle(
                    sequence: event.sequence,
                    source: event.source,
                    text: event.text,
                  );
            });
            ref.read(externalTranslationBridgeStatusProvider.notifier).state =
                ExternalTranslationBridgeStatus.ready;
          } catch (_) {
            ref.read(externalTranslationBridgeStatusProvider.notifier).state =
                ExternalTranslationBridgeStatus.unavailable;
          }
        })(),
      );
      ref.onDispose(bridge.stop);
      return bridge;
    });

enum ExternalTranslationBridgeStatus { inactive, ready, unavailable }

final externalTranslationBridgeStatusProvider =
    StateProvider<ExternalTranslationBridgeStatus>(
      (ref) => ExternalTranslationBridgeStatus.inactive,
    );
