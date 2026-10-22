import 'package:flutter/material.dart';

/// Design tokens from SmartRelay_Asset_Kit (`tokens/design-tokens.json`).
@immutable
class Palette {
  const Palette({
    required this.isDark,
    required this.bg,
    required this.bgEnd,
    required this.surface,
    required this.surfaceAlt,
    required this.stroke,
    required this.txt,
    required this.txtDim,
    required this.tech,
    required this.on,
    required this.danger,
    required this.techSoft,
    required this.onSoft,
    required this.dangerSoft,
  });

  final bool isDark;
  final Color bg;
  final Color bgEnd;
  final Color surface;
  final Color surfaceAlt;
  final Color stroke;
  final Color txt;
  final Color txtDim;
  final Color tech;
  final Color on;
  final Color danger;
  final Color techSoft;
  final Color onSoft;
  final Color dangerSoft;

  static const dark = Palette(
    isDark: true,
    bg: Color(0xFF070B14),
    bgEnd: Color(0xFF0E1626),
    surface: Color(0xFF141E2F),
    surfaceAlt: Color(0xFF1A2638),
    stroke: Color(0x14FFFFFF),
    txt: Color(0xFFE6EDF7),
    txtDim: Color(0xFF93A4BD),
    tech: Color(0xFF22D3EE),
    on: Color(0xFFF59E0B),
    danger: Color(0xFFF43F5E),
    techSoft: Color(0x2622D3EE),
    onSoft: Color(0x1FF59E0B),
    dangerSoft: Color(0x24F43F5E),
  );

  static const light = Palette(
    isDark: false,
    bg: Color(0xFFF3F6FA),
    bgEnd: Color(0xFFE8EFF7),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF7FAFD),
    stroke: Color(0xFFD7E1EC),
    txt: Color(0xFF152238),
    txtDim: Color(0xFF53657D),
    tech: Color(0xFF087F91),
    on: Color(0xFFB76A06),
    danger: Color(0xFFE11D48),
    techSoft: Color(0xFFE3F6F9),
    onSoft: Color(0xFFFFF3E0),
    dangerSoft: Color(0xFFFFE8ED),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  String get fanDir => isDark ? 'assets/fans/dark' : 'assets/fans/light';

  String get background => isDark
      ? 'assets/backgrounds/dark-base.webp'
      : 'assets/backgrounds/light-base.webp';

  String get aurora => isDark
      ? 'assets/backgrounds/dark-aurora.webp'
      : 'assets/backgrounds/light-aurora.webp';
}

/// Legacy dark aliases used during migration — prefer [Palette.of].
abstract final class AppColors {
  static const bg0 = Color(0xFF070B14);
  static const bg1 = Color(0xFF0E1626);
  static const bg2 = Color(0xFF141E2F);
  static const stroke = Color(0x14FFFFFF);
  static const txt = Color(0xFFE6EDF7);
  static const txtDim = Color(0xFF93A4BD);
  static const cyan = Color(0xFF22D3EE);
  static const teal = Color(0xFF14B8A6);
  static const amber = Color(0xFFF59E0B);
  static const danger = Color(0xFFF43F5E);
}

/// Typography roles (Vazirmatn 400 / 500 / 600).
abstract final class T {
  static const family = 'Vazirmatn';
  static const TextStyle _base = TextStyle(fontFamily: family);

  static TextStyle welcome(Palette p) => _base.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 40 / 28,
        color: p.txt,
      );

  static TextStyle title(Palette p) => _base.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 34 / 24,
        color: p.txt,
      );

  static TextStyle greeting(Palette p) => _base.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        height: 30 / 20,
        color: p.txt,
      );

  static TextStyle device(Palette p) => _base.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
        color: p.txt,
      );

  static TextStyle body(Palette p) => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: p.txt,
      );

  static TextStyle button(Palette p) => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 24 / 16,
        color: p.txt,
      );

  static TextStyle meta(Palette p) => _base.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 20 / 13,
        color: p.txtDim,
      );
}

abstract final class AppRadii {
  static const card = 24.0;
  static const sheet = 28.0;
  static const button = 24.0;
  static const pill = 999.0;
}

abstract final class AppSpace {
  static const xs = 8.0;
  static const sm = 16.0;
  static const md = 24.0;
  static const lg = 32.0;
  static const xl = 40.0;
  static const xxl = 48.0;
  static const gutter = 24.0;
  static const cardGap = 16.0;
  static const touch = 48.0;
}

class AppTheme {
  static const String fontFamily = T.family;

  static const Duration splashRing = Duration(milliseconds: 600);
  static const Duration splashGlyph = Duration(milliseconds: 300);
  static const Duration splashText = Duration(milliseconds: 300);
  static const Duration toggle = Duration(milliseconds: 240);
  static const Duration fanTurn = Duration(milliseconds: 1800);
  static const Duration pulse = Duration(milliseconds: 2400);
  static const Duration sending = Duration(milliseconds: 1000);
  static const Duration press = Duration(milliseconds: 100);
  static const Duration ripple = Duration(milliseconds: 320);
  static const Duration sheetIn = Duration(milliseconds: 240);
  static const Duration sheetDismiss = Duration(milliseconds: 3000);
  static const Curve standard = Cubic(0.2, 0, 0, 1);
  static const Curve splash = Cubic(0.22, 1, 0.36, 1);

  static ThemeData dark() => _build(Palette.dark);
  static ThemeData light() => _build(Palette.light);

  static ThemeData _build(Palette p) {
    final scheme = ColorScheme(
      brightness: p.isDark ? Brightness.dark : Brightness.light,
      primary: p.tech,
      onPrimary: p.isDark ? const Color(0xFF04222A) : Colors.white,
      secondary: p.on,
      onSecondary: p.isDark ? const Color(0xFF241503) : Colors.white,
      error: p.danger,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.txt,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      fontFamily: T.family,
      splashFactory: InkSparkle.splashFactory,
      textTheme: TextTheme(
        headlineLarge: T.welcome(p),
        headlineSmall: T.title(p),
        titleMedium: T.device(p),
        titleSmall: T.greeting(p),
        bodyLarge: T.body(p),
        bodyMedium: T.body(p).copyWith(fontSize: 14),
        labelLarge: T.button(p),
        labelMedium: T.meta(p),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceAlt,
        contentTextStyle: T.body(p).copyWith(fontSize: 14, color: p.txt),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: p.stroke, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: p.txt,
        titleTextStyle: T.title(p).copyWith(fontSize: 20),
        iconTheme: IconThemeData(color: p.txtDim),
      ),
    );
  }
}
