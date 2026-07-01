import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../widgets/common.dart';

/// Comprehensive final exam: mix of MC, spelling, and tone questions
/// drawn from all user cards. Score feeds into the rapor.
class UjianAkhirOverlay extends StatefulWidget {
  final AppController controller;
  const UjianAkhirOverlay({super.key, required this.controller});

  @override
  State<UjianAkhirOverlay> createState() => _UjianAkhirOverlayState();
}

class _UjianAkhirOverlayState extends State<UjianAkhirOverlay> {
  int _idx = 0;
  int _score = 0;
  bool _done = false;
  late final List<_UjianSoal> _soal;

  @override
  void initState() {
    super.initState();
    _soal = _generateSoal(widget.controller);
  }

  List<_UjianSoal> _generateSoal(AppController c) {
    final allIds = c.smartPracticeBase();
    if (allIds.isEmpty) return [];
    allIds.shuffle(c.rng);

    final soal = <_UjianSoal>[];
    final used = <int>{};

    // 8 multiple choice
    for (var i = 0; i < allIds.length && soal.length < 8; i++) {
      final card = c.cards[allIds[i]]!;
      if (used.contains(allIds[i])) continue;
      used.add(allIds[i]);
      soal.add(
        _McSoal(c, allIds[i], c.primaryHanzi(card), card.primaryMeaning),
      );
    }

    // 6 spelling
    for (var i = 0; i < allIds.length && soal.length < 14; i++) {
      if (used.contains(allIds[i])) continue;
      final card = c.cards[allIds[i]]!;
      used.add(allIds[i]);
      soal.add(
        _SpellSoal(
          allIds[i],
          card.meaningPreview,
          c.primaryHanzi(card),
          card.pinyin,
        ),
      );
    }

    // 6 tone
    for (var i = 0; i < allIds.length && soal.length < 20; i++) {
      if (used.contains(allIds[i])) continue;
      final card = c.cards[allIds[i]]!;
      used.add(allIds[i]);
      soal.add(
        _ToneSoal(allIds[i], c.primaryHanzi(card), card.pinyin, card.tone),
      );
    }

    soal.shuffle(c.rng);
    return soal;
  }

