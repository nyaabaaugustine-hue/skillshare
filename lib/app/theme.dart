import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// SkillBridge brand colours. Names are stable: other files reference them.
class SkillBridgeColors {
  // Surfaces: a deep ink base with gently stepped elevations.
  static const background = Color(0xFF080D15);
  static const surface = Color(0xFF101825);
  static const surfaceHigh = Color(0xFF182335);
  static const outline = Color(0xFF29384D);

  // Brand.
  static const primary = Color(0xFF4AA3FF);
  static const primaryDeep = Color(0xFF176DD4);
  static const onPrimary = Color(0xFF03172E);
  static const accent = Color(0xFFFFC857); // gold: XP, SkillCoins, rewards

  // Text and status.
  static const textPrimary = Color(0xFFF3F6FB);
  static const textMuted = Color(0xFF93A1B6);
  static const error = Color(0xFFFF6B6B);
  static const success = Color(0xFF4ADE80);

  // Code surfaces.
  static const codeSurface = Color(0xFF0D1624);
  static const codeSurfaceLight = Color(0xFFF4F6F8);

  /// Premium brand gradient for hero buttons and banners.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF45B4FF), Color(0xFF0B67E0)],
  );

  /// Deeper brand wash used behind hero cards so text stays readable.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0E2C57), Color(0xFF0A1A31), Color(0xFF0B2B4F)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Gold gradient for rewards.
  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFE08A), Color(0xFFFFB020)],
  );

  /// Soft lift used on floating cards instead of a hard border.
  static const cardShadow = [
    BoxShadow(color: Color(0x52000000), blurRadius: 22, offset: Offset(0, 10)),
  ];
}

class AppTheme {
  /// Token colors for Python syntax highlighting
  static const Color tokenKeyword = Color(0xFFFFB020);
  static const Color tokenBuiltin = Color(0xFFFFB020);
  static const Color tokenString = Color(0xFFC3E88D);
  static const Color tokenNumber = Color(0xFFFDD079);
  static const Color tokenComment = Color(0xFF5A6472);
  static const Color tokenOperator = Color(0xFFFFB020);
  static const Color tokenVariable = Color(0xFFF2F5F9);
  static const Color codeSurface = Color(0xFF0D1624);
  static const brandAmber = Color(0xFFFFC857);
  static const brandBlueDark = Color(0xFF125EAA);
}

