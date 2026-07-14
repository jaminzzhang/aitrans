import 'dart:io';

import 'package:flutter/services.dart';

class LocalStorageProtection {
  const LocalStorageProtection();

  static const _channel = MethodChannel('aitrans/local_storage_protection');

  Future<void> excludeFromBackup(Iterable<String> paths) async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>('excludeFromBackup', <String, Object?>{
      'paths': paths.toList(growable: false),
    });
  }
}
