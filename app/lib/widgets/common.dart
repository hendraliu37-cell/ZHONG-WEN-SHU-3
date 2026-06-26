import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import 'ico.dart';

/// Hanzi (Kaiti) text.
class Han extends StatelessWidget {
  final String text;
  final double size;
  final FontWeight weight;
  final Color? color;
  final double? height;
  final double? letterSpacing;
  const Han(
    this.text, {
    super.key,
    this.size = 28,
    this.weight = FontWeight.w500,
    this.color,
    this.height,
    this.letterSpacing,
  });

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: ZwsFonts.han(
      size: size,
      weight: weight,
      color: color ?? ZwsTheme.of(context).ink,
      height: height,
      letterSpacing: letterSpacing,
    ),
  );
}

/// Mono numerals / codes.
class Mono extends StatelessWidget {
  final String text;
  final double size;
  final FontWeight weight;
  final Color? color;
  final double? letterSpacing;
  const Mono(
    this.text, {
    super.key,
    this.size = 12,
    this.weight = FontWeight.w400,
    this.color,
    this.letterSpacing,
  });

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: ZwsFonts.mono(
      size: size,
      weight: weight,
      color: color ?? ZwsTheme.of(context).ink3,
      letterSpacing: letterSpacing,
    ),
  );
}

/// Uppercase, letter-spaced section label (ink3).
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Text(
      text.toUpperCase(),
      style: ZwsFonts.sans(
        size: 11,
        weight: FontWeight.w600,
        color: t.ink3,
        letterSpacing: 1.7,
      ),
    );
  }
}

/// A surface card container.
class SurfaceBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? background;
  final Color? border;
  final bool clip;
  const SurfaceBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 18,
    this.background,
    this.border,
    this.clip = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Container(
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: background ?? t.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? t.line),
      ),
      child: child,
    );
  }
}

/// Pill badge (e.g. "HSK 2").
class Pill extends StatelessWidget {
  final String text;
  final Color? fg;
  final Color? bg;
  final Color? borderColor;
  const Pill(this.text, {super.key, this.fg, this.bg, this.borderColor});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg ?? t.sealSoft,
        borderRadius: BorderRadius.circular(20),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: Text(
        text,
        style: ZwsFonts.sans(
          size: 11,
          weight: FontWeight.w700,
          color: fg ?? t.seal,
        ),
      ),
    );
  }
}

/// Top bar for full-screen overlays: back button + centered/left title.
class OverlayBar extends StatelessWidget {
  final VoidCallback onBack;
  final Widget title;
  final Widget? trailing;
  final bool desktop;
  const OverlayBar({
    super.key,
    required this.onBack,
    required this.title,
    this.trailing,
    this.desktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: desktop ? 22 : 14,
        vertical: desktop ? 16 : 13,
      ),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      child: Row(
        children: [
          _SquareButton(icon: ZwsIcons.back, onTap: onBack),
          const SizedBox(width: 10),
          Expanded(child: title),
          const SizedBox(width: 10),
          trailing ?? const SizedBox(width: 38),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SquareButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: t.line),
          ),
          child: Icon(icon, size: 20, color: t.ink2),
        ),
      ),
    );
  }
}

/// The little brand seal (书) tile.
class SealMark extends StatelessWidget {
  final double size;
  final double fontSize;
  final double radius;
  const SealMark({
    super.key,
    this.size = 36,
    this.fontSize = 23,
    this.radius = 10,
  });
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Transform.rotate(
      angle: -0.087, // ~ -5deg
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.seal,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Text(
          '书',
          style: ZwsFonts.han(
            size: fontSize,
            weight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Full-bleed filled "ink" button.
class InkButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  const InkButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Material(
      color: t.ink,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: t.bg),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: ZwsFonts.sans(
                  size: 15,
                  weight: FontWeight.w700,
                  color: t.bg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Question-count stepper card. The maximum follows the active deck/session.
/// games hub.
class CountStepper extends StatelessWidget {
  final int count;
  final String limitLabel;
  final VoidCallback onInc;
  final VoidCallback onDec;
  const CountStepper({
    super.key,
    required this.count,
    required this.limitLabel,
    required this.onInc,
    required this.onDec,
  });

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    Widget step(String label, VoidCallback onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.line),
        ),
        child: Text(
          label,
          style: ZwsFonts.sans(size: 20, weight: FontWeight.w700, color: t.ink),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jumlah soal',
                  style: ZwsFonts.sans(
                    size: 14,
                    weight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
                Text(limitLabel, style: ZwsFonts.sans(size: 11, color: t.ink3)),
              ],
            ),
          ),
          step('−', onDec),
          SizedBox(
            width: 40,
            child: Center(
              child: Mono(
                '$count',
                size: 18,
                weight: FontWeight.w700,
                color: t.ink,
              ),
            ),
          ),
          step('+', onInc),
        ],
      ),
    );
  }
}

/// Progress bar used in review/quiz overlays.
class ThinProgress extends StatelessWidget {
  final double pct; // 0..1
  const ThinProgress(this.pct, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Container(
      height: 4,
      color: t.line2,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: pct.clamp(0, 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            color: t.seal,
          ),
        ),
      ),
    );
  }
}
