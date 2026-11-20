import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Brand colours that read the same in light and dark themes.
///
/// Neutral surfaces and text (background, cards, borders, body copy) move with
/// the theme instead — read those from `context.appColors` so a widget rebuilds
/// when the learner flips the switch in Settings.
class SkillBridgeColors {
  // Brand.
  static const primary = Color(0xFF4AA3FF);
  static const primaryDeep = Color(0xFF176DD4);
  static const onPrimary = Color(0xFF03172E);
  static const accent = Color(0xFFFFC857); // gold: XP, SkillCoins, rewards

  // Status.
  static const error = Color(0xFFFF6B6B);
  static const success = Color(0xFF4ADE80);

  /// Code cards stay dark ink in both themes: the Python syntax tokens below
  /// are tuned for a dark card, so the card keeps a dark surface everywhere and
  /// code text stays light. `codeSurfaceLight` is the rare light-context variant.
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
}

/// The neutral colour tokens that differ between light and dark.
///
/// Brand colours live on [SkillBridgeColors] because they never change; these
/// are the ones a theme switch has to move. Installed on [ThemeData] as an
/// extension and read through `context.appColors`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.outline,
    required this.textPrimary,
    required this.textMuted,
    required this.divider,
    required this.cardShadow,
  });

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color outline;
  final Color textPrimary;
  final Color textMuted;
  final Color divider;
  final List<BoxShadow> cardShadow;

  /// Deep ink base with gently stepped elevations.
  static const AppPalette dark = AppPalette(
    background: Color(0xFF080D15),
    surface: Color(0xFF101825),
    surfaceHigh: Color(0xFF182335),
    outline: Color(0xFF29384D),
    textPrimary: Color(0xFFF3F6FB),
    textMuted: Color(0xFF93A1B6),
    divider: Color(0xFF29384D),
    cardShadow: [
      BoxShadow(color: Color(0x52000000), blurRadius: 22, offset: Offset(0, 10)),
    ],
  );

  /// Soft, airy light theme — off-white rather than pure white so cards lift.
  static const AppPalette light = AppPalette(
    background: Color(0xFFF4F7FC),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEDF1F8),
    outline: Color(0xFFDCE3EE),
    textPrimary: Color(0xFF0F1723),
    textMuted: Color(0xFF5B6779),
    divider: Color(0xFFE6EBF3),
    cardShadow: [
      BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 8)),
    ],
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? outline,
    Color? textPrimary,
    Color? textMuted,
    Color? divider,
    List<BoxShadow>? cardShadow,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      outline: outline ?? this.outline,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      divider: divider ?? this.divider,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t) ??
          cardShadow,
    );
  }
}

