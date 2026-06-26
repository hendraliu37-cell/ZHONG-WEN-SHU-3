import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../utils/test_exit_guard.dart';
import '../widgets/common.dart';
import '../widgets/ico.dart';

class SpellOverlay extends StatelessWidget {
  final AppController controller;
  final bool desktop;
  const SpellOverlay({
    super.key,
    required this.controller,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    final total = c.sessionCards.length;
    final finished = c.spellIdx >= total;
    final shown = (c.spellIdx + 1).clamp(1, total);
    return Container(
      color: t.bg,
      child: Column(
        children: [
          OverlayBar(
            desktop: desktop,
            onBack: () => closeSubWithTestGuard(context, c),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tes Ejaan',
                  style: ZwsFonts.sans(
                    size: 15,
                    weight: FontWeight.w800,
                    color: t.ink,
                  ),
                ),
                Mono(
                  '$shown / $total · skor ${c.spellScore}',
                  size: 11,
                  color: t.ink3,
                ),
              ],
            ),
          ),
          ThinProgress(total == 0 ? 0 : c.spellIdx / total),
          Expanded(
            child: finished
                ? _Finish(controller: c, total: total)
                : _Active(controller: c, key: ValueKey(c.spellIdx)),
          ),
        ],
      ),
    );
  }
}

class _Active extends StatefulWidget {
  final AppController controller;
  const _Active({required this.controller, super.key});
  @override
  State<_Active> createState() => _ActiveState();
}

class _ActiveState extends State<_Active> {
  final _tec = TextEditingController();

  @override
  void dispose() {
    _tec.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tec.text = widget.controller.spellInput;
  }

  void _check() {
    widget.controller.setSpellInput(_tec.text);
    widget.controller.checkSpell();
  }

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = widget.controller;
    final card = c.card(c.spellCardId);
    final checked = c.spellChecked;
    final borderColor = checked ? (c.spellCorrect ? t.green : t.seal) : t.line;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            'Ketik pinyin untuk kata ini',
            style: ZwsFonts.sans(size: 12, color: t.ink3),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Han(c.primaryHanzi(card), size: 72, color: t.ink, height: 1.05),
              const SizedBox(width: 12),
              InkWell(
                onTap: () => c.speech.speak(
                  c.primaryHanzi(card),
                  traditional: c.track == 'traditional',
                ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: t.surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: t.line),
                  ),
                  child: Icon(ZwsIcons.sound, size: 18, color: t.seal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            card.meaningPreview,
            textAlign: TextAlign.center,
            style: ZwsFonts.sans(size: 13, color: t.ink2),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Container(
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: borderColor, width: 2),
              ),
              child: TextField(
                controller: _tec,
                enabled: !checked,
                textAlign: TextAlign.center,
                onChanged: c.setSpellInput,
                onSubmitted: (_) => checked ? c.nextSpell() : _check(),
                style: ZwsFonts.mono(
                  size: 17,
                  color: t.ink,
                  letterSpacing: 0.5,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  border: InputBorder.none,
                  hintText: 'pinyin, hanzi, atau arti',
                  hintStyle: ZwsFonts.mono(size: 17, color: t.ink3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: checked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: c.spellCorrect ? t.correctTint : t.sealSoft,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: c.spellCorrect ? t.green : t.seal,
                          ),
                        ),
                        child: Text(
                          c.spellCorrect
                              ? 'Benar! ${card.pinyin}'
                              : 'Jawaban: ${card.pinyin}',
                          textAlign: TextAlign.center,
                          style: ZwsFonts.sans(
                            size: 14,
                            weight: FontWeight.w700,
                            color: c.spellCorrect ? t.green : t.seal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkButton(
                        label: c.spellIdx >= c.sessionCards.length - 1
                            ? 'Lihat hasil'
                            : 'Lanjut',
                        onTap: c.nextSpell,
                      ),
                    ],
                  )
                : Material(
                    color: t.seal,
                    borderRadius: BorderRadius.circular(13),
                    child: InkWell(
                      onTap: _check,
                      borderRadius: BorderRadius.circular(13),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Text(
                            'Periksa',
                            style: ZwsFonts.sans(
                              size: 15,
                              weight: FontWeight.w700,
                              color: Colors.white,
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

class _Finish extends StatelessWidget {
  final AppController controller;
  final int total;
  const _Finish({required this.controller, required this.total});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    final verdict = c.spellScore >= total - 1 ? 'Hebat!' : 'Terus berlatih';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Mono(
                '${c.spellScore}',
                size: 64,
                weight: FontWeight.w700,
                color: t.seal,
              ),
              Mono('/$total', size: 24, color: t.ink3),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            verdict,
            style: ZwsFonts.sans(
              size: 22,
              weight: FontWeight.w800,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniBtn(label: 'Ulang', filled: false, onTap: c.restartSpell),
              const SizedBox(width: 10),
              _MiniBtn(label: 'Selesai', filled: true, onTap: c.closeSub),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _MiniBtn({
    required this.label,
    required this.filled,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Material(
      color: filled ? t.ink : t.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: filled ? null : Border.all(color: t.line),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          child: Text(
            label,
            style: ZwsFonts.sans(
              size: 14,
              weight: FontWeight.w700,
              color: filled ? t.bg : t.ink,
            ),
          ),
        ),
      ),
    );
  }
}
