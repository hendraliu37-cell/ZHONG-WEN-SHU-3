import 'package:flutter/material.dart';

/// Design tokens for ZHONGWEN SHU.
///
/// Ported 1:1 from the locked `claude design` prototype (`ZWSApp.dc.html`).
/// Two intentional palettes (never auto-inverted): light + dark.
class ZwsTokens {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color line;
  final Color line2;
  final Color seal;
  final Color sealSoft;
  final Color gold;
  final Color green;
  final bool isDark;

  const ZwsTokens({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.line2,
    required this.seal,
    required this.sealSoft,
    required this.gold,
    required this.green,
    required this.isDark,
  });

  static const ZwsTokens light = ZwsTokens(
    bg: Color(0xFFF4F1EA),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFFAF7F1),
    ink: Color(0xFF1F1D1A),
    ink2: Color(0xFF6B665C),
    ink3: Color(0xFF9A948A),
    line: Color(0xFFE7E1D5),
    line2: Color(0xFFEFEAE0),
    seal: Color(0xFFB23B2E),
    sealSoft: Color(0xFFF3DDD8),
    gold: Color(0xFFB8862F),
    green: Color(0xFF3A9E6A),
    isDark: false,
  );

  static const ZwsTokens dark = ZwsTokens(
    bg: Color(0xFF15130F),
    surface: Color(0xFF1F1C17),
    surface2: Color(0xFF26221B),
    ink: Color(0xFFF1ECE1),
    ink2: Color(0xFFB3AB9C),
    ink3: Color(0xFF7D766A),
    line: Color(0xFF322D24),
    line2: Color(0xFF2A261E),
    seal: Color(0xFFCF5042),
    sealSoft: Color(0xFF3A221D),
    gold: Color(0xFFD6A443),
    green: Color(0xFF5CBA85),
    isDark: true,
  );

  /// Green "correct" tint used for option/result backgrounds.
  Color get correctTint => isDark ? const Color(0xFF16271D) : const Color(0xFFEAF5EE);
}

/// Font families. Hanzi uses Kaiti (楷体) with broad fallbacks so 简 & 繁
/// both render; Latin UI uses a clean modern sans; numerals use a mono face.
class ZwsFonts {
  static const List<String> hanziFallback = [
    'Kaiti',
    'STKaiti',
    'KaiTi',
    'Noto Serif SC',
    'Noto Serif TC',
    'serif',
  ];

  static const List<String> sansFallback = [
    'Hanken Grotesk',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  static const List<String> monoFallback = [
    'Space Mono',
    'Consolas',
    'Courier New',
    'monospace',
  ];

  /// Latin UI text (default body).
  static TextStyle sans({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamilyFallback: sansFallback,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Hanzi (Kaiti) text.
  static TextStyle han({
    double size = 28,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamilyFallback: hanziFallback,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Mono numerals / codes (Space Mono).
  static TextStyle mono({
    double size = 12,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamilyFallback: monoFallback,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );
}

/// Convenience: build a Material [ThemeData] seeded from tokens. The app draws
/// most chrome by hand (to match the prototype exactly), so this is mostly for
/// default text color, scrollbars, and selection.
ThemeData zwsThemeData(ZwsTokens t) {
  final base = t.isDark ? ThemeData.dark() : ThemeData.light();
  return base.copyWith(
    scaffoldBackgroundColor: t.bg,
    canvasColor: t.bg,
    splashColor: t.seal.withValues(alpha: 0.10),
    highlightColor: t.seal.withValues(alpha: 0.06),
    colorScheme: base.colorScheme.copyWith(
      primary: t.seal,
      surface: t.surface,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: t.seal,
      selectionColor: t.seal.withValues(alpha: 0.25),
      selectionHandleColor: t.seal,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(t.line),
      thickness: const WidgetStatePropertyAll(8),
      radius: const Radius.circular(8),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: t.ink,
      displayColor: t.ink,
      fontFamilyFallback: ZwsFonts.sansFallback,
    ),
  );
}
