import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/srs/tone_match.dart';

/// Synthetic semitone contours (calibration-free shape testing).
List<double> _ramp(double from, double to, [int n = 30]) =>
    List.generate(n, (i) => from + (to - from) * i / (n - 1));

List<double> _flat(double v, [int n = 30]) => List.filled(n, v);

List<double> _dip([int n = 30]) {
  // start mid, dip low, rise high — like tone 3
  final out = <double>[];
  for (var i = 0; i < n; i++) {
    final t = i / (n - 1);
    // piecewise: 0..0.4 falls, 0.4..1 rises
    out.add(t < 0.4 ? 2 - 5 * t : -0.5 + 6 * (t - 0.4));
  }
  return out;
}

void main() {
  group('resampleContour', () {
    test('keeps endpoints and interpolates the middle', () {
      final r = resampleContour([0, 10], 3);
      expect(r.first, closeTo(0, 1e-9));
      expect(r[1], closeTo(5, 1e-9));
      expect(r.last, closeTo(10, 1e-9));
    });
    test('returns empty when too few points', () {
      expect(resampleContour([1], 5), isEmpty);
    });
  });

  group('toneMatchScore — correct tone scores high', () {
    test('flat → tone 1', () {
      expect(toneMatchScore(_flat(60), 1), greaterThan(0.8));
    });
    test('rising → tone 2', () {
      expect(toneMatchScore(_ramp(58, 64), 2), greaterThan(0.75));
    });
    test('falling → tone 4', () {
      expect(toneMatchScore(_ramp(64, 58), 4), greaterThan(0.75));
    });
    test('dip → tone 3', () {
      expect(toneMatchScore(_dip(), 3), greaterThan(0.6));
    });
  });

  group('toneMatchScore — wrong tone scores low', () {
    test('rising attempt judged as tone 4 (falling)', () {
      expect(toneMatchScore(_ramp(58, 64), 4), lessThan(0.3));
    });
    test('falling attempt judged as tone 2 (rising)', () {
      expect(toneMatchScore(_ramp(64, 58), 2), lessThan(0.3));
    });
    test('a big rise is not a clean level tone', () {
      expect(toneMatchScore(_ramp(58, 66), 1), lessThan(0.3));
    });
    test('a near-flat line is a poor rising tone', () {
      expect(toneMatchScore(_flat(60), 2), lessThan(0.3));
    });
  });
}
