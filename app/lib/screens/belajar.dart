import 'package:flutter/material.dart';

import '../models/deck.dart';
import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../widgets/common.dart';
import '../widgets/ico.dart';

class BelajarScreen extends StatelessWidget {
  final AppController controller;
  final bool desktop;
  const BelajarScreen({super.key, required this.controller, required this.desktop});

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Continue review banner
        SurfaceBox(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                child: Icon(ZwsIcons.cards, color: t.seal, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lanjutkan review',
                        style: ZwsFonts.sans(
                            size: 14, weight: FontWeight.w700, color: t.ink)),
                    Text('${c.dueCount} kartu siap diulang',
                        style: ZwsFonts.sans(size: 12, color: t.ink2)),
                  ],
                ),
              ),
              Material(
                color: t.ink,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: c.startReviewFromQueue,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text('Mulai',
                        style: ZwsFonts.sans(
                            size: 13, weight: FontWeight.w700, color: t.bg)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionLabel('Deck kamu'),
            InkWell(
              onTap: c.openWrite,
              child: Text('+ Tulis kartu',
                  style: ZwsFonts.sans(
                      size: 12, weight: FontWeight.w700, color: t.seal)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DeckGrid(controller: c),
        const SizedBox(height: 16),
        const SectionLabel('Latihan'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ModeButton(
                icon: ZwsIcons.quiz,
                title: 'Mode Tes',
                sub: 'Pilihan ganda · self-check · ejaan',
                onTap: () => c.goTestPick(base: c.cards.keys.take(8).toList()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ModeButton(
                icon: ZwsIcons.game,
                title: 'Games',
                sub: 'Match · Tebak Nada · Speed',
                onTap: c.goGames,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const SectionLabel('Paket materi siap pakai'),
        const SizedBox(height: 10),
        _PackList(controller: c),
      ],
    );
  }
}

class _DeckGrid extends StatelessWidget {
  final AppController controller;
  const _DeckGrid({required this.controller});
  @override
  Widget build(BuildContext context) {
    final decks = controller.decks;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: decks.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 154,
      ),
      itemBuilder: (context, i) => _DeckCard(controller: controller, deck: decks[i]),
    );
  }
}

class _DeckCard extends StatelessWidget {
  final AppController controller;
  final Deck deck;
  const _DeckCard({required this.controller, required this.deck});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final now = DateTime.now();
    final total = deck.cardIds.length;
    final due = deck.cardIds.where((id) {
      final s = controller.srs[id];
      return s != null && (s.isNew || s.isDue(now));
    }).length;
    final mastered = total == 0
        ? 0
        : ((deck.cardIds
                    .where((id) => (controller.srs[id]?.mastery ?? 0) >= 2)
                    .length /
                total) *
            100)
            .round();
    return InkWell(
      onTap: () => controller.openDeckById(deck.id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Mono('№ ${deck.displayIdx}', size: 11, color: t.ink3, letterSpacing: 1),
                if (due > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                        color: t.seal, borderRadius: BorderRadius.circular(20)),
                    child: Text('$due due',
                        style: ZwsFonts.sans(
                            size: 11,
                            weight: FontWeight.w700,
                            color: Colors.white)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                        color: t.surface2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: t.line)),
                    child: Text('Selesai',
                        style: ZwsFonts.sans(
                            size: 11, weight: FontWeight.w600, color: t.ink3)),
                  ),
              ],
            ),
            const Spacer(),
            Text(deck.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ZwsFonts.sans(
                    size: 15, weight: FontWeight.w700, color: t.ink, height: 1.2)),
            const SizedBox(height: 2),
            Text('$total kartu · $mastered% dikuasai',
                style: ZwsFonts.sans(size: 12, color: t.ink3)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: mastered / 100,
                minHeight: 5,
                backgroundColor: t.line2,
                valueColor: AlwaysStoppedAnimation(t.seal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  const _ModeButton(
      {required this.icon,
      required this.title,
      required this.sub,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: t.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: t.seal),
                const SizedBox(width: 10),
                Text(title,
                    style: ZwsFonts.sans(
                        size: 14, weight: FontWeight.w700, color: t.ink)),
              ],
            ),
            const SizedBox(height: 8),
            Text(sub, style: ZwsFonts.sans(size: 11, color: t.ink3)),
          ],
        ),
      ),
    );
  }
}

class _PackList extends StatelessWidget {
  final AppController controller;
  const _PackList({required this.controller});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final packs = controller.packCatalog;
    if (packs.isEmpty) {
      return SurfaceBox(
        radius: 16,
        child: Text('Tidak ada paket tersedia.',
            style: ZwsFonts.sans(size: 13, color: t.ink3)),
      );
    }
    return SurfaceBox(
      radius: 16,
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        children: [
          for (var i = 0; i < packs.length; i++)
            Container(
              decoration: BoxDecoration(
                border: i < packs.length - 1
                    ? Border(bottom: BorderSide(color: t.line))
                    : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(packs[i].name,
                            style: ZwsFonts.sans(
                                size: 14,
                                weight: FontWeight.w700,
                                color: t.ink)),
                        Text(packs[i].meta,
                            style: ZwsFonts.sans(size: 11, color: t.ink3)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _PackButton(controller: controller, packIdx: i),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PackButton extends StatelessWidget {
  final AppController controller;
  final int packIdx;
  const _PackButton({required this.controller, required this.packIdx});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final pack = controller.packCatalog[packIdx];
    final installed = controller.isInstalled(pack.id);
    if (installed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: t.surface2,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: t.line),
        ),
        child: Text('Terunduh',
            style: ZwsFonts.sans(
                size: 12, weight: FontWeight.w700, color: t.ink3)),
      );
    }
    return Material(
      color: t.ink,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: () => controller.installPack(pack),
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Unduh',
              style:
                  ZwsFonts.sans(size: 12, weight: FontWeight.w700, color: t.bg)),
        ),
      ),
    );
  }
}
