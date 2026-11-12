import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized design tokens — change once, apply everywhere.
class ZingColors {
  // Primary brand — vivid indigo
  static const Color primary = Color(0xFF4361EE);
  static const Color primaryLight = Color(0xFF6B84F3);
  static const Color primaryDark = Color(0xFF2E4FD8);

  // Secondary — coral/rose accent
  static const Color secondary = Color(0xFFF72585);
  static const Color secondaryLight = Color(0xFFFF5FA3);

  // Accent / teal
  static const Color accent = Color(0xFF4CC9F0);

  // Success / Warning / Error
  static const Color success = Color(0xFF06D6A0);
  static const Color warning = Color(0xFFFFBE0B);
  static const Color error = Color(0xFFEF476F);

  // Neutral light palette — softer background for clean canvas
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F5F5);
  static const Color textDark = Color(0xFF1A1D2E);
  static const Color textMedium = Color(0xFF5A5D7A);
  static const Color textLight = Color(0xFF9799B3);
  static const Color divider = Color(0xFFE8E8E8);

  // Neutral dark palette
  static const Color darkBackground = Color(0xFF0E0F1A);
  static const Color darkSurface = Color(0xFF1A1D2E);
  static const Color darkSurfaceVariant = Color(0xFF252840);
  static const Color darkTextDark = Color(0xFFF0F2FF);
  static const Color darkTextMedium = Color(0xFFB0B3CC);
  static const Color darkTextLight = Color(0xFF6B6E8A);
  static const Color darkDivider = Color(0xFF2A2D45);
}

