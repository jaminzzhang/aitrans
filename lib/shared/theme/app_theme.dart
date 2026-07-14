import 'package:flutter/material.dart';
import 'app_tokens.dart';

/// 应用主题配置。
///
/// 中性底色 + 系统蓝强调，弃用 Material 紫种子。
/// 去涟漪、无外框输入、轻阴影卡片、极淡分割线，整体追求 Apple 式极简。
class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final palette = AppColors.of(brightness);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: palette.accent,
      onPrimary: Colors.white,
      primaryContainer: palette.accentMuted,
      onPrimaryContainer: palette.inkPrimary,
      secondary: palette.accent,
      onSecondary: Colors.white,
      secondaryContainer: palette.surfaceElevated,
      onSecondaryContainer: palette.inkPrimary,
      error: palette.error,
      onError: Colors.white,
      surface: palette.surface,
      onSurface: palette.inkPrimary,
      surfaceContainerHighest: palette.surfaceElevated,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.bg,
      canvasColor: palette.bg,
      fontFamily: AppTypography.family,
      splashFactory: NoSplash.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, palette),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: palette.inkPrimary,
      ),
      iconTheme: IconThemeData(color: palette.inkSecondary, size: 20),
      inputDecorationTheme: _inputDecoration(palette),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdRadius),
      ),
      dividerTheme: DividerThemeData(
        color: palette.divider,
        thickness: 0.5,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.inkPrimary,
        contentTextStyle: TextStyle(color: palette.bg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdRadius),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.accent,
        selectionColor: palette.accent.withValues(alpha: 0.2),
        selectionHandleColor: palette.accent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: palette.inkPrimary,
          borderRadius: AppRadii.smRadius,
        ),
        textStyle: TextStyle(color: palette.bg, fontSize: 12),
      ),
    );
  }

  /// 排版：以 base 主题为底，覆盖关键角色样式。
  static TextTheme _textTheme(TextTheme base, AppPalette _) => base.copyWith(
    displayMedium: AppTypography.hero(base.displayMedium!),
    titleLarge: AppTypography.hero(base.titleLarge!),
    titleMedium: AppTypography.sectionHeader(base.titleMedium!),
    bodyLarge: AppTypography.body(base.bodyLarge!),
    bodyMedium: AppTypography.bodyMuted(base.bodyMedium!),
    labelSmall: AppTypography.caption(base.labelSmall!),
    labelMedium: AppTypography.caption(base.labelMedium!),
  );

  /// 无外框输入；聚焦时用浅 accent 填充提示，取代描边。
  static InputDecorationTheme _inputDecoration(AppPalette palette) =>
      InputDecorationTheme(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        filled: false,
        isDense: true,
        hintStyle: TextStyle(color: palette.inkTertiary),
      );
}
