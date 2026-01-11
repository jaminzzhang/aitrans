import 'package:flutter/material.dart';

/// 应用主题配置
class AppTheme {
  /// 浅色主题
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.light,
      ),
      fontFamily: 'SF Pro Text',
    );
  }

  /// 深色主题
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.dark,
      ),
      fontFamily: 'SF Pro Text',
    );
  }
}
