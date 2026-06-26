import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../widgets/common.dart';

class MatchGameOverlay extends StatelessWidget {
  final AppController controller;
  final bool desktop;
  const MatchGameOverlay(
      {super.key, required this.controller, required this.desktop});

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    final pairs = c.matchPairs.length;
    final done = c.matchMatched.length;
    final finished = pairs > 0 && done >= pairs;
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
                Text('Match · 配对',
                    style: ZwsFonts.sans(
                        size: 15, weight: FontWeight.w800, color: t.ink)),
                Mono('$done / $pairs pasangan', size: 11, color: t.ink3),
              ],
            ),
          ),
          Expanded(
            child: finished
                ? _Finish(controller: c)
                : _Board(controller: c),
          ),
        ],
      ),
    );
  }
}

class _Board extends StatelessWidget {
  final AppController controller;
  const _Board({required this.controller});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            children: [
              Text('Ketuk 汉字 lalu artinya yang cocok',
                  style: ZwsFonts.sans(size: 12, color: t.ink3)),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: c.matchTiles.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 66,
                ),
                itemBuilder: (context, i) {
                  final tile = c.matchTiles[i];
                  final matched = c.matchMatched.contains(tile.pid);
                  final sel = c.matchSel == i;
                  final wrong = c.matchWrong.contains(i);
                  Color border = t.line, bg = t.surface, fg = t.ink;
                  double opacity = 1;
                  if (matched) {
                    border = t.green;
                    bg = t.correctTint;
                    fg = t.green;
                    opacity = 0.5;
                  } else if (sel || wrong) {
                    border = t.seal;
                    bg = t.sealSoft;
                    fg = t.seal;
                  }
                  final isHan = tile.kind == 'han';
                  return Opacity(
                    opacity: opacity,
                    child: InkWell(
                      onTap: matched ? null : () => c.matchTap(i),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border),
                        ),
                        child: isHan
                            ? Han(tile.label, size: 26, color: fg)
                            : Text(tile.label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: ZwsFonts.sans(
                                    size: 14,
                                    weight: FontWeight.w700,
                                    color: fg)),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 550),
            curve: Curves.elasticOut,
            builder: (context, v, child) =>
                Transform.scale(scale: v, child: child),
            child: Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.seal,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Han('配', size: 48, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          Text('Semua cocok!',
              style: ZwsFonts.sans(
                  size: 22, weight: FontWeight.w800, color: t.ink)),
          const SizedBox(height: 6),
          Text('${c.matchMoves} percobaan · ${c.matchPairs.length} pasangan',
              style: ZwsFonts.sans(size: 13, color: t.ink2)),
          const SizedBox(height: 22),
          Material(
            color: t.ink,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: c.startMatch,
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
