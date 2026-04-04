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

  /// Maximum relative deviation from the median that is considered stable (±5%).
  static const double stabilityTolerance = 0.05;

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
}
