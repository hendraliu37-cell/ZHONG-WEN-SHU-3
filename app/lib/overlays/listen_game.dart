import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../widgets/common.dart';
import '../widgets/ico.dart';
import 'quiz_shared.dart';

class ListenGameOverlay extends StatelessWidget {
  final AppController controller;
  final bool desktop;
  const ListenGameOverlay(
      {super.key, required this.controller, required this.desktop});

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    final finished = c.quizIdx >= c.quizTotal;
    final q = c.currentQuiz;
    final shown = (c.quizIdx + 1).clamp(1, c.quizTotal);
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
                Text('Listening Quiz',
                    style: ZwsFonts.sans(
                        size: 15, weight: FontWeight.w800, color: t.ink)),
                Mono('$shown / ${c.quizTotal} · skor ${c.quizScore}',
                    size: 11, color: t.ink3),
              ],
            ),
          ),
          ThinProgress(c.quizIdx / c.quizTotal),
          Expanded(
            child: finished || q == null
                ? QuizFinish(
                    score: c.quizScore,
                    total: c.quizTotal,
                    onRestart: c.goListen,
                    onClose: c.goGames,
                    footnote: 'Menyumbang ke nilai Praktek.',
                  )
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
    final q = c.currentQuiz!;
    final answered = c.quizPicked != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Text('Dengarkan, lalu pilih artinya',
              style: ZwsFonts.sans(size: 12, color: t.ink3)),
          const SizedBox(height: 18),
          InkWell(
            onTap: c.playListenCur,
            borderRadius: BorderRadius.circular(60),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: t.sealSoft,
                shape: BoxShape.circle,
                border: Border.all(color: t.seal),
              ),
              child: Icon(ZwsIcons.sound, size: 48, color: t.seal),
            ),
          ),
          const SizedBox(height: 22),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                for (final opt in q.options) ...[
                  QuizOption(
                    text: opt,
                    correct: opt == q.correct,
                    picked: c.quizPicked == opt,
                    answered: answered,
                    onTap: () => c.pickQuiz(opt),
                  ),
                  const SizedBox(height: 10),
                ],
                if (answered)
                  InkButton(
                    label: c.quizIdx >= c.quizTotal - 1 ? 'Lihat hasil' : 'Lanjut',
                    onTap: c.nextListen,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
