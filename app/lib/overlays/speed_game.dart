import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../widgets/common.dart';

class SpeedGameOverlay extends StatelessWidget {
  final AppController controller;
  final bool desktop;
  const SpeedGameOverlay(
      {super.key, required this.controller, required this.desktop});

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    final total = c.speedTotal;
    final finished = c.speedLeft <= 0 || c.speedIdx >= total;
    final barColor = c.speedLeft <= 10 ? t.seal : t.green;
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
                Text('Speed Recall',
                    style: ZwsFonts.sans(
                        size: 15, weight: FontWeight.w800, color: t.ink)),
                Mono('${c.speedScore} benar · ${c.speedLeft}s',
                    size: 11, color: t.ink3),
              ],
            ),
          ),
          Container(
            height: 5,
            color: t.line2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: (c.speedLeft / 45).clamp(0, 1),
                child: AnimatedContainer(
                    duration: const Duration(seconds: 1), color: barColor),
              ),
            ),
          ),
          Expanded(
            child: finished
                ? _Finish(controller: c)
                : _Active(controller: c, barColor: barColor),
          ),
        ],
      ),
    );
  }
}

class _Active extends StatelessWidget {
  final AppController controller;
  final Color barColor;
  const _Active({required this.controller, required this.barColor});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    final cur = c.speedCur;
    if (cur == null) return const SizedBox.shrink();
    final card = c.card(cur.cardId);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Mono('${c.speedLeft} detik',
              size: 15, weight: FontWeight.w700, color: barColor),
          const SizedBox(height: 14),
          Han(c.primaryHanzi(card), size: 74, color: t.ink, height: 1.05),
          Mono(card.pinyin, size: 13, color: t.ink3),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                for (final opt in cur.options) ...[
                  InkWell(
                    onTap: () => c.speedPick(opt),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: t.line),
                      ),
                      child: Text(opt,
                          textAlign: TextAlign.center,
                          style: ZwsFonts.sans(
                              size: 15, weight: FontWeight.w600, color: t.ink)),
                    ),
                  ),
                  const SizedBox(height: 9),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Finish extends StatelessWidget {
  final AppController controller;
  const _Finish({required this.controller});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    final verdict = c.speedScore >= 8 ? 'Cepat & tepat!' : 'Lumayan!';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Mono('${c.speedScore}',
              size: 64, weight: FontWeight.w700, color: t.seal),
          const SizedBox(height: 8),
          Text(verdict,
              style: ZwsFonts.sans(
                  size: 22, weight: FontWeight.w800, color: t.ink)),
          const SizedBox(height: 6),
          Text('benar dalam 45 detik · menyumbang nilai Praktek',
              textAlign: TextAlign.center,
              style: ZwsFonts.sans(size: 13, color: t.ink2)),
          const SizedBox(height: 22),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Btn(label: 'Ulang', filled: false, onTap: c.startSpeed),
              const SizedBox(width: 10),
              _Btn(label: 'Selesai', filled: true, onTap: c.goGames),
            ],
          ),
        ],
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
