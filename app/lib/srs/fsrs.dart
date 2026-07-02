import 'dart:math' as math;

/// FSRS grades. The UI only ever surfaces two buttons (Salah / Benar), mapped
/// per the backend handoff: Salah → again, Benar → good. Hard/Easy stay
/// internally supported so the scheduler is a drop-in for a richer UI later.
enum Grade {
  again(1),
  hard(2),
  good(3),
  easy(4);

  final int value;
  const Grade(this.value);
}

/// Per-(user×card) scheduling state.
class SrsState {
  double stability;
  double difficulty;
  DateTime due;
  DateTime? lastReview;
  int reps;
  int lapses;
  bool isNew;

  SrsState({
    this.stability = 0,
    this.difficulty = 0,
    DateTime? due,
    this.lastReview,
    this.reps = 0,
    this.lapses = 0,
    this.isNew = true,
  }) : due = due ?? DateTime.now();

  /// Mastery bucket (0–3) → drives the deck list colour code (handoff §2).
  /// 0 Baru · 1 Perlu latihan · 2 Cukup · 3 Mahir.
  int get mastery {
    if (reps == 0) return 0;
    if (stability < 7) return 1;
    if (stability < 30) return 2;
    return 3;
  }

  bool isDue(DateTime now) => !isNew && !due.isAfter(now);

  Map<String, dynamic> toJson() => {
    's': stability,
    'd': difficulty,
    'due': due.toIso8601String(),
    'last': lastReview?.toIso8601String(),
    'reps': reps,
    'lapses': lapses,
    'new': isNew,
  };

  factory SrsState.fromJson(Map<String, dynamic> j) => SrsState(
    stability: _doubleOf(j['s'], min: 0),
    difficulty: _doubleOf(j['d'], min: 0),
    due: _dateOf(j['due']) ?? DateTime.now(),
    lastReview: _dateOf(j['last']),
    reps: _intOf(j['reps'], min: 0),
    lapses: _intOf(j['lapses'], min: 0),
    isNew: _boolOf(j['new'], fallback: false),
  );
}

double _doubleOf(Object? value, {double min = double.negativeInfinity}) {
  double? parsed;
  if (value is num) {
    parsed = value.toDouble();
  } else if (value is String) {
    parsed = double.tryParse(value.trim());
  }
  if (parsed == null || parsed.isNaN || parsed.isInfinite) return min;
  return parsed < min ? min : parsed;
}

int _intOf(Object? value, {int min = -0x7fffffffffffffff}) {
  int? parsed;
  if (value is int) {
    parsed = value;
  } else if (value is num) {
    parsed = value.toInt();
  } else if (value is String) {
    final text = value.trim();
    parsed = int.tryParse(text) ?? double.tryParse(text)?.toInt();
  }
  if (parsed == null) return min;
  return parsed < min ? min : parsed;
}

bool _boolOf(Object? value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final text = value.trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
  }
  return fallback;
}

DateTime? _dateOf(Object? value) {
  if (value is DateTime) return value;
  if (value is! String) return null;
  return DateTime.tryParse(value.trim());
}

/// FSRS-4.5 scheduler (pure Dart, offline). Implements the canonical
/// difficulty/stability update equations with the published default weights.
class Fsrs {
  // Default FSRS-4.5 weights.
  static const List<double> w = [
    0.4197, 1.1869, 3.0412, 15.2441, 7.1434, 0.6477, 1.0007, 0.0674, //
    1.6597, 0.1712, 1.1178, 2.0225, 0.0904, 0.3025, 2.1214, 0.2498, 2.9466,
  ];

  static const double decay = -0.5;
  static double get factor => math.pow(0.9, 1 / decay) - 1; // = 19/81

  final double requestRetention;
  final double maximumIntervalDays;

  const Fsrs({this.requestRetention = 0.9, this.maximumIntervalDays = 36500});

  double _clampD(double d) => d.clamp(1.0, 10.0);

  double _initDifficulty(int g) => _clampD(w[4] - math.exp(w[5] * (g - 1)) + 1);

  double _initStability(int g) => math.max(w[g - 1], 0.1);

  double _nextDifficulty(double d, int g) {
    final next = d + w[6] * (g - 3);
    // mean reversion toward the "easy" baseline difficulty
    return _clampD(w[7] * _initDifficulty(4) + (1 - w[7]) * next);
  }

  /// Retrievability after [elapsedDays] given [stability].
  double retrievability(double elapsedDays, double stability) {
    if (stability <= 0) return 0;
    return math.pow(1 + factor * elapsedDays / stability, decay).toDouble();
  }

  double _nextStabilityRecall(double d, double s, double r, int g) {
    final hardPenalty = g == Grade.hard.value ? w[15] : 1.0;
    final easyBonus = g == Grade.easy.value ? w[16] : 1.0;
    final inc =
        math.exp(w[8]) *
        (11 - d) *
        math.pow(s, -w[9]) *
        (math.exp(w[10] * (1 - r)) - 1) *
        hardPenalty *
        easyBonus;
    return s * (1 + inc);
  }

  double _nextStabilityForget(double d, double s, double r) {
    return w[11] *
        math.pow(d, -w[12]) *
        (math.pow(s + 1, w[13]) - 1) *
        math.exp(w[14] * (1 - r));
  }

  double _intervalDays(double stability) {
    final ivl =
        (stability / factor) * (math.pow(requestRetention, 1 / decay) - 1);
    return ivl.clamp(1.0, maximumIntervalDays);
  }

  /// Apply a [grade] to [prev] at [now], returning the updated state.
  SrsState review(SrsState prev, Grade grade, {DateTime? now}) {
    now ??= DateTime.now();
    final g = grade.value;
    final next = SrsState(
      stability: prev.stability,
      difficulty: prev.difficulty,
      due: prev.due,
      lastReview: now,
      reps: prev.reps + 1,
      lapses: prev.lapses,
      isNew: false,
    );

    if (prev.isNew || prev.reps == 0) {
      next.difficulty = _initDifficulty(g);
      next.stability = _initStability(g);
    } else {
      final elapsed = prev.lastReview == null
          ? 0.0
          : now.difference(prev.lastReview!).inSeconds / 86400.0;
      final r = retrievability(math.max(elapsed, 0), prev.stability);
      next.difficulty = _nextDifficulty(prev.difficulty, g);
      if (g == Grade.again.value) {
        next.lapses = prev.lapses + 1;
        next.stability = _nextStabilityForget(
          prev.difficulty,
          prev.stability,
          r,
        );
      } else {
        next.stability = _nextStabilityRecall(
          prev.difficulty,
          prev.stability,
          r,
          g,
        );
      }
    }

    next.stability = math.max(next.stability, 0.1);
    final ivl = _intervalDays(next.stability);
    // "Again" on a young card comes back the same day for a quick re-look.
    next.due = g == Grade.again.value
        ? now.add(const Duration(minutes: 10))
        : now.add(Duration(seconds: (ivl * 86400).round()));
    return next;
  }
}
