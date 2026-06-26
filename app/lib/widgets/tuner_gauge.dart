import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/zws_theme.dart';

/// Real-time tone tuner gauge. Draws the target tone *shape* (dashed grey +
/// seal) and, while recording, plots the **live pitch trace** of the current
/// syllable ([trace] = semitones, newest last). The trace is normalized by its
/// own range and spread across the full width, so the tone shape — not the
/// absolute pitch — is what lines up with the target. Both target and trace
/// live in the same normalized band; the contours below are shape-only
/// (everything centred), matching the self-normalized trace.
class TunerGauge extends StatelessWidget {
  final int tone; // 1–4
  final bool recording;
  final List<double> trace;
  final double score; // 0..1 tone-shape match (colours the trace green ≥ 0.7)
  const TunerGauge({
    super.key,
    required this.tone,
    required this.recording,
    this.trace = const [],
    this.score = 0,
  });

  static const Map<int, List<Offset>> _contours = {
    1: [Offset(10, 52), Offset(90, 52)], // level — flat
    2: [Offset(10, 82), Offset(90, 22)], // rising — fills the band
    3: [Offset(10, 44), Offset(42, 84), Offset(70, 76), Offset(90, 32)], // dip
    4: [Offset(10, 22), Offset(90, 82)], // falling — fills the band
  };

  @override
  Widget build(BuildContext context) {
    final t = ZwsTheme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: t.surface2,
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: CustomPaint(
          painter: _TunerPainter(
            contour: _contours[tone] ?? _contours[1]!,
            recording: recording,
            trace: trace,
            seal: t.seal,
            guide: t.ink3,
            line: t.line,
            traceColor: score >= 0.7 ? t.green : t.seal,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _TunerPainter extends CustomPainter {
  final List<Offset> contour;
  final bool recording;
  final List<double> trace;
  final Color seal;
  final Color guide;
  final Color line;
  final Color traceColor;
  // Fixed vertical span (semitones) of the gauge band. The trace is centred on
  // the syllable's *onset* pitch and drawn against this fixed span — so the
  // contour stays stable instead of rescaling every frame, while remaining
  // calibration-free (relative to the speaker's own start pitch, not absolute).
  static const double _bandSpanSt = 12.0;
  _TunerPainter({
    required this.contour,
    required this.recording,
    required this.trace,
    required this.seal,
    required this.guide,
    required this.line,
    required this.traceColor,
  });

  Offset _p(Offset c, Size s) =>
      Offset(c.dx / 100 * s.width, c.dy / 100 * s.height);

  @override
  void paint(Canvas canvas, Size size) {
    // centre baseline
    canvas.drawLine(Offset(0, size.height / 2),
        Offset(size.width, size.height / 2), Paint()..color = line..strokeWidth = 1);

    final pts = contour.map((c) => _p(c, size)).toList();

    // dashed grey target
    _drawDashed(
        canvas,
        pts,
        Paint()
          ..color = guide
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round);

    // solid seal target (semi-transparent)
    final targetPaint = Paint()
      ..color = seal.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, targetPaint);

    // live mic pitch trace — centred on the syllable's onset pitch and drawn
    // against a fixed semitone band, so the contour is stable (no per-frame
    // rescaling) yet still calibration-free. Shape, not absolute pitch, lines
    // up with the target.
    if (recording) {
      final st = <double>[];
      for (final v in trace) {
        if (!v.isNaN && v.isFinite) st.add(v);
      }
      if (st.length >= 2) {
        // Onset pitch = median of the first few voiced frames → stable centre.
        final head = st.take(8).toList()..sort();
        final centre = head[head.length ~/ 2];
        final bandLo = centre - _bandSpanSt / 2;
        final tracePaint = Paint()
          ..color = traceColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        final tp = Path();
        Offset? last;
        for (var i = 0; i < st.length; i++) {
          final norm = ((st[i] - bandLo) / _bandSpanSt).clamp(0.0, 1.0);
          final x = i / (st.length - 1) * size.width;
          final y = (84 - norm * 64) / 100 * size.height; // high pitch → top
          if (i == 0) {
            tp.moveTo(x, y);
          } else {
            tp.lineTo(x, y);
          }
          last = Offset(x, y);
        }
        canvas.drawPath(tp, tracePaint);
        if (last != null) {
          canvas.drawCircle(last, 4.5, Paint()..color = traceColor);
        }
      }
    }
  }

  void _drawDashed(Canvas canvas, List<Offset> pts, Paint paint) {
    const dash = 5.0, gap = 4.0;
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      final len = (b - a).distance;
      final dir = (b - a) / len;
      double d = 0;
      while (d < len) {
        final s = a + dir * d;
        final e = a + dir * math.min(d + dash, len);
        canvas.drawLine(s, e, paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_TunerPainter old) =>
      old.recording != recording ||
      old.trace != trace ||
      old.contour != contour ||
      old.traceColor != traceColor;
}