/// Spacing constants for consistent layout
class ZingSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Shadow presets for consistent elevation
class ZingShadows {
  static List<BoxShadow> get soft => [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get medium => [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get card => [
        BoxShadow(
          color: ZingColors.primary.withOpacity(0.06),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
}

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme(bool isDark) {
    _isDarkMode = isDark;
    notifyListeners();
  }

  ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: ZingColors.primary,
    scaffoldBackgroundColor: ZingColors.background,

    colorScheme: const ColorScheme.light(
      primary: ZingColors.primary,
      onPrimary: Colors.white,
      primaryContainer: ZingColors.surfaceVariant,
      onPrimaryContainer: ZingColors.primaryDark,
      secondary: ZingColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFFFE4F0),
      onSecondaryContainer: Color(0xFF8B0045),
      tertiary: ZingColors.accent,
      onTertiary: Colors.white,
      error: ZingColors.error,
      onError: Colors.white,
      surface: ZingColors.surface,
      onSurface: ZingColors.textDark,
      surfaceContainerHighest: ZingColors.surfaceVariant,
      onSurfaceVariant: ZingColors.textMedium,
      outline: ZingColors.divider,
      shadow: Color(0x1A4361EE),
    ),

    // Clean white app bar — minimal style
    appBarTheme: AppBarTheme(
      backgroundColor: ZingColors.surface,
      foregroundColor: ZingColors.textDark,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: ZingColors.textDark,
        letterSpacing: 0.3,
      ),
      iconTheme: const IconThemeData(color: ZingColors.textDark, size: 24),
      toolbarHeight: 60,
    ),

    // Material 3 bottom navigation bar
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: ZingColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: ZingColors.primary.withOpacity(0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: ZingColors.primary,
          );
        }
        return GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: ZingColors.textLight,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: ZingColors.primary, size: 24);
        }
        return const IconThemeData(color: ZingColors.textLight, size: 24);
      }),
    ),

    // Search bar theme
    searchBarTheme: SearchBarThemeData(
      backgroundColor: WidgetStateProperty.all(ZingColors.surfaceVariant),
      elevation: WidgetStateProperty.all(0),
      hintStyle: WidgetStateProperty.all(
        GoogleFonts.inter(color: ZingColors.textLight, fontSize: 14),
      ),
      textStyle: WidgetStateProperty.all(
        GoogleFonts.inter(color: ZingColors.textDark, fontSize: 14),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 16),
      ),
    ),

    textTheme: TextTheme(
      displayLarge: GoogleFonts.poppins(
        color: ZingColors.textDark, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.poppins(
        color: ZingColors.textDark, fontSize: 26, fontWeight: FontWeight.w700,
      ),
      headlineLarge: GoogleFonts.poppins(
        color: ZingColors.textDark, fontSize: 22, fontWeight: FontWeight.w700,
      ),
      headlineMedium: GoogleFonts.poppins(
        color: ZingColors.textDark, fontSize: 20, fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.poppins(
        color: ZingColors.textDark, fontSize: 18, fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.poppins(
        color: ZingColors.textDark, fontSize: 16, fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.poppins(
        color: ZingColors.textDark, fontSize: 14, fontWeight: FontWeight.w600,
      ),
      titleSmall: GoogleFonts.poppins(
        color: ZingColors.textMedium, fontSize: 12, fontWeight: FontWeight.w500,
      ),
      bodyLarge: GoogleFonts.inter(
        color: ZingColors.textDark, fontSize: 16, fontWeight: FontWeight.w400, height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        color: ZingColors.textMedium, fontSize: 14, fontWeight: FontWeight.w400, height: 1.5,
      ),
      bodySmall: GoogleFonts.inter(
        color: ZingColors.textLight, fontSize: 12, fontWeight: FontWeight.w400, height: 1.4,
      ),
      labelLarge: GoogleFonts.poppins(
        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2,
      ),
      labelMedium: GoogleFonts.poppins(
        color: ZingColors.textMedium, fontSize: 12, fontWeight: FontWeight.w500,
      ),
      labelSmall: GoogleFonts.poppins(
        color: ZingColors.textLight, fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.4,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: ZingColors.primary,
        shadowColor: ZingColors.primary.withOpacity(0.3),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 28),
        textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
      ).copyWith(
        elevation: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return 0;
          if (states.contains(WidgetState.hovered)) return 4;
          return 0;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return Colors.white.withOpacity(0.15);
          return null;
        }),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ZingColors.primary,
        side: const BorderSide(color: ZingColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 28),
        textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ZingColors.primary,
        textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ZingColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ZingColors.divider, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ZingColors.divider, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ZingColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ZingColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ZingColors.error, width: 2),
      ),
      hintStyle: GoogleFonts.inter(color: ZingColors.textLight, fontSize: 14),
      labelStyle: GoogleFonts.inter(color: ZingColors.textMedium, fontSize: 14),
      prefixIconColor: ZingColors.textMedium,
      suffixIconColor: ZingColors.textMedium,
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ZingColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: ZingColors.surfaceVariant,
      selectedColor: ZingColors.primary.withOpacity(0.12),
      labelStyle: GoogleFonts.poppins(
        color: ZingColors.textMedium, fontSize: 12, fontWeight: FontWeight.w500,
      ),
      secondaryLabelStyle: GoogleFonts.poppins(
        color: ZingColors.primary, fontSize: 12, fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      elevation: 0,
      pressElevation: 2,
      side: const BorderSide(color: ZingColors.divider),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),

    cardTheme: CardThemeData(
      color: ZingColors.surface,
      shadowColor: ZingColors.primary.withOpacity(0.08),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: ZingColors.divider, width: 0.5),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: ZingColors.divider,
      thickness: 1,
      space: 1,
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: ZingColors.surface,
      selectedItemColor: ZingColors.primary,
      unselectedItemColor: ZingColors.textLight,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ZingColors.textDark,
      contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),

    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      iconColor: ZingColors.primary,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ZingColors.primary,
      linearTrackColor: ZingColors.surfaceVariant,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? ZingColors.primary : ZingColors.textLight),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? ZingColors.primary.withOpacity(0.3) : ZingColors.divider),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? ZingColors.primary : Colors.transparent),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: const BorderSide(color: ZingColors.divider, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),

    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? ZingColors.primary : ZingColors.textLight),
    ),
  );

  ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: ZingColors.primary,
    scaffoldBackgroundColor: ZingColors.darkBackground,

    colorScheme: const ColorScheme.dark(
      primary: ZingColors.primaryLight,
      onPrimary: Colors.white,
      primaryContainer: ZingColors.darkSurfaceVariant,
      onPrimaryContainer: ZingColors.primaryLight,
      secondary: ZingColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF4A0029),
      onSecondaryContainer: Color(0xFFFFD8E8),
      tertiary: ZingColors.accent,
      onTertiary: Colors.white,
      error: ZingColors.error,
      onError: Colors.white,
      surface: ZingColors.darkSurface,
      onSurface: ZingColors.darkTextDark,
      surfaceContainerHighest: ZingColors.darkSurfaceVariant,
      onSurfaceVariant: ZingColors.darkTextMedium,
      outline: ZingColors.darkDivider,
      shadow: Colors.black38,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: ZingColors.darkSurface,
      foregroundColor: ZingColors.darkTextDark,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: ZingColors.darkTextDark,
        letterSpacing: 0.3,
      ),
      iconTheme: const IconThemeData(color: ZingColors.darkTextDark, size: 24),
      toolbarHeight: 60,
    ),

    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: ZingColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: ZingColors.primaryLight.withOpacity(0.2),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: ZingColors.primaryLight,
          );
        }
        return GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: ZingColors.darkTextLight,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: ZingColors.primaryLight, size: 24);
        }
        return const IconThemeData(color: ZingColors.darkTextLight, size: 24);
      }),
    ),

    searchBarTheme: SearchBarThemeData(
      backgroundColor: WidgetStateProperty.all(ZingColors.darkSurfaceVariant),
      elevation: WidgetStateProperty.all(0),
      hintStyle: WidgetStateProperty.all(
        GoogleFonts.inter(color: ZingColors.darkTextLight, fontSize: 14),
      ),
      textStyle: WidgetStateProperty.all(
        GoogleFonts.inter(color: ZingColors.darkTextDark, fontSize: 14),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),

    textTheme: TextTheme(
      displayLarge: GoogleFonts.poppins(
        color: ZingColors.darkTextDark, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.poppins(
        color: ZingColors.darkTextDark, fontSize: 26, fontWeight: FontWeight.w700,
      ),
      headlineLarge: GoogleFonts.poppins(
        color: ZingColors.darkTextDark, fontSize: 22, fontWeight: FontWeight.w700,
      ),
      headlineMedium: GoogleFonts.poppins(
        color: ZingColors.darkTextDark, fontSize: 20, fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.poppins(
        color: ZingColors.darkTextDark, fontSize: 18, fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.poppins(
        color: ZingColors.darkTextDark, fontSize: 16, fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.poppins(
        color: ZingColors.darkTextDark, fontSize: 14, fontWeight: FontWeight.w600,
      ),
      titleSmall: GoogleFonts.poppins(
        color: ZingColors.darkTextMedium, fontSize: 12, fontWeight: FontWeight.w500,
      ),
      bodyLarge: GoogleFonts.inter(
        color: ZingColors.darkTextDark, fontSize: 16, fontWeight: FontWeight.w400, height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        color: ZingColors.darkTextMedium, fontSize: 14, fontWeight: FontWeight.w400, height: 1.5,
      ),
      bodySmall: GoogleFonts.inter(
        color: ZingColors.darkTextLight, fontSize: 12, fontWeight: FontWeight.w400, height: 1.4,
      ),
      labelLarge: GoogleFonts.poppins(
        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2,
      ),
      labelMedium: GoogleFonts.poppins(
        color: ZingColors.darkTextMedium, fontSize: 12, fontWeight: FontWeight.w500,
      ),
      labelSmall: GoogleFonts.poppins(
        color: ZingColors.darkTextLight, fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.4,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: ZingColors.primaryLight,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 28),
        textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return Colors.white.withOpacity(0.15);
          return null;
        }),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ZingColors.primaryLight,
        side: const BorderSide(color: ZingColors.primaryLight, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 28),
        textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ZingColors.darkSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ZingColors.darkDivider, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ZingColors.darkDivider, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ZingColors.primaryLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ZingColors.error, width: 1.5),
      ),
      hintStyle: GoogleFonts.inter(color: ZingColors.darkTextLight, fontSize: 14),
      labelStyle: GoogleFonts.inter(color: ZingColors.darkTextMedium, fontSize: 14),
      prefixIconColor: ZingColors.darkTextMedium,
      suffixIconColor: ZingColors.darkTextMedium,
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ZingColors.primaryLight,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: ZingColors.darkSurfaceVariant,
      selectedColor: ZingColors.primaryLight.withOpacity(0.2),
      labelStyle: GoogleFonts.poppins(
        color: ZingColors.darkTextMedium, fontSize: 12, fontWeight: FontWeight.w500,
      ),
      secondaryLabelStyle: GoogleFonts.poppins(
        color: ZingColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      elevation: 0,
      side: const BorderSide(color: ZingColors.darkDivider),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),

    cardTheme: CardThemeData(
      color: ZingColors.darkSurface,
      shadowColor: Colors.black.withOpacity(0.3),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: ZingColors.darkDivider, width: 0.5),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: ZingColors.darkDivider,
      thickness: 1,
      space: 1,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ZingColors.darkSurfaceVariant,
      contentTextStyle: GoogleFonts.inter(color: ZingColors.darkTextDark, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),

    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      iconColor: ZingColors.primaryLight,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ZingColors.primaryLight,
    ),
  );
}
