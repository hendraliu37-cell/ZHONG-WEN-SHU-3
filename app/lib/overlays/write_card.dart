import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../widgets/common.dart';

class WriteCardOverlay extends StatefulWidget {
  final AppController controller;
  final bool desktop;
  const WriteCardOverlay({
    super.key,
    required this.controller,
    required this.desktop,
  });

  @override
  State<WriteCardOverlay> createState() => _WriteCardOverlayState();
}

class _WriteCardOverlayState extends State<WriteCardOverlay> {
  final _han = TextEditingController();
  final _py = TextEditingController();
  final _m = TextEditingController();

  @override
  void dispose() {
    _han.dispose();
    _py.dispose();
    _m.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = widget.controller;
    return Container(
      color: t.bg,
      child: Column(
        children: [
          OverlayBar(
            desktop: widget.desktop,
            onBack: c.closeWrite,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tulis kartu baru',
                  style: ZwsFonts.sans(
                    size: 15,
                    weight: FontWeight.w800,
                    color: t.ink,
                  ),
                ),
                Text(
                  'Buat kartu & pilih deck',
                  style: ZwsFonts.sans(size: 11, color: t.ink3),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionLabel('Simpan ke deck'),
                      const SizedBox(height: 10),
                      _DeckPicker(controller: c),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: t.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'DETAIL KARTU',
                              style: ZwsFonts.sans(
                                size: 11,
                                weight: FontWeight.w700,
                                color: t.seal,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _Field(controller: _han, hint: '汉字 / 漢字'),
                            const SizedBox(height: 10),
                            _Field(
                              controller: _py,
                              hint: 'pinyin (cth. nǐ hǎo)',
                            ),
                            const SizedBox(height: 10),
                            _Field(
                              controller: _m,
                              hint: 'arti, bisa banyak: halo / apa kabar',
                            ),
                            const SizedBox(height: 12),
                            Material(
                              color: t.seal,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () {
                                  c.saveWrite(_han.text, _py.text, _m.text);
                                  _han.clear();
                                  _py.clear();
                                  _m.clear();
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Simpan kartu',
                                      style: ZwsFonts.sans(
                                        size: 14,
                                        weight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (c.writeMsg.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: t.sealSoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: t.seal),
                          ),
                          child: Text(
                            c.writeMsg,
                            textAlign: TextAlign.center,
                            style: ZwsFonts.sans(
                              size: 13,
                              weight: FontWeight.w700,
                              color: t.seal,
                            ),
                          ),
                        ),
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

class _DeckPicker extends StatelessWidget {
  final AppController controller;
  const _DeckPicker({required this.controller});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: c.decks.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 50,
      ),
      itemBuilder: (context, i) {
        final on = c.writeDeck == i;
        return InkWell(
          onTap: () => c.setWriteDeck(i),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: on ? t.sealSoft : t.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? t.seal : t.line),
            ),
            child: Text(
              c.decks[i].name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ZwsFonts.sans(
                size: 13,
                weight: FontWeight.w700,
                color: on ? t.seal : t.ink2,
                height: 1.2,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _Field({required this.controller, required this.hint});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: t.line),
      ),
      child: TextField(
        controller: controller,
        style: ZwsFonts.sans(size: 14, color: t.ink),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: ZwsFonts.sans(size: 14, color: t.ink3),
        ),
      ),
    );
  }
}
