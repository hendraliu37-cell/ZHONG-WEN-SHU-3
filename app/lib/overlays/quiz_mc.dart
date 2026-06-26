import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../widgets/common.dart';
import 'quiz_shared.dart';

class McQuizOverlay extends StatelessWidget {
  final AppController controller;
  final bool desktop;
  const McQuizOverlay({
    super.key,
    required this.controller,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    final finished = c.quizIdx >= c.quizTotal;
    final q = c.currentQuiz;
    final shownIdx = (c.quizIdx + 1).clamp(1, c.quizTotal);
    return Container(
      color: t.bg,
      child: Column(
        children: [
          OverlayBar(
            desktop: desktop,
            onBack: c.closeSub,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pilihan Ganda',
                  style: ZwsFonts.sans(
                    size: 15,
                    weight: FontWeight.w800,
                    color: t.ink,
                  ),
                ),
                Mono(
                  '$shownIdx / ${c.quizTotal} · skor ${c.quizScore}',
                  size: 11,
                  color: t.ink3,
                ),
              ],
            ),
          ),
          ThinProgress(c.quizIdx / c.quizTotal),
          Expanded(
            child: finished || q == null
                ? QuizFinish(
                    score: c.quizScore,
                    total: c.quizTotal,
                    onRestart: c.restartQuiz,
                    onClose: c.closeSub,
                    footnote: 'Masuk ke nilai Ujian Harian.',
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
    final card = c.card(q.cardId);
    final answered = c.quizPicked != null;
    final id2zh = c.testDirection == 'id2zh';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            id2zh ? 'Apa hanzi untuk arti ini?' : 'Apa arti kata ini?',
            style: ZwsFonts.sans(size: 12, color: t.ink3),
          ),
          const SizedBox(height: 6),
          if (id2zh)
            Text(
              card.primaryMeaning,
              style: ZwsFonts.sans(
                size: 28,
                weight: FontWeight.w700,
                color: t.ink,
              ),
            )
          else ...[
            Han(c.primaryHanzi(card), size: 66, color: t.ink, height: 1.1),
            Mono(q.cardId >= 0 ? card.pinyin : '', size: 14, color: t.ink3),
          ],
          const SizedBox(height: 20),
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
                    isHanzi: id2zh,
                    onTap: () => c.pickQuiz(opt),
                  ),
                  const SizedBox(height: 10),
                ],
                if (answered)
                  InkButton(
                    label: c.quizIdx >= c.quizTotal - 1
                        ? 'Lihat hasil'
                        : 'Lanjut',
                    onTap: c.nextQuiz,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
