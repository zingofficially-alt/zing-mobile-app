import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoPageTransitionsBuilder, CupertinoTextThemeData, CupertinoThemeData;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized design tokens — change once, apply everywhere.
///
/// The palette follows the iOS system colours: an indigo tint, pink accent,
/// and the grouped grey / white surface pair that iOS uses for its own apps.
class ZingColors {
  // Tint — iOS system indigo
  static const Color primary = Color(0xFF5856D6);
  static const Color primaryLight = Color(0xFF7D7AFF);
  static const Color primaryDark = Color(0xFF3634A3);

  // Accent — iOS system pink
  static const Color secondary = Color(0xFFFF2D55);
  static const Color secondaryLight = Color(0xFFFF6482);

  // Tertiary — iOS system cyan
  static const Color accent = Color(0xFF32ADE6);

  // Status — iOS system green / orange / red
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color error = Color(0xFFFF3B30);

  // Light: grouped background with white cards
  static const Color background = Color(0xFFF2F2F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE5E5EA);
  static const Color textDark = Color(0xFF1C1C1E);
  static const Color textMedium = Color(0xFF636366);
  static const Color textLight = Color(0xFF8E8E93);
  static const Color divider = Color(0xFFD1D1D6);

  // Dark: true black with elevated greys
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkSurfaceVariant = Color(0xFF2C2C2E);
  static const Color darkTextDark = Color(0xFFFFFFFF);
  static const Color darkTextMedium = Color(0xFFAEAEB2);
  static const Color darkTextLight = Color(0xFF8E8E93);
  static const Color darkDivider = Color(0xFF38383A);
}

/// Spacing constants for consistent layout
class ZingSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 32;
}

/// Corner radii. iOS uses large continuous corners on cards and sheets.
class ZingRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
}

/// Shadow presets. iOS relies on surface contrast more than elevation, so
/// these are deliberately faint.
class ZingShadows {
  static List<BoxShadow> get soft => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get medium => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.07),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];
}

/// iOS type scale. Apple devices use the system font (SF Pro); everywhere
/// else falls back to Inter, which has near-identical metrics.
class ZingType {
  static bool get _apple =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static double _tracking(double size) {
    if (_apple) {
      if (size >= 20) return 0.36;
      if (size >= 16) return -0.41;
      if (size >= 14) return -0.24;
      if (size >= 13) return -0.08;
      return 0;
    }
    if (size >= 20) return -0.022 * size;
    if (size >= 14) return -0.011 * size;
    return 0;
  }

  static TextStyle style(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing ?? _tracking(size),
    );
    return _apple ? base : GoogleFonts.inter(textStyle: base);
  }

  static TextStyle largeTitle(Color c) => style(34, weight: FontWeight.w700, color: c, height: 1.2);
  static TextStyle title1(Color c) => style(28, weight: FontWeight.w700, color: c, height: 1.2);
  static TextStyle title2(Color c) => style(22, weight: FontWeight.w700, color: c, height: 1.25);
  static TextStyle title3(Color c) => style(20, weight: FontWeight.w600, color: c, height: 1.25);
  static TextStyle headline(Color c) => style(17, weight: FontWeight.w600, color: c, height: 1.3);
  static TextStyle body(Color c) => style(17, color: c, height: 1.3);
  static TextStyle callout(Color c) => style(16, color: c, height: 1.3);
  static TextStyle subhead(Color c) => style(15, color: c, height: 1.35);
  static TextStyle footnote(Color c) => style(13, color: c, height: 1.35);
  static TextStyle caption(Color c) => style(12, color: c, height: 1.3);
}

class ThemeProvider with ChangeNotifier {
  static const _darkKey = 'dark_mode';

