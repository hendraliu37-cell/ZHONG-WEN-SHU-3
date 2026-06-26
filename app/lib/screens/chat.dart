import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import 'grup.dart';
import 'guru.dart';

/// Merged "Chat" tab: the AI tutor (Guru — private chat + voice/tone tuner) and
/// the study group, switchable with a top segmented control. Each sub-screen
/// keeps its own internal layout unchanged.
class ChatScreen extends StatelessWidget {
  final AppController controller;
  final bool desktop;
  const ChatScreen({super.key, required this.controller, required this.desktop});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _Switch(controller: c),
        ),
        const SizedBox(height: 14),
        if (c.chatTab == 'grup')
          Expanded(child: GrupScreen(controller: c, desktop: desktop))
        else
          Expanded(child: GuruScreen(controller: c, desktop: desktop)),
      ],
    );
  }
}

class _Switch extends StatelessWidget {
  final AppController controller;
  const _Switch({required this.controller});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Seg(controller: controller, value: 'ai', label: 'AI (Guru)'),
          _Seg(controller: controller, value: 'grup', label: 'Grup'),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  final AppController controller;
  final String value;
  final String label;
  const _Seg(
      {required this.controller, required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final on = controller.chatTab == value;
    return InkWell(
      onTap: () => controller.setChatTab(value),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: on ? t.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(label,
            style: ZwsFonts.sans(
                size: 13,
                weight: FontWeight.w700,
                color: on ? t.ink : t.ink3)),
      ),
    );
  }
}
