import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// On-device microphone pitch detection for the tone tuner. Streams PCM16 from
/// the mic and runs autocorrelation per frame to estimate the fundamental
/// frequency (Hz). Reports the input level (RMS) too, so the UI can show whether
/// audio is actually arriving. Degrades gracefully (never crashes).
class PitchService {
  final AudioRecorder _rec = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  final List<double> _buf = [];
  bool _running = false;

  static const int _sampleRate = 16000;
  static const int _frame = 1024; // ~64ms

  bool get isRunning => _running;

  /// Starts capture. [onFrame] gets (hz | null, rms 0..1) per frame. Returns a
  /// status string: 'ok', 'ok(perm?)' (started despite hasPermission=false), or
  /// 'error: ...'. The status is surfaced in the UI for diagnosis.
  /// Available input devices (for the mic picker).
  Future<List<InputDevice>> devices() async {
    try {
      return await _rec.listInputDevices();
    } catch (_) {
      return [];
    }
  }

  Future<String> start(
    void Function(double? hz, double rms) onFrame, {
    InputDevice? device,
  }) async {
    if (_running) return 'ok';
    bool perm = false;
    try {
      perm = await _rec.hasPermission();
    } catch (_) {}
    try {
      final stream = await _rec.startStream(RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
        device: device,
        autoGain: true, // help quiet mics register
      ));
      _running = true;
      _buf.clear();
      _sub = stream.listen(
        (data) {
          // View-safe: read only this chunk's region, honouring offsetInBytes.
          final bd = ByteData.sublistView(data);
          final count = data.lengthInBytes ~/ 2;
          for (var i = 0; i < count; i++) {
            _buf.add(bd.getInt16(i * 2, Endian.little) / 32768.0);
          }
          while (_buf.length >= _frame) {
            final frame = _buf.sublist(0, _frame);
            _buf.removeRange(0, _frame ~/ 2); // 50% overlap
            final rms = _rms(frame);
            onFrame(_detect(frame, rms), rms);
          }
        },
        onError: (e) {
          if (kDebugMode) debugPrint('[pitch] stream error: $e');
        },
        cancelOnError: false,
      );
      return perm ? 'ok' : 'ok(perm?)';
    } catch (e) {
      _running = false;
      if (kDebugMode) debugPrint('[pitch] start failed: $e');
      return 'error: $e';
    }
  }

  Future<void> stop() async {
    _running = false;
    _buf.clear();
    await _sub?.cancel();
    _sub = null;
    try {
      await _rec.stop();
    } catch (_) {}
  }

  void dispose() {
    _sub?.cancel();
    _rec.dispose();
  }

  static double _rms(List<double> x) {
    double e = 0;
    for (final v in x) {
      e += v * v;
    }
    return math.sqrt(e / x.length);
  }

  /// Pitch detection via the McLeod Pitch Method (NSDF + peak picking) over a
  /// normalized (-1..1) sample frame. Unlike plain autocorrelation (which often
  /// locks onto a multiple of the period → octave-down errors), MPM picks the
  /// first *significant* peak of the normalized square difference function, so
  /// the octave is right. Returns the fundamental in Hz, or null if unvoiced.
  static double? _detect(List<double> x, double rms) {
    if (rms < 0.010) return null; // silence gate
    final n = x.length;
    double mean = 0;
    for (final v in x) {
      mean += v;
    }
    mean /= n;
    final s = List<double>.generate(n, (i) => x[i] - mean);

    const minHz = 70.0, maxHz = 500.0;
    final minLag = (_sampleRate / maxHz).floor();
    final maxLag = math.min((_sampleRate / minHz).ceil(), n - 1);

    // Normalized square difference function: nsdf[tau] = 2·r(tau) / m(tau),
    // bounded in [-1, 1]; a value near 1 at lag tau means a strong period there.
    final nsdf = List<double>.filled(maxLag + 1, 0);
    for (var tau = 0; tau <= maxLag; tau++) {
      double acf = 0, m = 0;
      for (var i = 0; i < n - tau; i++) {
        acf += s[i] * s[i + tau];
        m += s[i] * s[i] + s[i + tau] * s[i + tau];
      }
      nsdf[tau] = m > 0 ? 2 * acf / m : 0;
    }

    // Skip the zero-lag main lobe: advance to the first zero crossing.
    var tau = 1;
    while (tau <= maxLag && nsdf[tau] > 0) {
      tau++;
    }

    // Collect the maximum of each positive region (the "key maxima").
    final maxima = <int>[];
    var searching = false;
    var curMax = 0.0;
    var curPos = -1;
    for (; tau <= maxLag; tau++) {
      final prev = nsdf[tau - 1];
      if (nsdf[tau] > 0 && prev <= 0) {
        searching = true;
        curMax = nsdf[tau];
        curPos = tau;
      } else if (nsdf[tau] <= 0 && prev > 0) {
        if (searching && curPos >= 0) maxima.add(curPos);
        searching = false;
        curPos = -1;
      } else if (searching && nsdf[tau] > curMax) {
        curMax = nsdf[tau];
        curPos = tau;
      }
    }
    if (searching && curPos >= 0) maxima.add(curPos);
    if (maxima.isEmpty) return null;

    // Highest key maximum gauges voicing; the chosen period is the *first* peak
    // that reaches 0.9× of it (kills octave errors), within the legal lag band.
    double highest = 0;
    for (final p in maxima) {
      if (nsdf[p] > highest) highest = nsdf[p];
    }
    if (highest < 0.5) return null; // clarity gate
    final threshold = highest * 0.9;
    var chosen = -1;
    for (final p in maxima) {
      if (nsdf[p] >= threshold && p >= minLag && p <= maxLag) {
        chosen = p;
        break;
      }
    }
    if (chosen < 0) return null;

    // Parabolic interpolation around the chosen peak for sub-sample precision.
    double refined = chosen.toDouble();
    if (chosen > 0 && chosen < maxLag) {
      final y0 = nsdf[chosen - 1], y1 = nsdf[chosen], y2 = nsdf[chosen + 1];
      final denom = (y0 - 2 * y1 + y2);
      if (denom != 0) refined = chosen + 0.5 * (y0 - y2) / denom;
    }
    return _sampleRate / refined;
  }

  /// Test hook: run the detector over a prepared sample frame. Lets unit tests
  /// feed synthetic signals (known Hz) without a microphone.
  @visibleForTesting
  static double? detectForTest(List<double> x, double rms) => _detect(x, rms);

  @visibleForTesting
  static int get frameSize => _frame;

  @visibleForTesting
  static int get sampleRate => _sampleRate;
}