  void _answer(bool correct) {
    if (_done) return;
    widget.controller.recordUjianAkhirAnswer(_soal[_idx].cardId, correct);
    if (correct) _score++;
    if (_idx + 1 >= _soal.length) {
      setState(() {
        _done = true;
        widget.controller.finishUjianAkhir(_score, _soal.length);
      });
    } else {
      setState(() => _idx++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    if (_soal.isEmpty) {
      return Scaffold(
        backgroundColor: t.bg,
        body: Center(
          child: Text(
            'Belum ada kartu untuk diujikan. Tambah kartu dulu.',
            style: ZwsFonts.sans(size: 14, color: t.ink3),
          ),
        ),
      );
    }
    if (_done) return _buildResult(t);
    return _buildQuestion(t);
  }

  Widget _buildQuestion(ZwsTokens t) {
    final s = _soal[_idx];
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Ujian Akhir · Soal ${_idx + 1}/${_soal.length}',
                    style: ZwsFonts.sans(
                      size: 13,
                      weight: FontWeight.w700,
                      color: t.ink,
                    ),
                  ),
                  const Spacer(),
                  Mono('Skor: $_score', size: 12, color: t.seal),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_idx + 1) / _soal.length,
                  minHeight: 4,
                  backgroundColor: t.line2,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFB8860B)),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: s.buildWidget(() => setState(() {}), _answer, t),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult(ZwsTokens t) {
    final pct = _soal.isEmpty ? 0 : (_score * 100 / _soal.length).round();
    final lulus = pct >= 70;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lulus ? 'SELAMAT!' : 'COBA LAGI',
                  style: ZwsFonts.sans(
                    size: 28,
                    weight: FontWeight.w800,
                    color: lulus ? t.green : t.ink3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Nilai Ujian Akhir',
                  style: ZwsFonts.sans(size: 14, color: t.ink2),
                ),
                const SizedBox(height: 6),
                Mono(
                  '$_score / ${_soal.length}',
                  size: 48,
                  weight: FontWeight.w800,
                  color: t.ink,
                ),
                const SizedBox(height: 4),
                Mono('($pct%)', size: 16, color: t.seal),
                const SizedBox(height: 8),
                Text(
                  lulus
                      ? 'Kamu lulus! Skor masuk ke rapor.'
                      : 'Belum lulus (min 70). Coba lagi nanti.',
                  style: ZwsFonts.sans(size: 13, color: t.ink2),
                ),
                const SizedBox(height: 24),
                Material(
                  color: t.seal,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => widget.controller.closeSub(),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      child: Text(
                        'Kembali',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
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

// ---- question types ----

abstract class _UjianSoal {
  int get cardId;

  Widget buildWidget(
    VoidCallback onSetState,
    void Function(bool correct) onAnswer,
    ZwsTokens t,
  );
}

class _McSoal extends _UjianSoal {
  final AppController c;
  @override
  final int cardId;
  final String hanzi;
  final String correct;

  _McSoal(this.c, this.cardId, this.hanzi, this.correct);

  @override
  Widget buildWidget(
    VoidCallback onSetState,
    void Function(bool correct) onAnswer,
    ZwsTokens t,
  ) {
    final options = <String>[correct];
    final all = c.cards.values
        .where((v) => v.primaryMeaning != correct)
        .toList();
    all.shuffle(c.rng);
    for (var i = 0; i < 3 && i < all.length; i++) {
      options.add(all[i].primaryMeaning);
    }
    options.shuffle(c.rng);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Pilih arti yang tepat'),
        const SizedBox(height: 14),
        Center(child: Han(hanzi, size: 44, color: t.ink)),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'Arti dari hanzi di atas adalah…',
            style: ZwsFonts.sans(size: 13, color: t.ink3),
          ),
        ),
        const SizedBox(height: 16),
        for (final o in options) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: Material(
                color: t.surface,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => onAnswer(o == correct),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: t.line),
                    ),
                    child: Text(
                      o,
                      style: ZwsFonts.sans(size: 15, color: t.ink),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SpellSoal extends _UjianSoal {
  @override
  final int cardId;
  final String meaning;
  final String correct;
  final String pinyin;
  String _input = '';
  bool _checked = false;
  bool _correct = false;

  _SpellSoal(this.cardId, this.meaning, this.correct, this.pinyin);

  @override
  Widget buildWidget(
    VoidCallback onSetState,
    void Function(bool correct) onAnswer,
    ZwsTokens t,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Tulis hanzi-nya'),
        const SizedBox(height: 10),
        Text(
          'Arti: "$meaning"',
          style: ZwsFonts.sans(size: 15, weight: FontWeight.w600, color: t.ink),
        ),
        const SizedBox(height: 4),
        if (pinyin.isNotEmpty)
          Text(
            'Pinyin: $pinyin',
            style: ZwsFonts.sans(size: 12, color: t.ink3),
          ),
        const SizedBox(height: 16),
        TextField(
          autofocus: true,
          style: ZwsFonts.sans(size: 24, color: t.ink),
          decoration: InputDecoration(
            hintText: 'Tulis hanzi di sini…',
            hintStyle: ZwsFonts.sans(size: 16, color: t.ink3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: t.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: t.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: t.seal, width: 2),
            ),
            suffixIcon: _checked
                ? Icon(
                    _correct ? Icons.check_circle : Icons.cancel,
                    color: _correct ? t.green : Colors.red.shade400,
                  )
                : null,
          ),
          onChanged: (v) {
            _input = v;
            onSetState();
          },
          onSubmitted: (_) => _check(onSetState),
        ),
        const SizedBox(height: 12),
        if (_checked) ...[
          Text(
            'Jawaban: $correct',
            style: ZwsFonts.sans(
              size: 14,
              color: _correct ? t.green : Colors.red.shade400,
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: Material(
            color: t.seal,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: _checked
                  ? () => onAnswer(_correct)
                  : () => _check(onSetState),
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Center(
                  child: Text(
                    'Periksa',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _check(VoidCallback onSetState) {
    _correct = _input.trim() == correct;
    _checked = true;
    onSetState();
  }
}

class _ToneSoal extends _UjianSoal {
  @override
  final int cardId;
  final String hanzi;
  final String pinyin;
  final int correct;

  _ToneSoal(this.cardId, this.hanzi, this.pinyin, this.correct);

  static const _names = {
    1: 'Pertama (—)',
    2: 'Kedua (ˊ)',
    3: 'Ketiga (ˇ)',
    4: 'Keempat (ˋ)',
  };

  @override
  Widget buildWidget(
    VoidCallback onSetState,
    void Function(bool correct) onAnswer,
    ZwsTokens t,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Nada suku kata pertama?'),
        const SizedBox(height: 14),
        Center(child: Han(hanzi, size: 44, color: t.ink)),
        if (pinyin.isNotEmpty) ...[
          const SizedBox(height: 6),
          Center(child: Mono(pinyin, size: 14, color: t.ink3)),
        ],
        const SizedBox(height: 20),
        for (final tno in [1, 2, 3, 4]) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: Material(
                color: t.surface,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => onAnswer(tno == correct),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: t.line),
                    ),
                    child: Text(
                      'Nada ${_names[tno]}',
                      style: ZwsFonts.sans(size: 15, color: t.ink),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
