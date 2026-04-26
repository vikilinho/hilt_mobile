import 'dart:math';

class SignalProcessor {
  SignalProcessor._();

  static const double lowCutHz = 0.75;
  static const double highCutHz = 4.0;

  static List<double> bandpassFilter(List<double> signal, double sampleRateHz) {
    if (signal.length < 4 || sampleRateHz <= 0) return List<double>.from(signal);
    final highPassed = _highPassFilter(signal, lowCutHz, sampleRateHz);
    return _lowPassFilter(highPassed, highCutHz, sampleRateHz);
  }

  static List<double> _highPassFilter(
    List<double> signal,
    double cutoffHz,
    double sampleRateHz,
  ) {
    final rc = 1.0 / (2 * pi * cutoffHz);
    final dt = 1.0 / sampleRateHz;
    final alpha = rc / (rc + dt);
    final output = List<double>.filled(signal.length, 0.0);
    output[0] = signal[0];
    for (int i = 1; i < signal.length; i++) {
      output[i] = alpha * (output[i - 1] + signal[i] - signal[i - 1]);
    }
    return output;
  }

  static List<double> _lowPassFilter(
    List<double> signal,
    double cutoffHz,
    double sampleRateHz,
  ) {
    final rc = 1.0 / (2 * pi * cutoffHz);
    final dt = 1.0 / sampleRateHz;
    final alpha = dt / (rc + dt);
    final output = List<double>.filled(signal.length, 0.0);
    output[0] = signal[0];
    for (int i = 1; i < signal.length; i++) {
      output[i] = alpha * signal[i] + (1 - alpha) * output[i - 1];
    }
    return output;
  }

  /// Detects positive peaks in [signal].
  ///
  /// [sampleRateHz] is used to enforce a physiological minimum inter-peak
  /// distance: no two heartbeats can be closer than 60 / 220 BPM ≈ 0.27 s.
  /// Passing the actual sample rate prevents spurious double-detections that
  /// previously occurred when [sampleRateHz] was high (≥ 60 fps) but the
  /// hard-coded minimum distance of 5 samples was kept unchanged.
  static List<int> detectPeaks(
    List<double> signal, {
    double sampleRateHz = 30.0,
  }) {
    if (signal.length < 5) return [];
    // 220 BPM is the physiological ceiling → minimum interval = 60/220 s.
    final minDist = (sampleRateHz * 60 / 220).ceil().clamp(3, 60);

    final peaks = <int>[];
    final mean = signal.reduce((a, b) => a + b) / signal.length;
    final variance = signal
            .map((v) => pow(v - mean, 2))
            .reduce((a, b) => a + b) /
        signal.length;
    final stdDev = sqrt(variance);
    final threshold = mean + 0.3 * stdDev;

    for (int i = 2; i < signal.length - 2; i++) {
      final value = signal[i];
      if (value > threshold &&
          value > signal[i - 1] &&
          value > signal[i - 2] &&
          value > signal[i + 1] &&
          value > signal[i + 2]) {
        if (peaks.isEmpty || (i - peaks.last) >= minDist) {
          peaks.add(i);
        }
      }
    }

    return peaks;
  }

  static double? calculateBpmFromPeaks(
    List<int> peakIndices,
    double sampleRateHz,
  ) {
    if (peakIndices.length < 3 || sampleRateHz <= 0) return null;
    double totalInterval = 0;
    for (int i = 1; i < peakIndices.length; i++) {
      totalInterval += peakIndices[i] - peakIndices[i - 1];
    }
    final avgInterval = totalInterval / (peakIndices.length - 1);
    final avgIntervalSec = avgInterval / sampleRateHz;
    if (avgIntervalSec <= 0) return null;
    final bpm = 60.0 / avgIntervalSec;
    return (bpm >= 40 && bpm <= 220) ? bpm : null;
  }