/// `context.appColors.surface` — the theme-aware neutral tokens.
///
/// Falls back to the dark palette if the extension is missing (e.g. a widget
/// pumped without the app theme in a test).
extension AppColorsX on BuildContext {
  AppPalette get appColors =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
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

ThemeData buildDarkTheme() => _buildTheme(AppPalette.dark, Brightness.dark);

ThemeData buildLightTheme() => _buildTheme(AppPalette.light, Brightness.light);

ThemeData _buildTheme(AppPalette p, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final text = p.textPrimary;
  final muted = p.textMuted;

  final scheme =
      ColorScheme.fromSeed(
        seedColor: SkillBridgeColors.primary,
        brightness: brightness,
      ).copyWith(
        primary: isDark ? SkillBridgeColors.primary : SkillBridgeColors.primaryDeep,
        onPrimary: Colors.white,
        secondary: SkillBridgeColors.accent,
        onSecondary: const Color(0xFF2A1D00),
        tertiary: SkillBridgeColors.success,
        surface: p.surface,
        onSurface: text,
        onSurfaceVariant: muted,
        // The brand red is tuned for a dark card; on a light surface it is too
        // pale for AA text, so light mode uses a deeper red.
        error: isDark ? SkillBridgeColors.error : const Color(0xFFB3261E),
        outline: isDark ? const Color(0xFF34435C) : const Color(0xFFC6D0E0),
        outlineVariant: p.outline,
        surfaceContainerLowest: isDark
            ? const Color(0xFF060A12)
            : const Color(0xFFFFFFFF),
        surfaceContainerLow: isDark
            ? const Color(0xFF0D141F)
            : const Color(0xFFF0F3F9),
        surfaceContainer: p.surface,
        surfaceContainerHigh: p.surfaceHigh,
        surfaceContainerHighest: isDark
            ? const Color(0xFF223047)
            : const Color(0xFFE3E9F3),
        primaryContainer: SkillBridgeColors.primary.withValues(
          alpha: isDark ? 0.16 : 0.14,
        ),
        onPrimaryContainer: isDark
            ? const Color(0xFFC9E5FF)
            : const Color(0xFF06335F),
      );

  final radius24 = BorderRadius.circular(20);
  final radius18 = BorderRadius.circular(18);
  final dragHandle = isDark ? const Color(0xFF3A4A62) : const Color(0xFFC6D0E0);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    extensions: [p],
    scaffoldBackgroundColor: p.background,
    splashColor: SkillBridgeColors.primary.withValues(alpha: 0.10),
    highlightColor: Colors.transparent,
    dividerColor: p.divider,
    canvasColor: p.background,

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
        side: WidgetStatePropertyAll(BorderSide(color: p.outline)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? SkillBridgeColors.primary.withValues(alpha: isDark ? 0.20 : 0.16)
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? (isDark ? SkillBridgeColors.primary : SkillBridgeColors.primaryDeep)
              : muted,
        ),
      ),
    ),

    // ---- Typography: confident headings, calm readable body. ----
    textTheme: TextTheme(
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
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      backgroundColor: p.background,
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
        disabledBackgroundColor: p.surfaceHigh,
        disabledForegroundColor: muted,
        elevation: 0,
        shadowColor: SkillBridgeColors.primary,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: radius18),
        side: BorderSide(color: p.outline, width: 1.4),
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
        foregroundColor: isDark
            ? SkillBridgeColors.primary
            : SkillBridgeColors.primaryDeep,
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
      color: p.surface,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius24,
        side: BorderSide(color: p.outline, width: 1),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        color: text,
      ),
      contentTextStyle: TextStyle(fontSize: 16, height: 1.5, color: muted),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: dragHandle,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
    ),
    // Snack bars keep a dark card in both themes: high contrast against either
    // background, standard on Android and iOS.
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1C2739),
      contentTextStyle: const TextStyle(
        fontSize: 15,
        color: Color(0xFFF3F6FB),
        height: 1.35,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? const Color(0xFF0C1420) : p.surface,
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
              ? (isDark
                    ? SkillBridgeColors.primary
                    : SkillBridgeColors.primaryDeep)
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
      textStyle: const TextStyle(color: Color(0xFFF3F6FB), fontSize: 13),
    ),

    // ---- Inputs and controls. ----
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: TextStyle(color: muted),
      labelStyle: TextStyle(color: muted),
      floatingLabelStyle: TextStyle(
        color: isDark
            ? SkillBridgeColors.primary
            : SkillBridgeColors.primaryDeep,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: p.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: p.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark
              ? SkillBridgeColors.primary
              : SkillBridgeColors.primaryDeep,
          width: 1.8,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.error, width: 1.8),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: SkillBridgeColors.primary,
      selectionColor: SkillBridgeColors.primary.withValues(alpha: 0.30),
      selectionHandleColor: SkillBridgeColors.primary,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: SkillBridgeColors.primary,
      linearTrackColor: p.surfaceHigh,
      circularTrackColor: p.surfaceHigh,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? SkillBridgeColors.primary
            : p.surfaceHigh,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: SkillBridgeColors.primary,
      inactiveTrackColor: p.surfaceHigh,
      thumbColor: isDark ? Colors.white : SkillBridgeColors.primaryDeep,
      overlayColor: SkillBridgeColors.primary.withValues(alpha: 0.16),
      trackHeight: 6,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surfaceHigh,
      disabledColor: p.textMuted,
      side: BorderSide(color: p.outline),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      labelStyle: TextStyle(
        color: p.textPrimary,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
