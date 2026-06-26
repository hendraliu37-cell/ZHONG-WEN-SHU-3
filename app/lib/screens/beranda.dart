import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../widgets/common.dart';
import '../widgets/ico.dart';

class BerandaScreen extends StatelessWidget {
  final AppController controller;
  final bool desktop;
  const BerandaScreen({
    super.key,
    required this.controller,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    final due = c.dueCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Rabu, 11 Juni 2026',
          style: ZwsFonts.sans(size: 13, color: t.ink2),
        ),
        const SizedBox(height: 14),
        // Rapor ring + due card
        _TwoCol(
          desktop: desktop,
          left: _RaporCard(controller: c),
          right: _DueCard(controller: c, due: due),
        ),
        const SizedBox(height: 14),
        _MateriCard(controller: c),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _QuickButton(
                icon: ZwsIcons.quiz,
                label: 'Tes Harian',
                onTap: c.goDailyTest,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickButton(
                icon: ZwsIcons.game,
                label: 'Games',
                onTap: c.goGames,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickButton(
                icon: ZwsIcons.mic,
                label: 'Pelafalan',
                onTap: c.goVoice,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _QuickButton(
                icon: ZwsIcons.spell,
                label: 'Ujian Akhir',
                onTap: c.startUjianAkhir,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(child: SizedBox.shrink()),
            const SizedBox(width: 10),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
        const SizedBox(height: 14),
        _LeaderboardCard(controller: c),
      ],
    );
  }
}

class _TwoCol extends StatelessWidget {
  final bool desktop;
  final Widget left;
  final Widget right;
  const _TwoCol({
    required this.desktop,
    required this.left,
    required this.right,
  });
  @override
  Widget build(BuildContext context) {
    if (!desktop) {
      return Column(children: [left, const SizedBox(height: 12), right]);
    }
    // IntrinsicHeight bounds the row height so stretch is valid inside the
    // (vertically unbounded) scroll view, and keeps both cards equal height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 13, child: left),
          const SizedBox(width: 12),
          Expanded(flex: 10, child: right),
        ],
      ),
    );
  }
}

class _RaporCard extends StatelessWidget {
  final AppController controller;
  const _RaporCard({required this.controller});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final total = controller.raporTotal;
    return SurfaceBox(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: CustomPaint(
              painter: _RingPainter(total / 100, t.seal, t.line2),
              child: Center(
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: t.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Mono(
                        '$total',
                        size: 30,
                        weight: FontWeight.w800,
                        color: t.ink,
                      ),
                      Mono('/ 100', size: 10, color: t.ink3, letterSpacing: 1),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SectionLabel('Rapor berjalan'),
                const SizedBox(height: 3),
                Text(
                  'Tingkat ${controller.raporLetter}',
                  style: ZwsFonts.sans(
                    size: 24,
                    weight: FontWeight.w800,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('XP ', style: ZwsFonts.sans(size: 12, color: t.ink2)),
                    Mono(
                      '${controller.xp}',
                      size: 12,
                      weight: FontWeight.w700,
                      color: t.seal,
                    ),
                    Text(
                      ' · Peringkat ',
                      style: ZwsFonts.sans(size: 12, color: t.ink2),
                    ),
                    Text(
                      controller.myRank > 0 ? '#${controller.myRank}' : '—',
                      style: ZwsFonts.sans(
                        size: 12,
                        weight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  final Color fg;
  final Color bg;
  _RingPainter(this.pct, this.fg, this.bg);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = 11.0;
    final inner = rect.deflate(stroke / 2);
    final bgPaint = Paint()
      ..color = bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final fgPaint = Paint()
      ..color = fg
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(inner, 0, 2 * math.pi, false, bgPaint);
    canvas.drawArc(
      inner,
      -math.pi / 2,
      2 * math.pi * pct.clamp(0, 1),
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.pct != pct || old.fg != fg || old.bg != bg;
}

class _DueCard extends StatelessWidget {
  final AppController controller;
  final int due;
  const _DueCard({required this.controller, required this.due});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.seal,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'JATUH TEMPO HARI INI',
            style: ZwsFonts.sans(
              size: 11,
              weight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.82),
              letterSpacing: 1.7,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Mono(
                '$due',
                size: 40,
                weight: FontWeight.w800,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                'kartu',
                style: ZwsFonts.sans(
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              child: InkWell(
                onTap: controller.startReviewFromQueue,
                borderRadius: BorderRadius.circular(11),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'Mulai review',
                      style: ZwsFonts.sans(
                        size: 14,
                        weight: FontWeight.w700,
                        color: t.seal,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MateriCard extends StatelessWidget {
  final AppController controller;
  const _MateriCard({required this.controller});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    final mat = c.dailyMaterial;
    final hanzi = mat != null && mat.vocab.isNotEmpty
        ? mat.vocab.first.hanzi
        : (c.track == 'traditional' ? '喜歡' : '喜欢');
    final pinyin = mat != null && mat.vocab.isNotEmpty
        ? mat.vocab.first.pinyin
        : 'xǐhuan';
    final topic = mat?.topic ?? 'Kata kerja perasaan';
    final desc =
        mat?.exercise ??
        'Latihan hari ini: buat 3 kalimat. Guru akan menilai PR-mu.';
    return SurfaceBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: SectionLabel('Materi dari Guru · hari ini'),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (c.curriculumLoading) ...[
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Pill(mat != null ? 'AI' : 'HSK 2'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  Mono(pinyin, size: 10, color: t.ink3),
                  const SizedBox(height: 2),
                  Han(hanzi, size: 38, color: t.ink),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic,
                      style: ZwsFonts.sans(
                        size: 15,
                        weight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      desc,
                      style: ZwsFonts.sans(
                        size: 12,
                        color: t.ink2,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: t.surface2,
              borderRadius: BorderRadius.circular(11),
              child: InkWell(
                onTap: () => controller.go('chat'),
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: t.line),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Center(
                    child: Text(
                      'Buka di Guru →',
                      style: ZwsFonts.sans(
                        size: 13,
                        weight: FontWeight.w600,
                        color: t.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.line),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: t.ink2),
            const SizedBox(height: 7),
            Text(
              label,
              style: ZwsFonts.sans(
                size: 12,
                weight: FontWeight.w600,
                color: t.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  final AppController controller;
  const _LeaderboardCard({required this.controller});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return SurfaceBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionLabel('Leaderboard global'),
              InkWell(
                onTap: controller.openLeader,
                child: Text(
                  'Lihat semua →',
                  style: ZwsFonts.sans(
                    size: 12,
                    weight: FontWeight.w700,
                    color: t.seal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (controller.leaderRows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Belum ada peringkat. Mulai belajar untuk masuk papan ini.',
                style: ZwsFonts.sans(size: 12, color: t.ink3),
              ),
            ),
          for (final r in controller.leaderRows.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: r.you ? t.sealSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Mono(
                        '${r.rank}',
                        weight: FontWeight.w700,
                        color: r.you ? t.seal : (r.rank <= 3 ? t.gold : t.ink3),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ZwsFonts.sans(
                                size: 13,
                                weight: FontWeight.w600,
                                color: t.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Mono('· ${r.id}', size: 11, color: t.ink3),
                        ],
                      ),
                    ),
                    Mono(
                      '${r.score}',
                      size: 13,
                      weight: FontWeight.w700,
                      color: t.ink,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
