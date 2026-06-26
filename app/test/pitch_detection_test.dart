import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/services/pitch_service.dart';

/// Layer-1 evidence: drive the pitch detector with synthetic signals of KNOWN
/// frequency so we can confirm it reports the right Hz (and the right octave)
/// without a microphone. These are the cases that matter for tone practice:
/// the speech range, harmonic-rich tones (the classic octave-error trap), and a
/// rising glissando (tone 2 shape).
void main() {
  final rate = PitchService.sampleRate.toDouble();
  final n = PitchService.frameSize;

  double rms(List<double> x) {
    double e = 0;
    for (final v in x) {
      e += v * v;
    }
    return math.sqrt(e / x.length);
  }

  // Pure sine at [f] Hz.
  List<double> sine(double f) =>
      List<double>.generate(n, (i) => math.sin(2 * math.pi * f * i / rate));

  // Voice-like tone: fundamental + decaying harmonics. The 2nd/3rd harmonics
  // are what tempt plain autocorrelation into octave errors.
  List<double> voiced(double f) => List<double>.generate(
      n,
      (i) =>
          1.0 * math.sin(2 * math.pi * f * i / rate) +
          0.6 * math.sin(2 * math.pi * 2 * f * i / rate) +
          0.4 * math.sin(2 * math.pi * 3 * f * i / rate) +
          0.2 * math.sin(2 * math.pi * 4 * f * i / rate));

  void expectHz(double? got, double want, {double tolPct = 4}) {
    expect(got, isNotNull, reason: 'expected ~$want Hz, got null');
    final errPct = (got! - want).abs() / want * 100;
    expect(errPct < tolPct, isTrue,
        reason: 'expected ~$want Hz, got ${got.toStringAsFixed(1)} Hz '
            '(${errPct.toStringAsFixed(1)}% off)');
  }

  group('pure sines across the speech range', () {
    for (final f in [90.0, 120.0, 150.0, 196.0, 220.0, 280.0, 350.0]) {
      test('${f.toInt()} Hz', () {
        final x = sine(f);
        expectHz(PitchService.detectForTest(x, rms(x)), f);
      });
    }
  });

  group('harmonic-rich tones report the fundamental (no octave error)', () {
    for (final f in [110.0, 150.0, 196.0, 240.0]) {
      test('voiced ${f.toInt()} Hz', () {
        final x = voiced(f);
        final got = PitchService.detectForTest(x, rms(x));
        expectHz(got, f);
        // Explicitly guard against the octave-down / octave-up traps.
        expect((got! - f / 2).abs() / f > 0.1, isTrue, reason: 'halved');
        expect((got - f * 2).abs() / f > 0.1, isTrue, reason: 'doubled');
      });
    }
  });

  test('silence returns null', () {
    final x = List<double>.filled(n, 0.0);
    expect(PitchService.detectForTest(x, rms(x)), isNull);
  });

  test('rising glissando tracks upward frame-to-frame (tone 2 shape)', () {
    // A sweep 150 -> 230 Hz; detect on overlapping windows and confirm the
    // estimate rises monotonically-ish (each later window higher than earlier).
    double phase = 0;
    final full = <double>[];
    for (var i = 0; i < n * 3; i++) {
      final f = 150 + (230 - 150) * (i / (n * 3));
      phase += 2 * math.pi * f / rate;
      full.add(math.sin(phase));
    }
    final first = full.sublist(0, n);
    final last = full.sublist(n * 2, n * 3);
    final f0 = PitchService.detectForTest(first, rms(first));
    final f1 = PitchService.detectForTest(last, rms(last));
    expect(f0, isNotNull);
    expect(f1, isNotNull);
    expect(f1! > f0! + 20, isTrue,
        reason: 'glissando should rise: f0=$f0 f1=$f1');
  });
}
