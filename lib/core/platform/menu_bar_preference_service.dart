import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class MenuBarPreferenceService {
  bool get isSupported;

  Future<bool> getVisibility();

  Future<void> setVisibility(bool visible);
}

final class MethodChannelMenuBarPreferenceService
    implements MenuBarPreferenceService {
  MethodChannelMenuBarPreferenceService({
    MethodChannel? channel,
    bool? isSupported,
  }) : _channel =
           channel ?? const MethodChannel('com.aitrans/menu_bar_preferences'),
       _isSupported = isSupported ?? Platform.isMacOS;

  final MethodChannel _channel;
  final bool _isSupported;

  @override
  bool get isSupported => _isSupported;

  @override
  Future<bool> getVisibility() async {
    _requireSupported();
    final visible = await _channel.invokeMethod<bool>('getVisibility');
    if (visible == null) throw _invalidVisibilityResult();
    return visible;
  }

  @override
  Future<void> setVisibility(bool visible) async {
    _requireSupported();
    final applied = await _channel.invokeMethod<bool>('setVisibility', visible);
    if (applied != visible) throw _invalidVisibilityResult();
  }

  void _requireSupported() {
    if (!_isSupported) {
      throw UnsupportedError(
        'Menu bar preferences are only available on macOS.',
      );
    }
  }

  PlatformException _invalidVisibilityResult() {
    return PlatformException(
      code: 'invalid_menu_bar_visibility',
      message: '状态栏可见性返回值无效。',
    );
  }
}

final menuBarPreferenceServiceProvider = Provider<MenuBarPreferenceService>(
  (ref) => MethodChannelMenuBarPreferenceService(),
);
