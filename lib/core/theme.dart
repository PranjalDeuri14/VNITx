import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color _bgDark = Color(0xFF0D0E1A);
  static const Color _bgCard = Color(0xFF161728);
  static const Color _bgCardLight = Color(0xFF1E2035);
  static const Color _primary = Color(0xFF7C4DFF);
  static const Color _primaryLight = Color(0xFF9C6FFF);
  static const Color _accent = Color(0xFF00E5FF);
  static const Color _success = Color(0xFF00E676);
  static const Color _warning = Color(0xFFFFD740);
  static const Color _error = Color(0xFFFF1744);
  static const Color _textPrimary = Color(0xFFECEEFF);
  static const Color _textSecondary = Color(0xFF8B8FAD);
  static const Color _divider = Color(0xFF2A2C45);

  static Color get background => _bgDark;
  static Color get cardBackground => _bgCard;
  static Color get cardBackgroundLight => _bgCardLight;
  static Color get primary => _primary;
  static Color get primaryLight => _primaryLight;
  static Color get accent => _accent;
  static Color get success => _success;
  static Color get warning => _warning;
  static Color get error => _error;
  static Color get textPrimary => _textPrimary;
  static Color get textSecondary => _textSecondary;
  static Color get divider => _divider;

  static ThemeData get theme {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: _bgDark,
      colorScheme: const ColorScheme.dark(
        primary: _primary,
        secondary: _accent,
        surface: _bgCard,
        error: _error,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: _textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _bgDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
        ),
        iconTheme: const IconThemeData(color: _textPrimary),
      ),
      cardTheme: CardThemeData(
        color: _bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _divider),
        ),
        margin: const EdgeInsets.all(0),
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        bodyLarge: GoogleFonts.inter(color: _textPrimary, fontSize: 15),
        bodyMedium: GoogleFonts.inter(color: _textSecondary, fontSize: 13),
        titleLarge: GoogleFonts.inter(
          color: _textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.inter(
          color: _textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        labelLarge: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _accent,
          side: const BorderSide(color: _accent),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _bgCardLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        labelStyle: GoogleFonts.inter(color: _textSecondary),
        hintStyle: GoogleFonts.inter(color: _textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? _primary : _textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? _primary.withOpacity(0.4)
              : _divider,
        ),
      ),
      dividerTheme: const DividerThemeData(color: _divider, thickness: 1),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _bgCard,
        selectedItemColor: _primary,
        unselectedItemColor: _textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _bgCardLight,
        labelStyle: GoogleFonts.inter(color: _textPrimary, fontSize: 12),
        side: BorderSide(color: _divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _bgCardLight,
        contentTextStyle: GoogleFonts.inter(color: _textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
