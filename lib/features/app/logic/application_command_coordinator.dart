import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/application_command_platform_bridge.dart';

final applicationCommandEventProvider = StateProvider<ApplicationCommandEvent?>(
  (ref) => null,
);

enum ApplicationCommandBridgeStatus { inactive, ready, unavailable }

final applicationCommandBridgeStatusProvider =
    StateProvider<ApplicationCommandBridgeStatus>(
      (ref) => ApplicationCommandBridgeStatus.inactive,
    );

final applicationCommandPlatformBridgeProvider =
    Provider<ApplicationCommandPlatformBridge?>((ref) {
      if (!Platform.isMacOS) return null;
      final bridge = ApplicationCommandPlatformBridge();
      unawaited(
        (() async {
          try {
            await bridge.start((event) {
              ref.read(applicationCommandEventProvider.notifier).state = event;
            });
            ref.read(applicationCommandBridgeStatusProvider.notifier).state =
                ApplicationCommandBridgeStatus.ready;
          } catch (_) {
            ref.read(applicationCommandBridgeStatusProvider.notifier).state =
                ApplicationCommandBridgeStatus.unavailable;
          }
        })(),
      );
      ref.onDispose(bridge.stop);
      return bridge;
    });
