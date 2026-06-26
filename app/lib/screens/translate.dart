import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/translation_service.dart';
import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../widgets/common.dart';
import '../widgets/ico.dart';

/// Realtime translator (text · voice · photo), Google-Translate style. Engine is
/// the `translate` Edge Function (LLM); the local dictionary enriches the
/// per-word breakdown. zh ⇄ id, with voice input (STT) and photo input (OCR).
class TranslateScreen extends StatefulWidget {
  final AppController controller;
  final bool desktop;
  const TranslateScreen({
    super.key,
    required this.controller,
    required this.desktop,
  });

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final _tc = TextEditingController();

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  static String _langName(String code) => code == 'zh' ? '中文' : 'Indonesia';

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = widget.controller;

    // Keep the field in sync when the source changes externally (voice / photo
    // / swap / clear) without clobbering the cursor while the user is typing.
    if (_tc.text != c.trSource) {
      _tc.value = TextEditingValue(
        text: c.trSource,
        selection: TextSelection.collapsed(offset: c.trSource.length),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LangBar(controller: c),
        const SizedBox(height: 10),
        _EngineToggle(controller: c),
        const SizedBox(height: 12),
        _SourceCard(controller: c, field: _tc),
        const SizedBox(height: 12),
        _ResultCard(controller: c),
        if (c.trHistory.isNotEmpty) ...[
          const SizedBox(height: 12),
          _HistoryCard(controller: c),
        ],
        const SizedBox(height: 14),
        Text(
          c.trEngine == 'ai'
              ? 'AI aktif: terjemahan akurat (butuh internet).'
              : 'AI mati: terjemahan dari kamus (offline, cepat).',
          style: ZwsFonts.sans(size: 11, color: t.ink3, height: 1.5),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final AppController controller;
  const _HistoryCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final items = controller.trHistory.take(8).toList();
    return SurfaceBox(
      background: t.surface2,
      padding: const EdgeInsets.all(14),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SectionLabel('Riwayat'),
              const Spacer(),
              InkWell(
                onTap: controller.trClearHistory,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  child: Text(
                    'Hapus',
                    style: ZwsFonts.sans(
                      size: 11,
                      weight: FontWeight.w700,
                      color: t.ink3,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in items)
            _HistoryRow(controller: controller, item: item),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final AppController controller;
  final TranslateHistoryItem item;
  const _HistoryRow({required this.controller, required this.item});

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final toZh = item.to == 'zh';
    return InkWell(
      onTap: () => controller.trUseHistory(item),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Text(
              '${_TranslateScreenState._langName(item.from)} → ${_TranslateScreenState._langName(item.to)}',
              style: ZwsFonts.sans(
                size: 10,
                weight: FontWeight.w700,
                color: t.ink3,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.source,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ZwsFonts.sans(size: 12, color: t.ink2),
                  ),
                  Text(
                    item.translation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: toZh
                        ? ZwsFonts.han(size: 17, color: t.ink)
                        : ZwsFonts.sans(
                            size: 13,
                            weight: FontWeight.w700,
                            color: t.ink,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row with label + Switch: "Terjemah AI" on/off.
class _EngineToggle extends StatelessWidget {
  final AppController controller;
  const _EngineToggle({required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    return SurfaceBox(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Icon(ZwsIcons.translate, size: 18, color: t.ink2),
          const SizedBox(width: 10),
          Text(
            'Terjemah AI',
            style: ZwsFonts.sans(
              size: 14,
              weight: FontWeight.w600,
              color: t.ink,
            ),
          ),
          const Spacer(),
          Switch(
            value: c.trEngine == 'ai',
            onChanged: (v) => c.trSetEngine(v ? 'ai' : 'dict'),
            activeThumbColor: t.seal,
          ),
        ],
      ),
    );
  }
}

class _LangBar extends StatelessWidget {
  final AppController controller;
  const _LangBar({required this.controller});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    Widget side(String code) => Expanded(
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Text(
          _TranslateScreenState._langName(code),
          style: ZwsFonts.sans(size: 14, weight: FontWeight.w700, color: t.ink),
        ),
      ),
    );
    return SurfaceBox(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      radius: 14,
      child: Row(
        children: [
          side(c.trFrom),
          Material(
            color: t.sealSoft,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: c.trSwap,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(ZwsIcons.swap, size: 20),
              ),
            ),
          ),
          side(c.trTo),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final AppController controller;
  final TextEditingController field;
  const _SourceCard({required this.controller, required this.field});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    final zh = c.trFrom == 'zh';
    return SurfaceBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: field,
            onChanged: c.trSetSource,
            onSubmitted: (_) => c.trTranslateNow(),
            maxLines: 4,
            minLines: 2,
            textInputAction: TextInputAction.done,
            style: zh
                ? ZwsFonts.han(size: 22, color: t.ink, height: 1.4)
                : ZwsFonts.sans(size: 16, color: t.ink, height: 1.4),
            cursorColor: t.seal,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: zh ? '输入中文…' : 'Ketik teks Indonesia…',
              hintStyle: ZwsFonts.sans(size: 15, color: t.ink3),
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: t.line),
          const SizedBox(height: 10),
          Row(
            children: [
              _ActionIcon(
                icon: ZwsIcons.mic,
                label: c.trRecording ? 'Stop' : 'Suara',
                active: c.trRecording,
                busy: c.trVoiceBusy,
                onTap: c.trToggleVoice,
              ),
              const SizedBox(width: 6),
              _ActionIcon(
                icon: ZwsIcons.image,
                label: 'Foto',
                busy: c.trPhotoBusy,
                onTap: c.trPickPhoto,
              ),
              const Spacer(),
              if (c.trSource.isNotEmpty)
                _ActionIcon(
                  icon: ZwsIcons.clear,
                  label: 'Hapus',
                  onTap: c.trClear,
                ),
              const SizedBox(width: 6),
              _TranslateButton(onTap: c.trTranslateNow, loading: c.trLoading),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool busy;
  final VoidCallback onTap;
  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.busy = false,
  });
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final fg = active ? Colors.white : t.ink2;
    return Material(
      color: active ? t.seal : t.surface2,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              else
                Icon(icon, size: 17, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: ZwsFonts.sans(
                  size: 12,
                  weight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TranslateButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool loading;
  const _TranslateButton({required this.onTap, required this.loading});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Material(
      color: t.seal,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Terjemah',
                  style: ZwsFonts.sans(
                    size: 13,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final AppController controller;
  const _ResultCard({required this.controller});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    if (c.trError != null) {
      return SurfaceBox(
        background: t.surface2,
        child: Text(
          c.trError!,
          style: ZwsFonts.sans(size: 13, color: t.ink2, height: 1.5),
        ),
      );
    }
    final r = c.trResult;
    if (r == null) {
      return SurfaceBox(
        background: t.surface2,
        child: Row(
          children: [
            Icon(ZwsIcons.translate, size: 18, color: t.ink3),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                c.trLoading
                    ? 'Menerjemahkan…'
                    : 'Hasil terjemahan muncul di sini.',
                style: ZwsFonts.sans(size: 13, color: t.ink3),
              ),
            ),
          ],
        ),
      );
    }
    final toZh = c.trTo == 'zh';
    return SurfaceBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionLabel('Hasil'),
              Row(
                children: [
                  _MiniIcon(
                    icon: ZwsIcons.sound,
                    onTap: c.trSpeakResult,
                    show: toZh || c.trFrom == 'zh',
                  ),
                  _MiniIcon(
                    icon: ZwsIcons.copy,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: r.translation));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Tersalin ke clipboard',
                            style: ZwsFonts.sans(
                              size: 13,
                              weight: FontWeight.w600,
                            ),
                          ),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(milliseconds: 1200),
                        ),
                      );
                    },
                    show: true,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          toZh
              ? SelectableText(
                  r.translation,
                  style: ZwsFonts.han(size: 26, color: t.ink, height: 1.4),
                )
              : SelectableText(
                  r.translation,
                  style: ZwsFonts.sans(size: 18, color: t.ink, height: 1.45),
                ),
          if ((r.pinyin ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            SelectableText(
              r.pinyin!,
              style: ZwsFonts.mono(size: 13, color: t.seal),
            ),
          ],
          if (r.alternatives.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: t.line),
            const SizedBox(height: 12),
            const SectionLabel('Pilihan lain'),
            const SizedBox(height: 8),
            for (final alt in r.alternatives) _TokenRow(token: alt),
          ],
          if (r.tokens.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: t.line),
            const SizedBox(height: 12),
            const SectionLabel('Rincian kata'),
            const SizedBox(height: 8),
            for (final tok in r.tokens) _TokenRow(token: tok),
          ],
        ],
      ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool show;
  const _MiniIcon({
    required this.icon,
    required this.onTap,
    required this.show,
  });
  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    final t = ZwsTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: t.ink2),
      ),
    );
  }
}

class _TokenRow extends StatelessWidget {
  final TranslateToken token;
  const _TokenRow({required this.token});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final allM = token.allMeanings;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            token.hanzi,
            style: ZwsFonts.han(size: 20, color: t.ink),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (token.pinyin.isNotEmpty)
                  SelectableText(
                    token.pinyin,
                    style: ZwsFonts.mono(size: 12, color: t.seal),
                  ),
                if (allM.isNotEmpty) ...[
                  // Primary meaning (bold)
                  if (allM[0].isNotEmpty)
                    SelectableText(
                      allM[0],
                      style: ZwsFonts.sans(
                        size: 13,
                        color: t.ink,
                        weight: FontWeight.w600,
                      ),
                    ),
                  // Alt meanings (lighter, comma-separated)
                  if (allM.length > 1) ...[
                    const SizedBox(height: 2),
                    SelectableText(
                      allM.sublist(1).join(', '),
                      style: ZwsFonts.sans(
                        size: 12,
                        color: t.ink2,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (token.hsk != null) ...[
            const SizedBox(width: 8),
            Pill('HSK ${token.hsk}'),
          ],
        ],
      ),
    );
  }
}