  ThemeProvider() {
    _load();
  }

  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_darkKey);
      if (saved != null && saved != _isDarkMode) {
        _isDarkMode = saved;
        notifyListeners();
      }
    } catch (_) {}
  }

  void toggleTheme(bool isDark) {
    _isDarkMode = isDark;
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.setBool(_darkKey, isDark)).catchError((_) => false);
  }

  ThemeData get lightTheme => _build(Brightness.light);

  ThemeData get darkTheme => _build(Brightness.dark);

  ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;

    final tint = dark ? ZingColors.primaryLight : ZingColors.primary;
    final background = dark ? ZingColors.darkBackground : ZingColors.background;
    final surface = dark ? ZingColors.darkSurface : ZingColors.surface;
    final fill = dark ? ZingColors.darkSurfaceVariant : ZingColors.surfaceVariant;
    final label = dark ? ZingColors.darkTextDark : ZingColors.textDark;
    final label2 = dark ? ZingColors.darkTextMedium : ZingColors.textMedium;
    final label3 = dark ? ZingColors.darkTextLight : ZingColors.textLight;
    final separator = dark ? ZingColors.darkDivider : ZingColors.divider;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: tint,
      onPrimary: Colors.white,
      primaryContainer: tint.withValues(alpha: dark ? 0.24 : 0.12),
      onPrimaryContainer: dark ? ZingColors.primaryLight : ZingColors.primaryDark,
      secondary: ZingColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: dark ? const Color(0xFF4A0A1A) : const Color(0xFFFFE5EA),
      onSecondaryContainer: dark ? const Color(0xFFFFD6DE) : const Color(0xFF8A0F2A),
      tertiary: ZingColors.accent,
      onTertiary: Colors.white,
      error: ZingColors.error,
      onError: Colors.white,
      surface: surface,
      onSurface: label,
      surfaceContainerLowest: surface,
      surfaceContainerLow: surface,
      surfaceContainer: dark ? ZingColors.darkSurfaceVariant : ZingColors.background,
      surfaceContainerHigh: fill,
      surfaceContainerHighest: fill,
      onSurfaceVariant: label2,
      outline: separator,
      outlineVariant: separator.withValues(alpha: 0.6),
      shadow: Colors.black.withValues(alpha: dark ? 0.5 : 0.12),
      surfaceTint: Colors.transparent,
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      primaryColor: tint,
      scaffoldBackgroundColor: background,
      canvasColor: surface,

      // iOS has no ink ripple: taps dim the control instead.
      splashFactory: NoSplash.splashFactory,
      highlightColor: label.withValues(alpha: 0.06),
      splashColor: Colors.transparent,
      hoverColor: label.withValues(alpha: 0.04),

      // Push/pop with the iOS slide and edge swipe-back on every platform.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),

      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: tint,
        scaffoldBackgroundColor: background,
        barBackgroundColor: surface.withValues(alpha: 0.8),
        textTheme: CupertinoTextThemeData(
          primaryColor: tint,
          textStyle: ZingType.body(label),
          actionTextStyle: ZingType.body(tint),
          navTitleTextStyle: ZingType.headline(label),
          navLargeTitleTextStyle: ZingType.largeTitle(label),
          navActionTextStyle: ZingType.body(tint),
          tabLabelTextStyle: ZingType.style(10, weight: FontWeight.w500, color: label3),
        ),
      ),

      // Inline navigation bar: 44pt, centred 17pt semibold title, tinted actions.
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: label,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: ZingType.headline(label),
        iconTheme: IconThemeData(color: tint, size: 24),
        actionsIconTheme: IconThemeData(color: tint, size: 24),
        toolbarHeight: 48,
      ),

      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const Icon(CupertinoIcons.chevron_back, size: 26),
        closeButtonIconBuilder: (_) => const Icon(CupertinoIcons.xmark, size: 22),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 56,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return ZingType.style(10, weight: FontWeight.w500, color: selected ? tint : label3);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? tint : label3, size: 26);
        }),
      ),

      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStateProperty.all(fill),
        elevation: WidgetStateProperty.all(0),
        hintStyle: WidgetStateProperty.all(ZingType.body(label3)),
        textStyle: WidgetStateProperty.all(ZingType.body(label)),
        constraints: const BoxConstraints(minHeight: 40),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 12)),
      ),

      textTheme: TextTheme(
        displayLarge: ZingType.largeTitle(label),
        displayMedium: ZingType.title1(label),
        displaySmall: ZingType.title2(label),
        headlineLarge: ZingType.title1(label),
        headlineMedium: ZingType.title2(label),
        headlineSmall: ZingType.title3(label),
        titleLarge: ZingType.headline(label),
        titleMedium: ZingType.style(15, weight: FontWeight.w600, color: label, height: 1.3),
        titleSmall: ZingType.style(13, weight: FontWeight.w500, color: label2, height: 1.3),
        bodyLarge: ZingType.body(label),
        bodyMedium: ZingType.subhead(label2),
        bodySmall: ZingType.footnote(label3),
        labelLarge: ZingType.style(16, weight: FontWeight.w600, color: label),
        labelMedium: ZingType.style(12, weight: FontWeight.w500, color: label2),
        labelSmall: ZingType.style(11, weight: FontWeight.w500, color: label3),
      ),

      // Filled button — the iOS prominent style.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: tint,
          disabledBackgroundColor: fill,
          disabledForegroundColor: label3,
          shadowColor: Colors.transparent,
          elevation: 0,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZingRadius.md)),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 22),
          textStyle: ZingType.style(16, weight: FontWeight.w600),
        ).copyWith(
          elevation: WidgetStateProperty.all(0),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return Colors.white.withValues(alpha: 0.22);
            return Colors.transparent;
          }),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tint,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZingRadius.md)),
          textStyle: ZingType.style(16, weight: FontWeight.w600),
        ),
      ),

      // Tinted button — the iOS secondary style (soft fill, no outline).
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tint,
          backgroundColor: tint.withValues(alpha: dark ? 0.22 : 0.12),
          side: BorderSide.none,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZingRadius.md)),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 22),
          textStyle: ZingType.style(16, weight: FontWeight.w600),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return tint.withValues(alpha: 0.12);
            return Colors.transparent;
          }),
        ),
      ),

      // Plain button — tinted text only.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tint,
          textStyle: ZingType.style(16, weight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZingRadius.sm)),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return tint.withValues(alpha: 0.1);
            return Colors.transparent;
          }),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return label.withValues(alpha: 0.08);
            return Colors.transparent;
          }),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? ZingColors.darkSurfaceVariant : ZingColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: inputBorder(separator.withValues(alpha: 0.7)),
        enabledBorder: inputBorder(separator.withValues(alpha: 0.7)),
        focusedBorder: inputBorder(tint, 1.5),
        errorBorder: inputBorder(ZingColors.error),
        focusedErrorBorder: inputBorder(ZingColors.error, 1.5),
        hintStyle: ZingType.callout(label3),
        labelStyle: ZingType.callout(label2),
        floatingLabelStyle: ZingType.callout(tint),
        prefixIconColor: label3,
        suffixIconColor: label3,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: tint,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 2,
        shape: const StadiumBorder(),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: fill,
        selectedColor: tint,
        labelStyle: ZingType.style(14, weight: FontWeight.w500, color: label),
        secondaryLabelStyle: ZingType.style(14, weight: FontWeight.w600, color: Colors.white),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        elevation: 0,
        pressElevation: 0,
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),

      cardTheme: CardThemeData(
        color: surface,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZingRadius.lg)),
      ),

      dividerTheme: DividerThemeData(color: separator, thickness: 0.5, space: 0.5),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZingRadius.lg)),
        titleTextStyle: ZingType.headline(label),
        contentTextStyle: ZingType.subhead(label2),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        modalBarrierColor: Colors.black.withValues(alpha: 0.35),
        dragHandleColor: separator,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(ZingRadius.xl)),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZingRadius.md)),
        textStyle: ZingType.body(label),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: tint,
        unselectedItemColor: label3,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: tint,
        unselectedLabelColor: label3,
        indicatorColor: tint,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: separator.withValues(alpha: 0.6),
        dividerHeight: 0.5,
        labelStyle: ZingType.style(15, weight: FontWeight.w600),
        unselectedLabelStyle: ZingType.style(15, weight: FontWeight.w500),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? ZingColors.darkSurfaceVariant : const Color(0xFF2C2C2E),
        contentTextStyle: ZingType.subhead(Colors.white),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZingRadius.md)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        iconColor: tint,
        titleTextStyle: ZingType.body(label),
        subtitleTextStyle: ZingType.footnote(label3),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tint,
        linearTrackColor: fill,
        circularTrackColor: Colors.transparent,
      ),

      // iOS switch: green track, white thumb, no outline.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? ZingColors.success : fill,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? tint : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: label3, width: 1.5),
        shape: const CircleBorder(),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? tint : label3,
        ),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: tint,
        inactiveTrackColor: fill,
        thumbColor: Colors.white,
        overlayColor: Colors.transparent,
        trackHeight: 4,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: ZingType.footnote(Colors.white),
      ),
    );
  }
}
