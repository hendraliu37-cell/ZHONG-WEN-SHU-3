import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../widgets/common.dart';
import '../widgets/ico.dart';

class ToneGameOverlay extends StatelessWidget {
  final AppController controller;
  final bool desktop;
  const ToneGameOverlay(
      {super.key, required this.controller, required this.desktop});

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    final total = c.toneTotal;
    final finished = c.toneIdx >= total;
    final shown = (c.toneIdx + 1).clamp(1, total);
    return Container(
      color: t.bg,
      child: Column(
        children: [
          OverlayBar(
            desktop: desktop,
            onBack: c.goGames,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Tebak Nada',
                    style: ZwsFonts.sans(
                        size: 15, weight: FontWeight.w800, color: t.ink)),
                Mono('$shown / $total · ${c.toneScore} benar',
                    size: 11, color: t.ink3),
              ],
            ),
          ),
          Expanded(
            child: finished
                ? _Finish(controller: c, total: total)
                : _Active(controller: c),
          ),
        ],
      ),
    );
  }
}

class _Active extends StatelessWidget {
  final AppController controller;
  const _Active({required this.controller});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    final cur = c.toneCur;
    final answered = c.tonePicked != null;
    const marks = {1: 'ˉ', 2: 'ˊ', 3: 'ˇ', 4: 'ˋ'};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text('Nada keberapa kata ini?',
              style: ZwsFonts.sans(size: 12, color: t.ink3)),
          const SizedBox(height: 6),
          Han(cur.han, size: 96, color: t.ink, height: 1.05),
          const SizedBox(height: 6),
          InkWell(
            onTap: c.replayTone,
            borderRadius: BorderRadius.circular(11),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: t.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(ZwsIcons.sound, size: 18, color: t.seal),
                  const SizedBox(width: 8),
                  Text('Putar lagi',
                      style: ZwsFonts.sans(
                          size: 13, weight: FontWeight.w700, color: t.seal)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Row(
              children: [
                for (final n in [1, 2, 3, 4]) ...[
                  Expanded(
                    child: _ToneOpt(
                      mark: marks[n]!,
                      n: n,
                      answered: answered,
                      correct: n == cur.tone,
                      picked: c.tonePicked == n,
                      onTap: () => c.pickTone(n),
                    ),
                  ),
                  if (n != 4) const SizedBox(width: 9),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (answered)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: InkButton(
                label: c.toneIdx >= c.toneTotal - 1 ? 'Lihat hasil' : 'Lanjut',
                onTap: c.nextTone,
              ),
            ),
        ],
      ),
    );
  }
}

class _ToneOpt extends StatelessWidget {
  final String mark;
  final int n;
  final bool answered;
  final bool correct;
  final bool picked;
  final VoidCallback onTap;
  const _ToneOpt(
      {required this.mark,
      required this.n,
      required this.answered,
      required this.correct,
      required this.picked,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    Color border = t.line, bg = t.surface, fg = t.ink2;
    double opacity = 1;
    if (answered) {
      if (correct) {
        border = t.green;
        bg = t.correctTint;
        fg = t.green;
      } else if (picked) {
        border = t.seal;
        bg = t.sealSoft;
        fg = t.seal;
      } else {
        opacity = 0.5;
      }
    }
    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: answered ? null : onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              Text(mark, style: ZwsFonts.sans(size: 22, weight: FontWeight.w700, color: fg)),
              const SizedBox(height: 3),
              Text('$n', style: ZwsFonts.sans(size: 11, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Finish extends StatelessWidget {
  final AppController controller;
  final int total;
  const _Finish({required this.controller, required this.total});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Mono('${c.toneScore}',
                  size: 60, weight: FontWeight.w700, color: t.seal),
              Mono('/$total', size: 22, color: t.ink3),
            ],
          ),
          const SizedBox(height: 8),
          Text('Mantap!',
              style: ZwsFonts.sans(
                  size: 21, weight: FontWeight.w800, color: t.ink)),
          const SizedBox(height: 6),
          Text('Menyumbang ke nilai Praktek.',
              style: ZwsFonts.sans(size: 13, color: t.ink2)),
          const SizedBox(height: 22),
          Material(
            color: t.ink,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: c.startTone,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
                child: Text('Main lagi',
                    style: ZwsFonts.sans(
                        size: 14, weight: FontWeight.w700, color: t.bg)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