  static double? calculateBpmFromFft(
    List<double> signal,
    double sampleRateHz,
  ) {
    final n = signal.length;
    if (n < 32 || sampleRateHz <= 0) return null;

    final fftSize = _nextPow2(n);

    // Apply Hann window and zero-pad into complex arrays.
    final re = List<double>.filled(fftSize, 0.0);
    final im = List<double>.filled(fftSize, 0.0);
    final windowDenom = fftSize > 1 ? fftSize - 1 : 1;
    for (int i = 0; i < n; i++) {
      final w = 0.5 * (1 - cos(2 * pi * i / windowDenom));
      re[i] = signal[i] * w;
    }

    // O(N log N) Cooley-Tukey radix-2 in-place FFT.
    _fftInPlace(re, im, fftSize);

    // Find the bin with peak power inside the cardiac band.
    double maxPower = 0;
    double dominantFreq = 0;
    final halfN = fftSize ~/ 2;

    for (int k = 1; k < halfN; k++) {
      final frequency = k * sampleRateHz / fftSize;
      if (frequency < lowCutHz || frequency > highCutHz) continue;
      final power = re[k] * re[k] + im[k] * im[k];
      if (power > maxPower) {
        maxPower = power;
        dominantFreq = frequency;
      }
    }

    if (dominantFreq == 0) return null;
    final bpm = dominantFreq * 60;
    return (bpm >= 40 && bpm <= 220) ? bpm : null;
  }

  /// Cooley-Tukey radix-2 DIT FFT (in-place).
  ///
  /// [re] and [im] must both have length equal to a power of two.
  /// On return they contain the complex DFT output.
  static void _fftInPlace(List<double> re, List<double> im, int n) {
    // Bit-reversal permutation.
    for (int i = 1, j = 0; i < n; i++) {
      int bit = n >> 1;
      for (; (j & bit) != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        var t = re[i]; re[i] = re[j]; re[j] = t;
        t = im[i]; im[i] = im[j]; im[j] = t;
      }
    }

    // Butterfly stages — twiddle factors computed once per stage length,
    // then rotated incrementally, avoiding cos/sin inside the inner loop.
    for (int len = 2; len <= n; len <<= 1) {
      final half = len >> 1;
      final baseRe = cos(-2 * pi / len);
      final baseIm = sin(-2 * pi / len);
      for (int i = 0; i < n; i += len) {
        double wRe = 1.0;
        double wIm = 0.0;
        for (int k = 0; k < half; k++) {
          final uRe = re[i + k];
          final uIm = im[i + k];
          final vRe = re[i + k + half] * wRe - im[i + k + half] * wIm;
          final vIm = re[i + k + half] * wIm + im[i + k + half] * wRe;
          re[i + k] = uRe + vRe;
          im[i + k] = uIm + vIm;
          re[i + k + half] = uRe - vRe;
          im[i + k + half] = uIm - vIm;
          // Rotate the twiddle factor — no trig in the inner loop.
          final newWRe = wRe * baseRe - wIm * baseIm;
          wIm = wRe * baseIm + wIm * baseRe;
          wRe = newWRe;
        }
      }
    }
  }

  static List<double> normalise(List<double> signal) {
    if (signal.isEmpty) return const [];
    final minValue = signal.reduce(min);
    final maxValue = signal.reduce(max);
    final range = maxValue - minValue;
    if (range == 0) {
      return signal.map((_) => 0.0).toList(growable: false);
    }
    return signal
        .map((value) => ((value - minValue) / range) * 2 - 1)
        .toList(growable: false);
  }

  static double smoothBpmEstimates(
    List<int> estimates, {
    double alpha = 0.35,
  }) {
    if (estimates.isEmpty) return 0;

    final median = _medianAsDouble(estimates);
    double smoothed = median;
    for (final estimate in estimates) {
      final clamped = estimate.toDouble().clamp(median - 12, median + 12);
      smoothed = alpha * clamped + (1 - alpha) * smoothed;
    }
    return smoothed;
  }

  static double _medianAsDouble(List<int> values) {
    if (values.isEmpty) return 0;
    final sorted = List<int>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid].toDouble()
        : (sorted[mid - 1] + sorted[mid]) / 2.0;
  }

  static int _nextPow2(int n) {
    int power = 1;
    while (power < n) {
      power <<= 1;
    }
    return power;
  }
}
