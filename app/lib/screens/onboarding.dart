import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../widgets/common.dart';

class OnboardingScreen extends StatelessWidget {
  final AppController controller;
  const OnboardingScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Container(
      color: t.bg,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(34),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SealMark(size: 62, fontSize: 38, radius: 16),
                const SizedBox(height: 26),
                Han('中文书', size: 30, color: t.ink, letterSpacing: 1.8),
                const SizedBox(height: 6),
                Text('ZHONGWEN SHU',
                    style: ZwsFonts.sans(
                        size: 13,
                        weight: FontWeight.w600,
                        color: t.ink2,
                        letterSpacing: 2.8)),
                const SizedBox(height: 18),
                Text(
                  'Pilih jalur belajarmu. Setiap kata disimpan dalam 简 · 繁 · 拼音 · 注音.',
                  textAlign: TextAlign.center,
                  style: ZwsFonts.sans(size: 14, color: t.ink2, height: 1.55),
                ),
                const SizedBox(height: 24),
                _TrackOption(
                  controller: controller,
                  value: 'simplified',
                  han: '简',
                  title: 'Mandarin Daratan',
                  sub: 'HSK · 简体 · 拼音 pinyin',
                ),
                const SizedBox(height: 10),
                _TrackOption(
                  controller: controller,
                  value: 'traditional',
                  han: '繁',
                  title: 'Mandarin Taiwan',
                  sub: 'TOCFL · 繁體 · 注音 zhuyin',
                ),
                const SizedBox(height: 10),
                _TrackOption(
                  controller: controller,
                  value: 'both',
                  han: '简繁',
                  title: 'Dua-duanya',
                  sub: 'Belajar simplified & traditional',
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: t.ink,
                    borderRadius: BorderRadius.circular(13),
                    child: InkWell(
                      onTap: controller.finishOnboard,
                      borderRadius: BorderRadius.circular(13),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Center(
                          child: Text('Masuk',
                              style: ZwsFonts.sans(
                                  size: 15,
                                  weight: FontWeight.w700,
                                  color: t.bg)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackOption extends StatelessWidget {
  final AppController controller;
  final String value;
  final String han;
  final String title;
  final String sub;
  const _TrackOption({
    required this.controller,
    required this.value,
    required this.han,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final on = controller.track == value;
    return InkWell(
      onTap: () => controller.setTrack(value),
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: on ? t.sealSoft : t.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: on ? t.seal : t.line),
        ),
        child: Row(
          children: [
            Han(han, size: 24, color: on ? t.seal : t.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: ZwsFonts.sans(
                          size: 14,
                          weight: FontWeight.w700,
                          color: on ? t.seal : t.ink,
                          height: 1.25)),
                  Text(sub,
                      style: ZwsFonts.sans(
                          size: 11,
                          color: (on ? t.seal : t.ink).withValues(alpha: 0.7),
                          height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
