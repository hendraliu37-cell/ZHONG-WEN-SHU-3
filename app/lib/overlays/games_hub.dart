import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../widgets/common.dart';

class GamesHubOverlay extends StatelessWidget {
  final AppController controller;
  final bool desktop;
  const GamesHubOverlay({
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
            onBack: c.closeSub,
            title: Center(
              child: Text(
                'Games',
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
              padding: const EdgeInsets.all(18),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CountStepper(
                        count: c.qCount,
                        limitLabel: c.questionLimitLabel,
                        onInc: c.incCount,
                        onDec: c.decCount,
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 11,
                        crossAxisSpacing: 11,
                        childAspectRatio: 1.35,
                        children: [
                          _GameCard(
                            han: '声',
                            title: 'Tebak Nada',
                            sub: 'Dengar & pilih nada 1–4',
                            onTap: c.startTone,
                          ),
                          _GameCard(
                            han: '配',
                            title: 'Match',
                            sub: 'Pasangkan 汉字 ↔ arti',
                            onTap: c.startMatch,
                          ),
                          _GameCard(
                            han: '听',
                            title: 'Listening Quiz',
                            sub: 'Dengar audio → jawab',
                            onTap: c.goListen,
                          ),
                          _GameCard(
                            han: '速',
                            title: 'Speed Recall',
                            sub: 'Kebut kartu lawan waktu',
                            onTap: c.startSpeed,
                          ),
                        ],
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

class _GameCard extends StatelessWidget {
  final String han;
  final String title;
  final String sub;
  final VoidCallback onTap;
  const _GameCard({
    required this.han,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Han(han, size: 30, color: t.seal),
            const SizedBox(height: 8),
            Text(
              title,
              style: ZwsFonts.sans(
                size: 14,
                weight: FontWeight.w700,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: ZwsFonts.sans(size: 11, color: t.ink3),
            ),
          ],
        ),
      ),
    );
  }
}
