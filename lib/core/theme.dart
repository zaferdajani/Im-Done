import 'package:flutter/material.dart';

/// One seed colour, Material 3, generous radii — the whole visual identity.
class ImDoneTheme {
  static const seed = Color(0xFF0E7C86); // deep teal
  static const accent = Color(0xFFFF8A3D); // warm coral for the mic + "done"

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: b == Brightness.light ? const Color(0xFFF7F8F6) : const Color(0xFF0F1413),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
