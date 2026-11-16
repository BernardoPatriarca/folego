// Tema escuro do Fôlego: painel esportivo, verde-limão sobre grafite.

import 'package:material_ui/material_ui.dart';

abstract final class FolegoColors {
  static const background = Color(0xFF12161C);
  static const surface = Color(0xFF1D242E);
  static const surfaceHigh = Color(0xFF2A333F);
  static const border = Color(0xFF323C49);
  static const text = Color(0xFFF3F1EA);
  static const textSecondary = Color(0xFFA9B3BF);
  static const lime = Color(0xFFC6F432);

  /// Texto sobre o limão é sempre escuro.
  static const onLime = Color(0xFF12161C);

  /// Alerta "ousado": sempre acompanhado de texto ou ícone.
  static const bold = Color(0xFFFF8A3D);
  static const error = Color(0xFFFF6B6B);
}

const headingFont = 'Oswald';
const bodyFont = 'Rubik';
const tabular = [FontFeature.tabularFigures()];

/// Estilo para números grandes (Oswald, algarismos tabulares).
TextStyle numberStyle(double size,
        {Color color = FolegoColors.text, FontWeight weight = FontWeight.w600}) =>
    TextStyle(
      fontFamily: headingFont,
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFeatures: tabular,
      height: 1.1,
    );

ThemeData buildTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: FolegoColors.lime,
    onPrimary: FolegoColors.onLime,
    secondary: FolegoColors.lime,
    onSecondary: FolegoColors.onLime,
    tertiary: FolegoColors.bold,
    onTertiary: FolegoColors.onLime,
    error: FolegoColors.error,
    onError: FolegoColors.onLime,
    surface: FolegoColors.background,
    onSurface: FolegoColors.text,
    onSurfaceVariant: FolegoColors.textSecondary,
    surfaceContainerLowest: FolegoColors.background,
    surfaceContainerLow: FolegoColors.surface,
    surfaceContainer: FolegoColors.surface,
    surfaceContainerHigh: FolegoColors.surfaceHigh,
    surfaceContainerHighest: FolegoColors.surfaceHigh,
    outline: FolegoColors.border,
    outlineVariant: FolegoColors.border,
    primaryContainer: FolegoColors.surfaceHigh,
    onPrimaryContainer: FolegoColors.lime,
    secondaryContainer: FolegoColors.lime,
    onSecondaryContainer: FolegoColors.onLime,
    inverseSurface: FolegoColors.text,
    onInverseSurface: FolegoColors.background,
  );

  TextStyle h(double size, [FontWeight w = FontWeight.w600]) => TextStyle(
      fontFamily: headingFont,
      fontSize: size,
      fontWeight: w,
      color: FolegoColors.text,
      letterSpacing: 0.4,
      fontFeatures: tabular);
  TextStyle b(double size,
          [FontWeight w = FontWeight.w400, Color c = FolegoColors.text]) =>
      TextStyle(fontFamily: bodyFont, fontSize: size, fontWeight: w, color: c);

  final textTheme = TextTheme(
    displayLarge: h(56),
    displayMedium: h(44),
    displaySmall: h(36),
    headlineLarge: h(32),
    headlineMedium: h(28),
    headlineSmall: h(24),
    titleLarge: h(22, FontWeight.w500),
    titleMedium: b(16, FontWeight.w500),
    titleSmall: b(14, FontWeight.w500),
    bodyLarge: b(16),
    bodyMedium: b(14),
    bodySmall: b(12, FontWeight.w400, FolegoColors.textSecondary),
    labelLarge: b(14, FontWeight.w600),
    labelMedium: b(12, FontWeight.w500),
    labelSmall: b(11, FontWeight.w500, FolegoColors.textSecondary),
  );

  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: FolegoColors.background,
    fontFamily: bodyFont,
    textTheme: textTheme,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: FolegoColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: FolegoColors.text,
      centerTitle: false,
      titleTextStyle: h(22, FontWeight.w500),
    ),
    cardTheme: CardThemeData(
      color: FolegoColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: FolegoColors.border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: FolegoColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: FolegoColors.lime,
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? FolegoColors.onLime
              : FolegoColors.textSecondary)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => b(
          12,
          FontWeight.w500,
          s.contains(WidgetState.selected)
              ? FolegoColors.text
              : FolegoColors.textSecondary)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FolegoColors.lime,
        foregroundColor: FolegoColors.onLime,
        disabledBackgroundColor: FolegoColors.surfaceHigh,
        minimumSize: const Size(48, 52),
        shape: shape,
        textStyle: b(16, FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: FolegoColors.text,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: FolegoColors.border),
        shape: shape,
        textStyle: b(14, FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: FolegoColors.lime,
        minimumSize: const Size(48, 48),
        textStyle: b(14, FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: FolegoColors.surface,
      selectedColor: FolegoColors.lime,
      disabledColor: FolegoColors.surface,
      labelStyle: b(14, FontWeight.w500),
      secondaryLabelStyle: b(14, FontWeight.w600, FolegoColors.onLime),
      checkmarkColor: FolegoColors.onLime,
      side: const BorderSide(color: FolegoColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: FolegoColors.surface,
      labelStyle: b(14, FontWeight.w400, FolegoColors.textSecondary),
      hintStyle: b(14, FontWeight.w400, FolegoColors.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: FolegoColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: FolegoColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: FolegoColors.lime, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: FolegoColors.error),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: FolegoColors.surfaceHigh,
      contentTextStyle: b(14),
      actionTextColor: FolegoColors.lime,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: FolegoColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: h(22, FontWeight.w500),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: FolegoColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dividerTheme: const DividerThemeData(color: FolegoColors.border, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: FolegoColors.textSecondary,
      titleTextStyle: b(16, FontWeight.w500),
      subtitleTextStyle: b(13, FontWeight.w400, FolegoColors.textSecondary),
      minVerticalPadding: 12,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: FolegoColors.lime,
      linearTrackColor: FolegoColors.surfaceHigh,
      circularTrackColor: FolegoColors.surfaceHigh,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? FolegoColors.onLime
              : FolegoColors.textSecondary),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? FolegoColors.lime
              : FolegoColors.surfaceHigh),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: FolegoColors.lime,
        selectedForegroundColor: FolegoColors.onLime,
        foregroundColor: FolegoColors.text,
        side: const BorderSide(color: FolegoColors.border),
        minimumSize: const Size(48, 48),
      ),
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: FolegoColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
