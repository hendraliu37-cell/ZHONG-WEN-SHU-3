import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../widgets/common.dart';
import '../widgets/ico.dart';

class TestPickerOverlay extends StatelessWidget {
  final AppController controller;
  final bool desktop;
  const TestPickerOverlay({
    super.key,
    required this.controller,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    final sub = c.openDeck?.name ?? '${c.baseCards.length} kata';
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
                  'Pilih mode tes',
                  style: ZwsFonts.sans(
                    size: 15,
                    weight: FontWeight.w800,
                    color: t.ink,
                  ),
                ),
                Text(sub, style: ZwsFonts.sans(size: 11, color: t.ink3)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Direction toggle
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: t.surface2,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _DirSeg(
                                label: '中文 → Indo',
                                active: c.testDirection == 'zh2id',
                                onTap: () => c.testDirection != 'zh2id'
                                    ? c.toggleTestDirection()
                                    : null,
                              ),
                            ),
                            Expanded(
                              child: _DirSeg(
                                label: 'Indo → 中文',
                                active: c.testDirection == 'id2zh',
                                onTap: () => c.testDirection != 'id2zh'
                                    ? c.toggleTestDirection()
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      CountStepper(
                        count: c.qCount,
                        limitLabel: c.questionLimitLabel,
                        onInc: c.incCount,
                        onDec: c.decCount,
                      ),
                      if (c.testHistory.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _HistoryCard(controller: c),
                      ],
                      const SizedBox(height: 12),
                      _PickCard(
                        icon: ZwsIcons.quiz,
                        title: 'Pilihan Ganda',
                        sub: 'Pilih arti yang benar dari 4 opsi',
                        onTap: c.startMc,
                      ),
                      const SizedBox(height: 12),
                      _PickCard(
                        icon: ZwsIcons.cards,
                        title: 'Self-check',
                        sub: 'Balik kartu, nilai sendiri benar / salah',
                        onTap: c.startSelf,
                      ),
                      const SizedBox(height: 12),
                      _PickCard(
                        icon: ZwsIcons.spell,
                        title: 'Tes Ejaan',
                        sub: 'Ketik pinyin dari kata yang muncul',
                        onTap: c.startSpell,
                      ),
                    ],
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

class _HistoryCard extends StatelessWidget {
  final AppController controller;
  const _HistoryCard({required this.controller});

  String _modeLabel(String mode) => switch (mode) {
    'self' => 'Self-check',
    'spell' => 'Ejaan',
    _ => 'Pilihan Ganda',
  };

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final items = controller.testHistory.take(6).toList();
    return SurfaceBox(
      radius: 16,
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                const Expanded(child: SectionLabel('Riwayat tes')),
                Mono(
                  '${controller.testHistory.length}',
                  size: 11,
                  color: t.ink3,
                ),
              ],
            ),
          ),
          for (var i = 0; i < items.length; i++)
            _HistoryRow(
              controller: controller,
              item: items[i],
              modeLabel: _modeLabel(items[i].mode),
              last: i == items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final AppController controller;
  final TestHistoryItem item;
  final String modeLabel;
  final bool last;
  const _HistoryRow({
    required this.controller,
    required this.item,
    required this.modeLabel,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final done = item.completed;
    final progress = item.total == 0 ? 0.0 : item.shownIndex / item.total;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: t.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZwsFonts.sans(
                    size: 13,
                    weight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$modeLabel · ${done ? 'selesai' : 'belum selesai'} · '
                  '${item.shownIndex}/${item.total} · skor ${item.score}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZwsFonts.sans(size: 11, color: t.ink3),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1),
                    minHeight: 4,
                    backgroundColor: t.line2,
                    valueColor: AlwaysStoppedAnimation(done ? t.green : t.seal),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (!done)
            Material(
              color: t.ink,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                onTap: () => controller.resumeTestHistory(item),
                borderRadius: BorderRadius.circular(9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    'Lanjut',
                    style: ZwsFonts.sans(
                      size: 12,
                      weight: FontWeight.w700,
                      color: t.bg,
                    ),
                  ),
                ),
              ),
            )
          else
            Mono('${item.pct}%', size: 12, color: t.ink3),
        ],
      ),
    );
  }
}

class _PickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  const _PickCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.line),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.sealSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: t.seal, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ZwsFonts.sans(
                      size: 15,
                      weight: FontWeight.w700,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(sub, style: ZwsFonts.sans(size: 12, color: t.ink3)),
                ],
              ),
            ),
            Icon(ZwsIcons.chevron, color: t.ink3, size: 20),
          ],
        ),
      ),
    );
  }
}

class _DirSeg extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _DirSeg({required this.label, required this.active, this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? t.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: ZwsFonts.sans(
            size: 12,
            weight: FontWeight.w700,
            color: active ? t.ink : t.ink3,
          ),
        ),
      ),
    );
  }
}