ThemeData buildDarkTheme() {
  const text = SkillBridgeColors.textPrimary;
  const muted = SkillBridgeColors.textMuted;

  final scheme =
      ColorScheme.fromSeed(
        seedColor: SkillBridgeColors.primary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: SkillBridgeColors.primary,
        onPrimary: Colors.white,
        secondary: SkillBridgeColors.accent,
        onSecondary: const Color(0xFF2A1D00),
        tertiary: SkillBridgeColors.success,
        surface: SkillBridgeColors.surface,
        onSurface: text,
        onSurfaceVariant: muted,
        error: SkillBridgeColors.error,
        outline: const Color(0xFF34435C),
        outlineVariant: SkillBridgeColors.outline,
        surfaceContainerLowest: Color(0xFF060A12),
        surfaceContainerLow: Color(0xFF0D141F),
        surfaceContainer: SkillBridgeColors.surface,
        surfaceContainerHigh: SkillBridgeColors.surfaceHigh,
        surfaceContainerHighest: Color(0xFF223047),
        primaryContainer: SkillBridgeColors.primary.withValues(alpha: 0.16),
        onPrimaryContainer: const Color(0xFFC9E5FF),
      );

    final radius24 = BorderRadius.circular(20);
  final radius18 = BorderRadius.circular(18);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: SkillBridgeColors.background,
    splashColor: SkillBridgeColors.primary.withValues(alpha: 0.10),
    highlightColor: Colors.transparent,
    dividerColor: SkillBridgeColors.outline,

    // ---- Motion: every pushed screen eases in instead of snapping. ----
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),

    // ---- Segmented selectors (e.g. the theme picker in Settings). ----
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        animationDuration: const Duration(milliseconds: 220),
        visualDensity: VisualDensity.standard,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        side: const WidgetStatePropertyAll(
          BorderSide(color: SkillBridgeColors.outline),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? SkillBridgeColors.primary.withValues(alpha: 0.20)
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? SkillBridgeColors.primary
              : muted,
        ),
      ),
    ),

    // ---- Typography: confident headings, calm readable body. ----
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 56,
        fontWeight: FontWeight.w800,
        color: text,
        letterSpacing: -1.2,
        height: 1.05,
      ),
      displayMedium: TextStyle(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        color: text,
        letterSpacing: -1.0,
        height: 1.1,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: text,
        letterSpacing: -0.6,
        height: 1.15,
      ),
      headlineMedium: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: text,
        letterSpacing: -0.6,
        height: 1.15,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: text,
        letterSpacing: -0.3,
        height: 1.2,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: text,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: text,
        letterSpacing: 0,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: text,
        letterSpacing: 0.1,
      ),
      bodyLarge: TextStyle(
        fontSize: 17,
        height: 1.55,
        color: text,
        letterSpacing: 0.1,
      ),
      bodyMedium: TextStyle(
        fontSize: 15.5,
        height: 1.5,
        color: muted,
        letterSpacing: 0.1,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        height: 1.45,
        color: muted,
        letterSpacing: 0.2,
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: text,
        letterSpacing: 0.7,
      ),
      labelMedium: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: muted,
        letterSpacing: 0.6,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: muted,
        letterSpacing: 0.7,
      ),
    ),

    // ---- App bar: flat, quiet, no tint when scrolling. ----
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      backgroundColor: SkillBridgeColors.background,
      foregroundColor: text,
      toolbarTextStyle: TextStyle(color: text, fontWeight: FontWeight.w700),
      titleTextStyle: TextStyle(
        color: text,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.1,
      ),
    ),

    // ---- Buttons: large, rounded, tactile. ----
    // minimumSize keeps full width where a parent gives bounded width. Place a
    // button in a Row/dialog only with Expanded or its own minimumSize.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: radius18),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
        // White on #2B95FF measures 3.1:1 — below AA for 16px bold button text.
        // The deeper brand blue clears it at 5.2:1 and keeps the brand reading.
        backgroundColor: SkillBridgeColors.primaryDeep,
        foregroundColor: Colors.white,
        disabledBackgroundColor: SkillBridgeColors.surfaceHigh,
        disabledForegroundColor: muted,
        elevation: 0,
        shadowColor: SkillBridgeColors.primary,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: radius18),
        side: const BorderSide(color: SkillBridgeColors.outline, width: 1.4),
        foregroundColor: text,
        disabledForegroundColor: muted,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: SkillBridgeColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: text),
    ),

    // ---- Surfaces. ----
    cardTheme: CardThemeData(
      color: SkillBridgeColors.surface,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius24,
        side: const BorderSide(color: SkillBridgeColors.outline, width: 1),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: SkillBridgeColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        color: text,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 16,
        height: 1.5,
        color: muted,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: SkillBridgeColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Color(0xFF3A4A62),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1C2739),
      contentTextStyle: const TextStyle(
        fontSize: 15,
        color: text,
        height: 1.35,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    dividerTheme: const DividerThemeData(
      color: SkillBridgeColors.outline,
      thickness: 1,
      space: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0C1420),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      indicatorColor: SkillBridgeColors.primary.withValues(alpha: 0.18),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11.5,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          color: s.contains(WidgetState.selected) ? text : muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 24,
          color: s.contains(WidgetState.selected)
              ? SkillBridgeColors.primary
              : muted,
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: muted,
      textColor: text,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xFF223047),
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: const TextStyle(color: text, fontSize: 13),
    ),

    // ---- Inputs and controls. ----
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SkillBridgeColors.surfaceHigh.withValues(alpha: 0.65),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: const TextStyle(color: muted),
      labelStyle: const TextStyle(color: SkillBridgeColors.textMuted),
      floatingLabelStyle: const TextStyle(color: SkillBridgeColors.primary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: SkillBridgeColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: SkillBridgeColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: SkillBridgeColors.primary,
          width: 1.8,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: SkillBridgeColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: SkillBridgeColors.error,
          width: 1.8,
        ),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: SkillBridgeColors.primary,
      selectionColor: SkillBridgeColors.primary.withValues(alpha: 0.30),
      selectionHandleColor: SkillBridgeColors.primary,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: SkillBridgeColors.primary,
      linearTrackColor: SkillBridgeColors.surfaceHigh,
      circularTrackColor: SkillBridgeColors.surfaceHigh,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? SkillBridgeColors.primary
            : SkillBridgeColors.surfaceHigh,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: SkillBridgeColors.primary,
      inactiveTrackColor: SkillBridgeColors.surfaceHigh,
      thumbColor: Colors.white,
      overlayColor: SkillBridgeColors.primary.withValues(alpha: 0.16),
      trackHeight: 6,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: SkillBridgeColors.surfaceHigh.withValues(alpha: 0.7),
      disabledColor: SkillBridgeColors.textMuted,
      side: const BorderSide(color: SkillBridgeColors.outline),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      labelStyle: const TextStyle(
        color: SkillBridgeColors.textPrimary,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
