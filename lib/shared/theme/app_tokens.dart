import 'package:flutter/material.dart';

/// 设计 token 单一来源。
///
/// 墨笺·文学杂志风：暖象牙纸底 + 松烟墨绿 + 朱砂点缀。
/// 集中颜色、圆角、间距与排版，避免 UI 各处散落魔法值。
/// 排版遵循尺寸相关字距规则：大字负字距紧行高，小字正字距。
/// 展示位（译文/台词/例句原文）用衬线，界面 chrome 用无衬线。

/// 字体族常量。
///
/// 展示用衬线优先系统 New York（macOS/iOS 自带），fallback 到 Songti SC（CJK 衬线）
/// 与通用 serif，保证 Android 也有合理回退。不打包字体文件、不新增依赖。
class AppFonts {
  AppFonts._();

  /// 界面 chrome 字体（输入框、按钮、微标签）。
  static const String sans = 'SF Pro Text';

  /// 展示衬线字体族主名。
  static const String serif = 'New York';

  /// CJK 衬线回退（宋体）。
  static const String serifCJK = 'Songti SC';

  /// 衬线族完整回退链（Latin New York → CJK 宋体 → 通用 serif）。
  static const List<String> serifFallback = [serif, serifCJK, 'serif'];
}

class AppColors {
  AppColors._();

  /// 浅色调色板：暖象牙纸。
  static const light = AppPalette(
    bg: Color(0xFFFAF8F3),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF1ECE2),
    inkPrimary: Color(0xFF1C1A17),
    inkSecondary: Color(0xFF6B6358),
    inkTertiary: Color(0xFF9A9286),
    accent: Color(0xFF2C5F5D),
    accentMuted: Color(0xFFE4EDEA),
    success: Color(0xFF3F7A52),
    error: Color(0xFFB5482E),
    divider: Color(0xFFE8E2D6),
    scrim: Color(0x33000000),
  );

  /// 深色调色板：暖墨。
  static const dark = AppPalette(
    bg: Color(0xFF1A1815),
    surface: Color(0xFF262320),
    surfaceElevated: Color(0xFF322E2A),
    inkPrimary: Color(0xFFF2EEE6),
    inkSecondary: Color(0xFFB5ADA0),
    inkTertiary: Color(0xFF8A8378),
    accent: Color(0xFF5A8F8B),
    accentMuted: Color(0xFF2A3A38),
    success: Color(0xFF6FAA82),
    error: Color(0xFFD4674E),
    divider: Color(0xFF3A3530),
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

  /// 朱砂点缀色：用于印章式标签、计数、错误态微调。
  /// 浅色用朱砂本相，深色提亮一档保证可读。
  Color get seal => this == AppColors.light
      ? const Color(0xFFB5482E)
      : const Color(0xFFD4674E);

  /// 暖纸印章底（朱砂极淡），用于印章式标签背景。
  Color get sealMuted => this == AppColors.light
      ? const Color(0xFFF6E7E1)
      : const Color(0xFF3A2520);

  /// 半透明工具栏背景（用于毛玻璃材质）。
  Color get materialBar => this == AppColors.light
      ? const Color(0xCCFAF8F3)
      : const Color(0xCC262320);

  /// 工具栏顶部 1px 亮边（模拟光打在暖纸上）。
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
  static BorderRadius pillRadius = BorderRadius.circular(pill);
}

/// 统一间距刻度（基于 4 的倍数，含出版物级宽留白）。
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xlg = 40;
  static const double xxl = 56;
}

/// 响应式布局断点。
class AppBreakpoints {
  AppBreakpoints._();

  /// 手机与窄窗口使用单栏、全屏设置等紧凑布局。
  static const double compact = 600;
}

/// 可交互控件的最小触控尺寸。
class AppTouchTargets {
  AppTouchTargets._();

  /// 同时满足 iOS 44pt 与 Android 48dp 建议的统一移动端基线。
  static const double mobile = 48;
}

extension AppTargetPlatform on TargetPlatform {
  /// iOS 与 Android 共用移动端信息架构和触控基线。
  bool get isMobile =>
      this == TargetPlatform.iOS || this == TargetPlatform.android;
}

/// 尺寸相关的排版样式。
///
/// 大字给负字距、紧行高；小字给正字距。绝不全局统一 letter-spacing。
/// 展示位用衬线族（含回退），界面 chrome 用无衬线。
class AppTypography {
  AppTypography._();

  /// 英雄译文：衬线大字、负字距、紧行高。精装书内页感。
  static TextStyle editorial(TextStyle base) => base.copyWith(
    fontFamily: AppFonts.serif,
    fontFamilyFallback: AppFonts.serifFallback,
    fontSize: 34,
    fontWeight: FontWeight.w600,
    height: 1.18,
    letterSpacing: -0.015,
  );

  /// 衬线正文：例句原文、电影台词等读物内容。
  static TextStyle serifBody(TextStyle base) => base.copyWith(
    fontFamily: AppFonts.serif,
    fontFamilyFallback: AppFonts.serifFallback,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: -0.005,
  );

  /// 衬线斜体引文：电影台词专用，带书卷气。
  static TextStyle serifQuote(TextStyle base) => base.copyWith(
    fontFamily: AppFonts.serif,
    fontFamilyFallback: AppFonts.serifFallback,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    height: 1.5,
    letterSpacing: -0.005,
  );

  /// 衬线副标题：英文原文置于译文上方时的灰墨小字。
  static TextStyle serifSubtitle(TextStyle base) => base.copyWith(
    fontFamily: AppFonts.serif,
    fontFamilyFallback: AppFonts.serifFallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.01,
  );

  /// 兼容旧引用：英雄区，现等同 editorial。
  static TextStyle hero(TextStyle base) => editorial(base);

  /// 英雄区输入文字（保留可读字号，便于编辑）。用无衬线，编辑更清晰。
  static TextStyle input(TextStyle base) =>
      base.copyWith(fontSize: 17, fontWeight: FontWeight.w400, height: 1.45);

  /// 分节标题：衬线小字、正字距、稍紧。
  static TextStyle sectionHeader(TextStyle base) => base.copyWith(
    fontFamily: AppFonts.serif,
    fontFamilyFallback: AppFonts.serifFallback,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.06,
  );

  /// 正文（释义、答案）。用无衬线，与衬线原文形成层级。
  static TextStyle body(TextStyle base) =>
      base.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5);

  /// 译文辅助行（中文释义、卡片翻译）。
  static TextStyle bodyMuted(TextStyle base) =>
      base.copyWith(fontSize: 15, fontWeight: FontWeight.w400, height: 1.5);

  /// 微标签（胶囊、计数、cached）。无衬线、正字距。
  static TextStyle caption(TextStyle base) => base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.04,
  );

  /// 系统字体常量，供主题使用。
  static String get family => AppFonts.sans;
}
