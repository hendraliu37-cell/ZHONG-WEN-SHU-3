import 'package:flutter/material.dart';

import '../data/seed.dart';
import '../models/vocab.dart';
import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../widgets/common.dart';
import '../widgets/ico.dart';

class DeckDetailOverlay extends StatelessWidget {
  final AppController controller;
  final bool desktop;
  const DeckDetailOverlay({
    super.key,
    required this.controller,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    final deck = c.openDeck;
    if (deck == null) return const SizedBox.shrink();
    return Container(
      color: t.bg,
      child: Column(
        children: [
          OverlayBar(
            desktop: desktop,
            onBack: c.closeSub,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  deck.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZwsFonts.sans(
                    size: 15,
                    weight: FontWeight.w800,
                    color: t.ink,
                  ),
                ),
                Text(
                  '${deck.cardIds.length} kartu di daftar',
                  style: ZwsFonts.sans(size: 11, color: t.ink3),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ActionBtn(
                              label: 'Review',
                              icon: ZwsIcons.cards,
                              filled: false,
                              onTap: c.deckReview,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionBtn(
                              label: 'Tes deck',
                              icon: ZwsIcons.quiz,
                              filled: true,
                              onTap: c.deckTest,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionBtn(
                              label: 'Import',
                              icon: ZwsIcons.download,
                              filled: false,
                              onTap: c.importIntoOpenDeck,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionBtn(
                              label: 'Export CSV',
                              icon: ZwsIcons.upload,
                              filled: false,
                              onTap: () => c.exportOpenDeck(excel: false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionBtn(
                              label: 'Excel',
                              icon: ZwsIcons.table,
                              filled: false,
                              onTap: () => c.exportOpenDeck(excel: true),
                            ),
                          ),
                        ],
                      ),
                      if (c.deckIoMsg.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SurfaceBox(
                          radius: 12,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          background: t.surface2,
                          child: Text(
                            c.deckIoMsg,
                            style: ZwsFonts.sans(size: 12, color: t.ink2),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _Legend(),
                      const SizedBox(height: 12),
                      _CardList(controller: c, deckCardIds: deck.cardIds),
                      const SizedBox(height: 14),
                      if (!c.adding)
                        InkWell(
                          onTap: () => c.setAdding(true),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: t.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: t.line,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '+ Tambah kartu ke deck',
                                style: ZwsFonts.sans(
                                  size: 14,
                                  weight: FontWeight.w700,
                                  color: t.seal,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        _AddForm(controller: c),
                      const SizedBox(height: 22),
                      _DeleteDeckButton(
                        controller: c,
                        deckId: deck.id,
                        deckName: deck.name,
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

class _DeleteDeckButton extends StatelessWidget {
  final AppController controller;
  final String deckId;
  final String deckName;
  const _DeleteDeckButton({
    required this.controller,
    required this.deckId,
    required this.deckName,
  });

  Future<void> _confirm(BuildContext context) async {
    final t = ZwsTheme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        title: Text(
          'Hapus deck?',
          style: ZwsFonts.sans(size: 16, weight: FontWeight.w800, color: t.ink),
        ),
        content: Text(
          'Deck "$deckName" akan dihapus dari daftarmu. Tindakan ini tidak bisa dibatalkan.',
          style: ZwsFonts.sans(size: 13, color: t.ink2, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: ZwsFonts.sans(size: 13, color: t.ink2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Hapus',
              style: ZwsFonts.sans(
                size: 13,
                weight: FontWeight.w700,
                color: t.seal,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true) controller.deleteDeck(deckId);
  }

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return InkWell(
      onTap: () => _confirm(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.seal.withValues(alpha: 0.5)),
        ),
        child: Text(
          'Hapus deck',
          style: ZwsFonts.sans(
            size: 13,
            weight: FontWeight.w700,
            color: t.seal,
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Material(
      color: filled ? t.seal : t.surface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: filled ? null : Border.all(color: t.line),
          ),
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: filled ? Colors.white : t.seal),
              const SizedBox(width: 8),
              Text(
                label,
                style: ZwsFonts.sans(
                  size: 14,
                  weight: FontWeight.w700,
                  color: filled ? Colors.white : t.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const SectionLabel('Penguasaan'),
        for (final l in masteryLevels)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: Color(l.color),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(l.label, style: ZwsFonts.sans(size: 11, color: t.ink2)),
            ],
          ),
      ],
    );
  }
}

class _CardList extends StatefulWidget {
  final AppController controller;
  final List<int> deckCardIds;
  const _CardList({required this.controller, required this.deckCardIds});

  @override
  State<_CardList> createState() => _CardListState();
}

class _CardListState extends State<_CardList> {
  int? expandedId;

  @override
  Widget build(BuildContext context) {
    return SurfaceBox(
      radius: 16,
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        children: [
          for (var i = 0; i < widget.deckCardIds.length; i++)
            _CardRow(
              controller: widget.controller,
              cardId: widget.deckCardIds[i],
              expanded: expandedId == widget.deckCardIds[i],
              last: i == widget.deckCardIds.length - 1,
              onToggle: () {
                setState(() {
                  expandedId = expandedId == widget.deckCardIds[i]
                      ? null
                      : widget.deckCardIds[i];
                });
              },
            ),
        ],
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  final AppController controller;
  final int cardId;
  final bool expanded;
  final bool last;
  final VoidCallback onToggle;
  const _CardRow({
    required this.controller,
    required this.cardId,
    required this.expanded,
    required this.last,
    required this.onToggle,
  });
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller.card(cardId);
    final mastery = controller.srs[cardId]?.mastery ?? 0;
    final lvl = masteryLevels[mastery];
    final color = Color(lvl.color);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color, width: 3),
          bottom: last ? BorderSide.none : BorderSide(color: t.line),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              child: Row(
                children: [
                  _VoiceButton(
                    onTap: () => controller.speech.speak(
                      controller.primaryHanzi(c),
                      traditional: controller.usesTraditionalHanzi,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Han(
                    controller.primaryHanzi(c),
                    size: 30,
                    color: t.ink,
                    height: 1,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Mono(c.pinyin, size: 11, color: t.ink3),
                        Text(
                          c.primaryMeaning,
                          style: ZwsFonts.sans(size: 13, color: t.ink2),
                        ),
                        if (c.alternativeMeanings.isNotEmpty)
                          Text(
                            c.alternativeMeanings.join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ZwsFonts.sans(size: 11, color: t.ink3),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    lvl.label,
                    style: ZwsFonts.sans(
                      size: 11,
                      weight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: t.ink3,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: expanded
                ? _InlineCardDetail(
                    controller: controller,
                    card: c,
                    level: lvl.label,
                    levelColor: color,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _InlineCardDetail extends StatelessWidget {
  final AppController controller;
  final VocabEntry card;
  final String level;
  final Color levelColor;
  const _InlineCardDetail({
    required this.controller,
    required this.card,
    required this.level,
    required this.levelColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final hanzi = controller.primaryHanzi(card);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(58, 0, 12, 12),
      color: t.surface2.withValues(alpha: 0.72),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _VoiceButton(
                  compact: true,
                  onTap: () => controller.speech.speak(
                    hanzi,
                    traditional: controller.usesTraditionalHanzi,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    card.meanings.join(' / '),
                    style: ZwsFonts.sans(size: 13, color: t.ink, height: 1.35),
                  ),
                ),
              ],
            ),
            if (card.exampleS.isNotEmpty || card.exampleId.isNotEmpty) ...[
              const SizedBox(height: 9),
              if (card.exampleS.isNotEmpty)
                Han(card.exampleS, size: 17, color: t.ink, height: 1.32),
              if (card.exampleId.isNotEmpty)
                Text(
                  card.exampleId,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ZwsFonts.sans(size: 12, color: t.ink2, height: 1.35),
                ),
            ],
            const SizedBox(height: 9),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Pill(
                  level,
                  fg: levelColor,
                  bg: levelColor.withValues(alpha: 0.12),
                ),
                if (card.hskLevel != null) Pill('HSK ${card.hskLevel}'),
                if (card.tocflLevel != null) Pill('TOCFL ${card.tocflLevel}'),
                Pill('Nada ${card.tone}'),
                if (card.zhuyin.isNotEmpty)
                  Pill(card.zhuyin, fg: t.ink2, bg: t.surface2),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;
  const _VoiceButton({required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Material(
      color: t.sealSoft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: compact ? 30 : 36,
          height: compact ? 30 : 36,
          child: Icon(ZwsIcons.sound, size: compact ? 16 : 18, color: t.seal),
        ),
      ),
    );
  }
}

class _AddForm extends StatefulWidget {
  final AppController controller;
  const _AddForm({required this.controller});
  @override
  State<_AddForm> createState() => _AddFormState();
}

class _AddFormState extends State<_AddForm> {
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.seal),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'KARTU BARU',
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
          _Field(controller: _py, hint: 'pinyin (cth. nǐ hǎo)'),
          const SizedBox(height: 10),
          _Field(controller: _m, hint: 'arti, bisa banyak: halo / apa kabar'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: t.surface2,
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    onTap: () => widget.controller.setAdding(false),
                    borderRadius: BorderRadius.circular(11),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: t.line),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          'Batal',
                          style: ZwsFonts.sans(
                            size: 13,
                            weight: FontWeight.w700,
                            color: t.ink2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                flex: 2,
                child: Material(
                  color: t.seal,
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    onTap: () {
                      widget.controller.saveCardToOpenDeck(
                        _han.text,
                        _py.text,
                        _m.text,
                      );
                      _han.clear();
                      _py.clear();
                      _m.clear();
                    },
                    borderRadius: BorderRadius.circular(11),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          'Simpan kartu',
                          style: ZwsFonts.sans(
                            size: 13,
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
        ],
      ),
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
