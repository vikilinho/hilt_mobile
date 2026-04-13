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

  static List<int> detectPeaks(List<double> signal) {
    if (signal.length < 5) return [];
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
        if (peaks.isEmpty || (i - peaks.last) > 5) {
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
    final padded = List<double>.filled(fftSize, 0.0);
    for (int i = 0; i < n; i++) {
      padded[i] = signal[i];
    }

    final windowed = List<double>.generate(fftSize, (i) {
      final window = 0.5 * (1 - cos(2 * pi * i / (fftSize - 1)));
      return padded[i] * window;
    });

    double maxMagnitude = 0;
    double dominantFreq = 0;
    final halfN = fftSize ~/ 2;

    for (int k = 1; k < halfN; k++) {
      final frequency = k * sampleRateHz / fftSize;
      if (frequency < lowCutHz || frequency > highCutHz) continue;

      double real = 0;
      double imag = 0;
      for (int i = 0; i < fftSize; i++) {
        final angle = 2 * pi * k * i / fftSize;
        real += windowed[i] * cos(angle);
        imag -= windowed[i] * sin(angle);
      }

      final magnitude = sqrt(real * real + imag * imag);
      if (magnitude > maxMagnitude) {
        maxMagnitude = magnitude;
        dominantFreq = frequency;
      }
    }

    if (dominantFreq == 0) return null;
    final bpm = dominantFreq * 60;
    return (bpm >= 40 && bpm <= 220) ? bpm : null;
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
