// Shape-only scoring of a sung/spoken syllable against a Mandarin tone target.
//
// Deliberately calibration-free: it never assumes an absolute pitch range (the
// user rejected per-voice calibration and chose shape-only). It looks at the
// contour — flatness for tone 1, and the normalized rise/dip/fall shape for
// tones 2/3/4 — so it works for any voice. Input is the syllable's pitch in
// semitones (newest last). toneMatchScore returns 0..1 (1 = a clean match).
import 'dart:math' as math;

/// Canonical normalized tone targets (value 0..1, where 1 = high pitch),
/// sampled left→right across the syllable. Tone 1 is handled separately by
/// flatness, so it is not listed here.
const Map<int, List<double>> kToneTargets = {
  2: [0.0, 0.25, 0.5, 0.75, 1.0], // rising
  3: [0.55, 0.2, 0.0, 0.15, 0.7], // dip (low-dipping then rise)
  4: [1.0, 0.75, 0.5, 0.25, 0.0], // falling
};

/// Resamples [v] to exactly [k] points by linear interpolation. Returns an
/// empty list if there is not enough data.
List<double> resampleContour(List<double> v, int k) {
  final clean = v.where((x) => !x.isNaN && x.isFinite).toList();
  if (clean.length < 2 || k < 2) return const [];
  final out = List<double>.filled(k, 0);
  final n = clean.length;
  for (var i = 0; i < k; i++) {
    final pos = i / (k - 1) * (n - 1);
    final lo = pos.floor();
    final hi = math.min(lo + 1, n - 1);
    final frac = pos - lo;
    out[i] = clean[lo] * (1 - frac) + clean[hi] * frac;
  }
  return out;
}

/// Min/max range (in semitones) of [v], ignoring NaNs. 0 if fewer than 2 points.
double contourSpanSt(List<double> v) {
  final clean = v.where((x) => !x.isNaN && x.isFinite).toList();
  if (clean.length < 2) return 0;
  var lo = clean.first, hi = clean.first;
  for (final x in clean) {
    if (x < lo) lo = x;
    if (x > hi) hi = x;
  }
  return hi - lo;
}

/// Scores how well the semitone contour [trace] matches [tone] (1–4), 0..1.
///
/// - Tone 1 (level): rewards flatness — small total span scores high.
/// - Tones 2/3/4: requires a real excursion, then compares the min-max
///   normalized shape to the canonical target via mean absolute deviation.
///
/// Returns 0 when there is too little voiced data to judge.
double toneMatchScore(List<double> trace, int tone) {
  final span = contourSpanSt(trace);
  if (tone == 1) {
    // Flat within ~1.5 st reads as a clean level tone; degrade to ~6 st.
    return (1 - (span - 1.5) / 4.5).clamp(0.0, 1.0);
  }

  final target = kToneTargets[tone];
  if (target == null) return 0;

  // A rise/dip/fall needs a minimum excursion; a near-flat attempt at a
  // contour tone is wrong regardless of how its noise happens to normalize.
  if (span < 2.0) return (span / 2.0 * 0.3).clamp(0.0, 1.0);

  final res = resampleContour(trace, target.length);
  if (res.isEmpty) return 0;

  // Min-max normalize the resampled contour to 0..1 (shape-only).
  var lo = res.first, hi = res.first;
  for (final x in res) {
    if (x < lo) lo = x;
    if (x > hi) hi = x;
  }
  final range = hi - lo;
  if (range <= 0) return 0;
  final norm = res.map((x) => (x - lo) / range).toList();

  // Mean absolute deviation from the target shape → score.
  var mad = 0.0;
  for (var i = 0; i < target.length; i++) {
    mad += (norm[i] - target[i]).abs();
  }
  mad /= target.length;
  // Perfect match mad≈0 → 1; an inverted contour mad≈0.5 → 0.
  return (1 - 2 * mad).clamp(0.0, 1.0);
}
