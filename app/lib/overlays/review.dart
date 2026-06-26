import 'package:flutter/material.dart';

import '../models/vocab.dart';
import '../state/app_controller.dart';
import '../theme/tokens.dart';
import '../theme/zws_theme.dart';
import '../widgets/common.dart';
import '../widgets/ico.dart';

class ReviewOverlay extends StatelessWidget {
  final AppController controller;
  final bool desktop;
  const ReviewOverlay({
    super.key,
    required this.controller,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    final total = c.sessionCards.length;
    final active = c.reviewIdx < total;
    final isSelf = c.reviewMode == 'self';
    final done = c.reviewIdx.clamp(0, total);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) c.closeSub();
      },
      child: Container(
        color: t.bg,
        child: Column(
          children: [
            OverlayBar(
              desktop: desktop,
              onBack: c.closeSub,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isSelf ? 'Tes · Self-check' : 'Review',
                    style: ZwsFonts.sans(
                      size: 15,
                      weight: FontWeight.w800,
                      color: t.ink,
                    ),
                  ),
                  Mono('$done / $total', size: 11, color: t.ink3),
                ],
              ),
            ),
            ThinProgress(total == 0 ? 0 : done / total),
            Expanded(
              child: active
                  ? _ReviewBody(controller: c)
                  : _Finish(controller: c, isSelf: isSelf, total: total),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewBody extends StatefulWidget {
  final AppController controller;
  const _ReviewBody({required this.controller});
  @override
  State<_ReviewBody> createState() => _ReviewBodyState();
}

class _ReviewBodyState extends State<_ReviewBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipCtrl;
  late final Animation<double> _flipAnim;
  bool _wasFlipped = false;
  int _lastIdx = 0;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnim = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut));
    _lastIdx = widget.controller.reviewIdx;
  }

  @override
  void didUpdateWidget(covariant _ReviewBody old) {
    super.didUpdateWidget(old);
    final c = widget.controller;
    final nowFlipped = c.flipped;

    // Card changed — reset instantly
    if (c.reviewIdx != _lastIdx) {
      _lastIdx = c.reviewIdx;
      _wasFlipped = false;
      _flipCtrl.value = 0.0;
      return;
    }

    if (nowFlipped != _wasFlipped) {
      _wasFlipped = nowFlipped;
      if (nowFlipped) {
        _flipCtrl.forward();
      } else {
        _flipCtrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = widget.controller;
    final id = c.sessionCards[c.reviewIdx.clamp(0, c.sessionCards.length - 1)];
    final card = c.card(id);
    final id2zh = c.testDirection == 'id2zh';

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth - 32;
        final cardW = (maxW > 400 ? 400.0 : maxW).clamp(260.0, 400.0);
        final cardH = cardW * 0.85;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 12),
              GestureDetector(
                onTap: c.flipCard,
                onHorizontalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v.abs() > 300) c.flipCard();
                },
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _flipAnim,
                    builder: (context, child) {
                      final isFront = _flipAnim.value < 0.5;
                      final angle = _flipAnim.value * 3.14159; // pi
                      // Show front when value < 0.5, back when > 0.5
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001) // perspective
                          ..rotateY(angle),
                        child: isFront
                            ? _buildFront(c, card, id2zh, cardW, cardH)
                            : Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..rotateY(3.14159),
                                child: _buildBack(c, card, id2zh, cardW, cardH),
                              ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: cardW,
                child: Row(
                  children: [
                    Expanded(
                      child: _RateButton(
                        label: 'Salah',
                        icon: ZwsIcons.cross,
                        color: t.seal,
                        bg: t.sealSoft,
                        onTap: () => c.rate(false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RateButton(
                        label: 'Benar',
                        icon: ZwsIcons.check,
                        color: t.green,
                        bg: t.correctTint,
                        onTap: () => c.rate(true),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ketuk kartu untuk lihat jawaban',
                style: ZwsFonts.sans(size: 11, color: t.ink3),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFront(
    AppController c,
    VocabEntry card,
    bool id2zh,
    double w,
    double h,
  ) {
    if (id2zh) {
      return _CardFront(
        controller: c,
        card: card,
        isId2zh: true,
        width: w,
        height: h,
      );
    }
    return _CardFront(controller: c, card: card, width: w, height: h);
  }

  Widget _buildBack(
    AppController c,
    VocabEntry card,
    bool id2zh,
    double w,
    double h,
  ) {
    if (id2zh) {
      return _CardBack(
        controller: c,
        card: card,
        isId2zh: true,
        width: w,
        height: h,
      );
    }
    return _CardBack(controller: c, card: card, width: w, height: h);
  }
}

class _CardFace extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  const _CardFace({required this.child, this.width, this.height});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return Container(
      width: width ?? 360,
      height: height ?? 330,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardFront extends StatelessWidget {
  final AppController controller;
  final VocabEntry card;
  final bool isId2zh;
  final double? width;
  final double? height;
  const _CardFront({
    required this.controller,
    required this.card,
    this.isId2zh = false,
    this.width,
    this.height,
  });
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final showSecondary = controller.track == 'both';
    if (isId2zh) return _buildId2zhFront(t);
    return _CardFace(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'KATA',
                  style: ZwsFonts.sans(
                    size: 10,
                    weight: FontWeight.w600,
                    color: t.ink3,
                    letterSpacing: 1.4,
                  ),
                ),
                _SpeakBtn(onTap: controller.speakCurrentReview),
              ],
            ),
          ),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Han(
                    controller.primaryHanzi(card),
                    size: 72,
                    color: t.ink,
                    height: 1.05,
                  ),
                  if (showSecondary) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '繁體 ',
                          style: ZwsFonts.sans(size: 12, color: t.ink3),
                        ),
                        Han(card.traditional, size: 18, color: t.ink2),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildId2zhFront(ZwsTokens t) {
    return _CardFace(
      width: width,
      height: height,
      child: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Text(
              'ARTI',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  card.meaningPreview,
                  textAlign: TextAlign.center,
                  style: ZwsFonts.sans(
                    size: 28,
                    weight: FontWeight.w800,
                    color: t.ink,
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

class _CardBack extends StatelessWidget {
  final AppController controller;
  final VocabEntry card;
  final bool isId2zh;
  final double? width;
  final double? height;
  const _CardBack({
    required this.controller,
    required this.card,
    this.isId2zh = false,
    this.width,
    this.height,
  });
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final showZhuyin =
        controller.zhuyin &&
        (controller.track == 'traditional' || controller.track == 'both');
    final example = controller.track == 'traditional'
        ? card.exampleT
        : card.exampleS;

    if (isId2zh) {
      return _CardFace(
        width: width,
        height: height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: _SpeakBtn(onTap: controller.speakCurrentReview),
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Han(
                controller.primaryHanzi(card),
                size: 56,
                color: t.ink,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 6),
            Mono(card.pinyin, size: 13, color: t.ink3, letterSpacing: 0.5),
            if (showZhuyin) ...[
              const SizedBox(height: 2),
              Han(card.zhuyin, size: 14, color: t.seal, letterSpacing: 1.4),
            ],
            const SizedBox(height: 4),
            Text(
              card.meaningPreview,
              textAlign: TextAlign.center,
              style: ZwsFonts.sans(size: 14, color: t.ink2),
            ),
            if (example.isNotEmpty) ...[
              const Spacer(),
              const Divider(),
              const SizedBox(height: 6),
              Flexible(
                child: SingleChildScrollView(
                  child: Han(example, size: 16, color: t.ink2),
                ),
              ),
              if (card.exampleId.isNotEmpty)
                Text(
                  card.exampleId,
                  textAlign: TextAlign.center,
                  style: ZwsFonts.sans(size: 11, color: t.ink3),
                ),
            ] else
              const Spacer(),
          ],
        ),
      );
    }
    return _CardFace(
      width: width,
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: _SpeakBtn(onTap: controller.speakCurrentReview),
          ),
          Mono(card.pinyin, size: 13, color: t.ink3, letterSpacing: 0.5),
          if (showZhuyin) ...[
            const SizedBox(height: 2),
            Han(card.zhuyin, size: 14, color: t.seal, letterSpacing: 1.4),
          ],
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Han(
              controller.primaryHanzi(card),
              size: 30,
              color: t.ink,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              card.meaningPreview,
              textAlign: TextAlign.center,
              style: ZwsFonts.sans(
                size: 20,
                weight: FontWeight.w800,
                color: t.ink,
              ),
            ),
          ),
          if (example.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Han(example, size: 17, color: t.ink2),
              ),
            ),
            if (card.exampleId.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                card.exampleId,
                textAlign: TextAlign.center,
                style: ZwsFonts.sans(size: 11, color: t.ink3),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SpeakBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _SpeakBtn({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: t.surface2,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: t.line),
        ),
        child: const Icon(ZwsIcons.sound, size: 18),
      ),
    );
  }
}

class _RateButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  const _RateButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 7),
              Text(
                label,
                style: ZwsFonts.sans(
                  size: 14,
                  weight: FontWeight.w700,
                  color: color,
                ),
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
  final bool isSelf;
  final int total;
  const _Finish({
    required this.controller,
    required this.isSelf,
    required this.total,
  });
  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    final c = controller;
    final pct = total == 0
        ? 0
        : ((isSelf ? c.reviewScore : total) * 100 / total).round();
    final score = isSelf ? c.reviewScore : total;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Selesai!',
            style: ZwsFonts.sans(
              size: 24,
              weight: FontWeight.w800,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSelf
                ? 'Skor: $score / $total ($pct%)'
                : 'Semua kartu sudah direview.',
            style: ZwsFonts.sans(size: 14, color: t.ink2),
          ),
          if (isSelf) ...[
            const SizedBox(height: 4),
            Text(
              'Masuk ke nilai Ujian Harian.',
              style: ZwsFonts.sans(size: 11, color: t.ink3),
            ),
          ],
          const SizedBox(height: 20),
          Material(
            color: t.seal,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: c.closeSub,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28, vertical: 13),
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
    );
  }
}
