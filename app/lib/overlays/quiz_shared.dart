import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../widgets/common.dart';

/// One answer option for MC / Listening quizzes.
class QuizOption extends StatelessWidget {
  final String text;
  final bool correct;
  final bool picked;
  final bool answered;
  final VoidCallback onTap;
  final bool isHanzi;
  const QuizOption({
    super.key,
    required this.text,
    required this.correct,
    required this.picked,
    required this.answered,
    required this.onTap,
    this.isHanzi = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    Color border = t.line;
    Color bg = t.surface;
    Color fg = t.ink;
    double opacity = 1;
    String mark = '';
    if (answered) {
      if (correct) {
        border = t.green;
        bg = t.correctTint;
        fg = t.green;
        mark = '✓';
      } else if (picked) {
        border = t.seal;
        bg = t.sealSoft;
        fg = t.seal;
        mark = '✕';
      } else {
        opacity = 0.55;
      }
    }
    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: answered ? null : onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Expanded(
                child: isHanzi
                    ? Han(text, size: 22, color: fg)
                    : Text(text,
                        style: ZwsFonts.sans(
                            size: 15, weight: FontWeight.w600, color: fg)),
              ),
              if (mark.isNotEmpty)
                Han(mark, size: 16, color: fg, weight: FontWeight.w700),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared finish panel for MC / Listening.
class QuizFinish extends StatelessWidget {
  final int score;
  final int total;
  final VoidCallback onRestart;
  final VoidCallback onClose;
  final String footnote;
  const QuizFinish({
    super.key,
    required this.score,
    required this.total,
    required this.onRestart,
    required this.onClose,
    required this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final verdict = score >= total - 1
        ? 'Luar biasa!'
        : (score >= (total / 2).ceil() ? 'Bagus, terus berlatih' : 'Ayo coba lagi');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Mono('$score', size: 64, weight: FontWeight.w700, color: t.seal),
                Mono('/$total', size: 24, color: t.ink3),
              ],
            ),
            const SizedBox(height: 8),
            Text(verdict,
                style: ZwsFonts.sans(
                    size: 22, weight: FontWeight.w800, color: t.ink)),
            const SizedBox(height: 6),
            Text(footnote, style: ZwsFonts.sans(size: 13, color: t.ink2)),
            const SizedBox(height: 22),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Btn(label: 'Ulang', filled: false, onTap: onRestart),
                const SizedBox(width: 10),
                _Btn(label: 'Selesai', filled: true, onTap: onClose),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.filled, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Material(
      color: filled ? t.ink : t.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: filled ? null : Border.all(color: t.line),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          child: Text(label,
              style: ZwsFonts.sans(
                  size: 14,
                  weight: FontWeight.w700,
                  color: filled ? t.bg : t.ink)),
        ),
      ),
    );
  }
}
