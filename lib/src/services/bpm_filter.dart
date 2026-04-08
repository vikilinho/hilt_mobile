/// Pure PPG signal-processing logic extracted from [CameraBpmScreen].
///
/// All methods are static so the entire filtering pipeline can be unit-tested
/// without any widget or platform-channel scaffolding.
class BpmFilter {
  BpmFilter._(); // prevent instantiation

  /// Readings required to fill the progress ring completely.
  static const int bufferTarget = 30;

  /// Readings before the "LOCK IN" button can appear (~80% of [bufferTarget]).
  static const int lockThreshold = 24;

  /// How many of the most-recent readings to examine for the stability check.
  static const int stabilityWindow = 5;

  /// Maximum relative deviation from the median considered stable (±10%).
  ///
  /// Real PPG-derived BPM has natural beat-to-beat variability of ±8–12%.
  /// A 5% band was too strict and caused lock-in to fire only on coincidental
  /// clusters rather than genuine steady-state readings.
  static const double stabilityTolerance = 0.10;

  /// Initial readings to discard at the start of each finger placement.
  ///
  /// The camera's auto-exposure takes a few frames to settle, producing
  /// unreliable values that should never enter the median buffer.
  static const int warmupReadings = 5;

  /// Maximum BPM deviation from the current median before a reading is
  /// classified as a motion artefact and rejected pre-buffer.
  ///
  /// If the buffer is not yet established (fewer than 5 readings) no gate is
  /// applied — any in-range value is tentatively accepted.
  static const int maxOutlierDeviation = 25;

  // ───────────────────────────────────────────────────────────────────────────
  // Core algorithms
  // ───────────────────────────────────────────────────────────────────────────

  /// Returns the **median** of [values].
  ///
  /// * Odd-length list  → true middle element.
  /// * Even-length list → integer average of the two middle elements.
  /// * Empty list       → 0.
  ///
  /// Because the median ignores extreme values, a single rogue spike (e.g. 200
  /// caused by finger movement) does not bias the reported heart rate.
  static int medianOf(List<int> values) {
    if (values.isEmpty) return 0;
    final sorted = List<int>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : ((sorted[mid - 1] + sorted[mid]) ~/ 2);
  }

  /// Returns the current median of the full [readings] buffer. 0 if empty.
  static int currentMedian(List<int> readings) => medianOf(readings);

  /// Returns `true` if the last [window] readings are all within
  /// ±[tolerance] of their own median.
  ///
  /// This confirms the signal has stabilised and is not actively spiking due
  /// to finger movement.
  static bool isStable(
    List<int> readings, {
    int window = stabilityWindow,
    double tolerance = stabilityTolerance,
  }) {
    if (readings.length < window) return false;
    final recent = readings.sublist(readings.length - window);
    final median = medianOf(recent);
    if (median == 0) return false;
    final band = median * tolerance;
    return recent.every((r) => (r - median).abs() <= band);
  }

  /// Returns `true` when the buffer has enough stable readings to lock in.
  static bool canLock(List<int> readings) =>
      readings.length >= lockThreshold && isStable(readings);

  // ───────────────────────────────────────────────────────────────────────────
  // Pre-buffer artefact gate
  // ───────────────────────────────────────────────────────────────────────────

  /// Returns `true` if [bpm] is plausible given the readings already buffered.
  ///
  /// A value is rejected when there is enough prior history to form a reliable
  /// median and the new value deviates from that median by more than
  /// [maxOutlierDeviation] BPM.  This catches motion artefact spikes (e.g.
  /// finger shifting) that the physiological range check alone misses.
  static bool isPlausibleReading(int bpm, List<int> buffered) {
    if (buffered.length < 5) return true; // too early to have a reference median
    final med = medianOf(buffered);
    return (bpm - med).abs() <= maxOutlierDeviation;
  }
}
