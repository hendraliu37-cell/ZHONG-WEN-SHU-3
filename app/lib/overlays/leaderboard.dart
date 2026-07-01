import 'package:flutter/material.dart';

import '../data/leaderboard.dart';
import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../widgets/common.dart';

class LeaderboardOverlay extends StatelessWidget {
  final AppController controller;
  final bool desktop;
  const LeaderboardOverlay({
    super.key,
    required this.controller,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    return Container(
      color: t.bg,
      child: Column(
        children: [
          OverlayBar(
            desktop: desktop,
            onBack: () => c.closeLeader(),
            title: Center(
              child: Text(
                'Leaderboard global',
                style: ZwsFonts.sans(
                  size: 15,
                  weight: FontWeight.w800,
                  color: t.ink,
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      if (c.leaderRows.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Text(
                            'Papan peringkat masih kosong.\nBelajar & kumpulkan XP untuk muncul di sini.',
                            textAlign: TextAlign.center,
                            style: ZwsFonts.sans(
                              size: 13,
                              color: t.ink3,
                              height: 1.5,
                            ),
                          ),
                        ),
                      for (final r in c.leaderRows) ...[
                        _Row(row: r),
                        const SizedBox(height: 8),
                      ],
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

class _Row extends StatelessWidget {
  final LeaderRow row;
  const _Row({required this.row});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final rankColor = row.you ? t.seal : (row.rank <= 3 ? t.gold : t.ink3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: row.you ? t.sealSoft : t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: row.you ? t.seal : t.line),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Mono(
              '${row.rank}',
              size: 15,
              weight: FontWeight.w700,
              color: rankColor,
            ),
          ),
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.sealSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Han(row.initial, size: 18, color: t.seal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: ZwsFonts.sans(
                    size: 14,
                    weight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
                Mono(row.id, size: 11, color: t.ink3),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Mono(
                '${row.score}',
                size: 16,
                weight: FontWeight.w700,
                color: t.ink,
              ),
              Text(
                'Tier ${row.tier}',
                style: ZwsFonts.sans(size: 10, color: t.ink3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
