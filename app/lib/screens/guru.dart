import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../widgets/common.dart';
import '../widgets/ico.dart';
import '../widgets/tutor_text.dart';
import '../widgets/tuner_gauge.dart';

class GuruScreen extends StatelessWidget {
  final AppController controller;
  final bool desktop;
  const GuruScreen({
    super.key,
    required this.controller,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // segmented tabs
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: t.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Seg(controller: c, value: 'chat', label: 'Chat privat'),
              _Seg(controller: c, value: 'voice', label: 'Suara & Nada'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (c.guruTab == 'chat')
          Expanded(child: _ChatPane(controller: c))
        else
          Expanded(
            child: SingleChildScrollView(child: _VoicePane(controller: c)),
          ),
      ],
    );
  }
}

class _Seg extends StatelessWidget {
  final AppController controller;
  final String value;
  final String label;
  const _Seg({
    required this.controller,
    required this.value,
    required this.label,
  });
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final on = controller.guruTab == value;
    return InkWell(
      onTap: () => controller.setGuruTab(value),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: on ? t.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: ZwsFonts.sans(
            size: 13,
            weight: FontWeight.w700,
            color: on ? t.ink : t.ink3,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CHAT
// ---------------------------------------------------------------------------

class _ChatPane extends StatefulWidget {
  final AppController controller;
  const _ChatPane({required this.controller});
  @override
  State<_ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<_ChatPane> {
  final _tec = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _tec.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final txt = _tec.text.trim();
    if (txt.isEmpty) return;
    widget.controller.setChatInput(txt);
    widget.controller.sendChat();
    _tec.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = widget.controller;
    // Auto-scroll to bottom when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // curriculum banner — dynamic from curriculum-gen, with fallback
        if (c.showDailyMaterialBanner) ...[
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.line),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3, color: t.seal),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'MATERI HARIAN · BERKESINAMBUNGAN',
                                  style: ZwsFonts.sans(
                                    size: 9,
                                    weight: FontWeight.w700,
                                    color: t.seal,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: c.snoozeDailyMaterial,
                                style: TextButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Ingatkan nanti',
                                  style: ZwsFonts.sans(
                                    size: 11,
                                    weight: FontWeight.w700,
                                    color: t.seal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            c.dailyMaterial != null
                                ? '${c.dailyMaterial!.topic}. Target hari ini: ${c.dailyMaterial!.summary}.'
                                : 'HSK 2 · Unit 4 - Kata kerja perasaan. Target hari ini: 喜欢, 想, 觉得.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ZwsFonts.sans(
                              size: 12,
                              color: t.ink,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        // action button
        Row(
          children: [
            TextButton(
              onPressed: c.tutorTyping ? null : () => c.learnIdiomWithGuru(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                backgroundColor: t.sealSoft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Belajar idiom',
                style: ZwsFonts.sans(
                  size: 12,
                  weight: FontWeight.w600,
                  color: c.tutorTyping ? t.ink3 : t.seal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // messages — scrollable, takes all remaining space
        Expanded(
          child: ListView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.only(bottom: 8),
            children: [
              for (final m in c.messages) ...[
                _Bubble(controller: c, msg: m),
                const SizedBox(height: 12),
              ],
              if (c.tutorTyping) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(14),
                      ),
                      border: Border.all(color: t.line),
                    ),
                    child: Text(
                      'Guru sedang mengetik…',
                      style: ZwsFonts.sans(size: 13, color: t.ink3),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        // input — pinned at bottom
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: t.line),
                ),
                child: TextField(
                  controller: _tec,
                  style: ZwsFonts.sans(size: 14, color: t.ink),
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 13,
                    ),
                    border: InputBorder.none,
                    hintText: 'Tulis ke Guru… (cth. 我喜欢…)',
                    hintStyle: ZwsFonts.sans(size: 14, color: t.ink3),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            _SendButton(onTap: _send),
          ],
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final AppController controller;
  final ChatMsg msg;
  const _Bubble({required this.controller, required this.msg});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final tutor = msg.who == 't';
    return Align(
      alignment: tutor ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: tutor ? t.surface : t.ink,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(tutor ? 4 : 14),
              bottomRight: Radius.circular(tutor ? 14 : 4),
            ),
            border: tutor ? Border.all(color: t.line) : null,
          ),
          child: tutor
              ? TutorText(
                  text: controller.displayTutorText(msg.text),
                  color: t.ink,
                )
              : SelectableText(
                  msg.text,
                  style: ZwsFonts.sans(size: 14, color: t.bg, height: 1.5),
                ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SendButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Material(
      color: t.seal,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: const SizedBox(
          width: 46,
          height: 46,
          child: Icon(ZwsIcons.send, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// VOICE & TONE
// ---------------------------------------------------------------------------

class _VoicePane extends StatefulWidget {
  final AppController controller;
  const _VoicePane({required this.controller});
  @override
  State<_VoicePane> createState() => _VoicePaneState();
}

class _VoicePaneState extends State<_VoicePane> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.controller.micList.isEmpty) widget.controller.loadMics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = widget.controller;
    final hanzi = c.pronTarget;
    const toneNames = {1: '阴平', 2: '阳平', 3: '上声', 4: '去声'};
    const toneHz = {1: '210 Hz', 2: '196 Hz', 3: '168 Hz', 4: '220 Hz'};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // pronunciation score
        SurfaceBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SectionLabel('Skor pelafalan'),
                  Pill(
                    c.pronScore == null ? 'Azure' : '${c.pronScore}/100',
                    bg: c.pronScore == null
                        ? null
                        : (c.pronScore! >= 75 ? t.correctTint : t.sealSoft),
                    fg: c.pronScore == null
                        ? null
                        : (c.pronScore! >= 75 ? t.green : t.seal),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Han(hanzi, size: 40, color: t.ink2, height: 1.05),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.pronMsg.isEmpty
                              ? 'Ucapkan target ini untuk mendapat skor kejernihan dari Azure Speech.'
                              : c.pronMsg,
                          style: ZwsFonts.sans(
                            size: 12,
                            color: t.ink2,
                            height: 1.5,
                          ),
                        ),
                        if (c.pronTranscript.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            'Terdengar: ${c.pronTranscript}',
                            style: ZwsFonts.sans(
                              size: 12,
                              weight: FontWeight.w700,
                              color: t.ink,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (c.pronWords.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final w in c.pronWords.take(6))
                                Pill(
                                  '${w.word}${w.confidence == null ? '' : ' ${w.confidence}'}',
                                  bg: t.surface2,
                                  fg: t.ink2,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Material(
                color: c.pronRecording ? t.seal : t.sealSoft,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: c.pronBusy ? null : c.togglePronunciationAssessment,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (c.pronBusy)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: t.seal,
                            ),
                          )
                        else
                          Icon(
                            c.pronRecording ? ZwsIcons.check : ZwsIcons.mic,
                            size: 18,
                            color: c.pronRecording ? Colors.white : t.seal,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          c.pronBusy
                              ? 'Menganalisis'
                              : (c.pronRecording
                                    ? 'Selesai & nilai'
                                    : 'Nilai pelafalan'),
                          style: ZwsFonts.sans(
                            size: 13,
                            weight: FontWeight.w800,
                            color: c.pronRecording ? Colors.white : t.seal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (c.pronRecording) ...[
                const SizedBox(height: 8),
                Text(
                  'Rekaman skor memakai mic yang dipilih di bawah.',
                  style: ZwsFonts.sans(size: 11, color: t.ink3, height: 1.4),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        // tuner
        SurfaceBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SectionLabel('Tuner nada'),
                  Mono(
                    'T${c.tunerTone} · ${toneHz[c.tunerTone]} · ${toneNames[c.tunerTone]}',
                    size: 12,
                    weight: FontWeight.w700,
                    color: t.seal,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _MicPicker(controller: c),
              const SizedBox(height: 13),
              Row(
                children: [
                  for (final n in [1, 2, 3, 4]) ...[
                    Expanded(
                      child: _ToneSel(controller: c, tone: n),
                    ),
                    if (n != 4) const SizedBox(width: 7),
                  ],
                ],
              ),
              const SizedBox(height: 13),
              TunerGauge(
                tone: c.tunerTone,
                recording: c.recording,
                trace: c.pitchTrace,
                score: c.tunerMatch,
              ),
              if (c.recording && c.pitchTrace.length >= 12) ...[
                const SizedBox(height: 10),
                _MatchBar(score: c.tunerMatch),
              ],
              if (c.recording) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Level mic',
                      style: ZwsFonts.sans(size: 11, color: t.ink3),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: c.micLevel,
                          minHeight: 6,
                          backgroundColor: t.line2,
                          valueColor: AlwaysStoppedAnimation(
                            c.micLevel > 0.04 ? t.green : t.ink3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Mono(
                      c.currentHz != null ? '${c.currentHz!.round()}Hz' : '—',
                      size: 11,
                      color: t.seal,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Material(
                color: c.recording ? t.seal : t.sealSoft,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: c.toggleMic,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          ZwsIcons.mic,
                          size: 18,
                          color: c.recording ? Colors.white : t.seal,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          c.recording ? 'Stop merekam' : 'Mulai rekam',
                          style: ZwsFonts.sans(
                            size: 14,
                            weight: FontWeight.w700,
                            color: c.recording ? Colors.white : t.seal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                c.micUnavailable
                    ? 'Mikrofon tidak aktif (${c.micStatus}). Di Windows: Settings → Privacy & security → Microphone → aktifkan "Let desktop apps access your microphone".'
                    : c.recording
                    ? (c.micLevel <= 0.04
                          ? 'Tidak ada suara masuk. Cek mic & izin Windows (Settings → Privacy → Microphone), lalu coba bicara lebih dekat.'
                          : (c.currentHz != null
                                ? 'Bagus — terdengar ${c.currentHz!.round()} Hz. Ikuti bentuk kontur target.'
                                : 'Mendengarkan… ucapkan suku kata panjang & jelas mengikuti kontur.'))
                    : 'Tekan rekam, lalu ucapkan suku kata sesuai bentuk nada target.',
                style: ZwsFonts.sans(size: 11, color: t.ink3, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Live tone-shape match readout (calibration-free): a verdict + bar driven by
/// the controller's [AppController.toneScore].
class _MatchBar extends StatelessWidget {
  final double score; // 0..1
  const _MatchBar({required this.score});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final pct = (score * 100).round();
    final good = score >= 0.7;
    final ok = score >= 0.45;
    final color = good ? t.green : (ok ? t.seal : t.ink3);
    final verdict = good ? 'Tepat' : (ok ? 'Hampir' : 'Coba lagi');
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            verdict,
            style: ZwsFonts.sans(
              size: 12,
              weight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: score.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: t.line2,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 38,
          child: Mono('$pct%', size: 12, weight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

class _MicPicker extends StatelessWidget {
  final AppController controller;
  const _MicPicker({required this.controller});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    if (c.micList.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MIKROFON (pilih yang aktif)',
          style: ZwsFonts.sans(
            size: 10,
            weight: FontWeight.w600,
            color: t.ink3,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in c.micList)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: InkWell(
                  onTap: () => c.selectMic(d),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: c.micDevice?.id == d.id ? t.sealSoft : t.surface,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: c.micDevice?.id == d.id ? t.seal : t.line,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ZwsIcons.mic,
                          size: 13,
                          color: c.micDevice?.id == d.id ? t.seal : t.ink3,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            d.label.isEmpty ? d.id : d.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ZwsFonts.sans(
                              size: 11,
                              weight: FontWeight.w600,
                              color: c.micDevice?.id == d.id ? t.seal : t.ink2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ToneSel extends StatelessWidget {
  final AppController controller;
  final int tone;
  const _ToneSel({required this.controller, required this.tone});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final on = controller.tunerTone == tone;
    const labels = {1: '一声 ˉ', 2: '二声 ˊ', 3: '三声 ˇ', 4: '四声 ˋ'};
    return InkWell(
      onTap: () => controller.setTunerTone(tone),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: on ? t.sealSoft : t.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: on ? t.seal : t.line),
        ),
        child: Center(
          child: Text(
            labels[tone]!,
            style: ZwsFonts.sans(
              size: 12,
              weight: FontWeight.w700,
              color: on ? t.seal : t.ink2,
            ),
          ),
        ),
      ),
    );
  }
}
