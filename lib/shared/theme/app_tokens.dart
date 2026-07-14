import 'package:flutter/material.dart';

/// 设计 token 单一来源。
///
/// 集中颜色、圆角、间距与排版，避免 UI 各处散落魔法值。
/// 排版遵循 Apple 的尺寸相关字距规则：大字负字距紧行高，小字正字距。
class AppColors {
  AppColors._();

  /// 浅色调色板。
  static const light = AppPalette(
    bg: Color(0xFFFBFBFD),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF2F2F4),
    inkPrimary: Color(0xFF1D1D1F),
    inkSecondary: Color(0xFF6E6E73),
    inkTertiary: Color(0xFF8E8E93),
    accent: Color(0xFF0071E3),
    accentMuted: Color(0xFFE8F1FE),
    success: Color(0xFF34C759),
    error: Color(0xFFFF3B30),
    divider: Color(0xFFE5E5EA),
    scrim: Color(0x33000000),
  );

  /// 深色调色板。
  static const dark = AppPalette(
    bg: Color(0xFF1C1C1E),
    surface: Color(0xFF2C2C2E),
    surfaceElevated: Color(0xFF3A3A3C),
    inkPrimary: Color(0xFFF5F5F7),
    inkSecondary: Color(0xFFAEAEB2),
    inkTertiary: Color(0xFF8E8E93),
    accent: Color(0xFF0A84FF),
    accentMuted: Color(0xFF1B2A3D),
    success: Color(0xFF30D158),
    error: Color(0xFFFF453A),
    divider: Color(0xFF3A3A3C),
    scrim: Color(0x66000000),
  );

  /// 按亮度取对应调色板。
  static AppPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

@immutable
class AppPalette {
  final Color bg;
  final Color surface;
  final Color surfaceElevated;
  final Color inkPrimary;
  final Color inkSecondary;
  final Color inkTertiary;
  final Color accent;
  final Color accentMuted;
  final Color success;
  final Color error;
  final Color divider;
  final Color scrim;

  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceElevated,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.inkTertiary,
    required this.accent,
    required this.accentMuted,
    required this.success,
    required this.error,
    required this.divider,
    required this.scrim,
  });

  /// 半透明工具栏背景（用于毛玻璃材质）。
  Color get materialBar => this == AppColors.light
      ? const Color(0xCCFFFFFF)
      : const Color(0xCC2C2C2E);

  /// 工具栏顶部 1px 亮边（模拟光打在玻璃上）。
  Color get materialTopEdge => this == AppColors.light
      ? const Color(0x66FFFFFF)
      : const Color(0x44FFFFFF);
}

/// 统一圆角刻度。
class AppRadii {
  AppRadii._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;

  static BorderRadius smRadius = BorderRadius.circular(sm);
  static BorderRadius mdRadius = BorderRadius.circular(md);
  static BorderRadius lgRadius = BorderRadius.circular(lg);
}

/// 统一间距刻度（基于 4 的倍数）。
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// 尺寸相关的排版样式。
///
/// 大字给负字距、紧行高；小字给正字距。绝不全局统一 letter-spacing。
class AppTypography {
  AppTypography._();

  static const String _family = 'SF Pro Text';

  /// 译文英雄区：大字号、负字距、紧行高。
  static TextStyle hero(TextStyle base) => base.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.15,
    letterSpacing: -0.02,
  );

  /// 英雄区输入文字（保留可读字号，便于编辑）。
  static TextStyle input(TextStyle base) =>
      base.copyWith(fontSize: 17, fontWeight: FontWeight.w400, height: 1.4);

  /// 分节标题：小字、正字距、稍紧。
  static TextStyle sectionHeader(TextStyle base) => base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.04,
  );

  /// 正文（例句原文、题目）。
  static TextStyle body(TextStyle base) =>
      base.copyWith(fontSize: 17, fontWeight: FontWeight.w400, height: 1.45);

  /// 译文辅助行（中文释义、卡片翻译）。
  static TextStyle bodyMuted(TextStyle base) =>
      base.copyWith(fontSize: 15, fontWeight: FontWeight.w400, height: 1.5);

  /// 微标签（胶囊、计数、cached）。
  static TextStyle caption(TextStyle base) => base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.02,
  );

  /// 系统字体常量，供主题使用。
  static String get family => _family;
}
