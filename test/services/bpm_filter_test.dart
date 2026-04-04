import 'package:flutter_test/flutter_test.dart';
import 'package:hilt_mobile/src/services/bpm_filter.dart';

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  // medianOf — outlier rejection
  // ───────────────────────────────────────────────────────────────────────────
  group('BpmFilter.medianOf — outlier rejection', () {
    test(
        'ignores high (200) and low (10) outliers; returns median of clustered readings',
        () {
      // 8 readings tightly clustered around 70–72, one extreme high, one low.
      // sorted: [10, 70, 70, 70, 70, 71, 71, 71, 72, 200]
      // even-length (10) → average of indices 4&5 = (70+71)/2 = 70
      final readings = [70, 70, 71, 200, 70, 72, 10, 71, 70, 71];

      final result = BpmFilter.medianOf(readings);

      expect(result, 70,
          reason: 'Median should be 70, not biased by spike 200 or dip 10');
      expect(result, isNot(greaterThan(80)),
          reason: 'Upper outlier 200 must not inflate the result');
      expect(result, isNot(lessThan(60)),
          reason: 'Lower outlier 10 must not deflate the result');
    });

    test('odd-length list returns the exact middle element', () {
      // sorted: [65, 68, 70, 72, 75]  → middle index 2 → 70
      expect(BpmFilter.medianOf([65, 72, 70, 68, 75]), 70);
    });

    test('even-length list averages the two middle elements', () {
      // sorted: [60, 70, 80, 90] → (70 + 80) / 2 = 75
      expect(BpmFilter.medianOf([90, 60, 80, 70]), 75);
    });

    test('single element returns itself', () {
      expect(BpmFilter.medianOf([80]), 80);
    });

    test('empty list returns 0', () {
      expect(BpmFilter.medianOf([]), 0);
    });

    test('duplicate values return that value', () {
      expect(BpmFilter.medianOf([72, 72, 72, 72, 72]), 72);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // isStable — ±5 % stability window
  // ───────────────────────────────────────────────────────────────────────────
  group('BpmFilter.isStable — ±5% stability check', () {
    test('returns false when readings fewer than the stability window (5)', () {
      // 4 readings < stabilityWindow (5)
      expect(BpmFilter.isStable([70, 71, 72, 73]), isFalse);
    });

    test('returns true when all 5 readings are within ±5% of their median', () {
      // median = 70, band = 70 * 0.05 = 3.5
      // all values in [69, 70, 70, 71, 72] satisfy |v - 70| ≤ 3.5
      expect(BpmFilter.isStable([70, 70, 71, 69, 72]), isTrue);
    });

    test('returns false when one reading exceeds the ±5% band', () {
      // median = 70, band = 3.5 → 80 deviates by 10 > 3.5
      expect(BpmFilter.isStable([70, 70, 71, 69, 80]), isFalse);
    });

    test('examines only the LAST N readings from a longer buffer', () {
      // First 10 readings are wild; last 5 are tightly clustered around 75.
      // median of last 5: [74,74,75,75,76] → 75, band = 3.75.
      // All within range → isStable must be true.
      final readings = [
        40, 200, 38, 190, 42, 180, 50, 170, 60, 160,
        74, 75, 76, 74, 75,
      ];
      expect(BpmFilter.isStable(readings), isTrue);
    });

    test('returns false if a spike appears in the last 5 of an otherwise '
        'stable buffer', () {
      // 14 stable readings then 1 spike (160) in position 15
      final readings = List.filled(14, 70) + [160];
      expect(BpmFilter.isStable(readings), isFalse);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // canLock — combined threshold + stability gate
  // ───────────────────────────────────────────────────────────────────────────
  group('BpmFilter.canLock — threshold AND stability gate', () {
    test('returns false when reading count is below lockThreshold (24)', () {
      // 23 perfectly-stable readings → still must not unlock
      final readings = List.filled(23, 70);
      expect(BpmFilter.canLock(readings), isFalse,
          reason: '23 readings is one short of the 24-reading lock threshold');
    });

    test('returns false when count ≥ 24 but signal is unstable', () {
      // 19 stable readings + last 5 contain a spike → unstable
      final readings = List.filled(19, 70) + [70, 70, 70, 70, 160];
      expect(readings.length, BpmFilter.lockThreshold);
      expect(BpmFilter.canLock(readings), isFalse,
          reason: 'Spike in last 5 readings must prevent lock-in');
    });

    test('returns true when count ≥ 24 AND all last 5 are within ±5%', () {
      // 24 readings all exactly 72 → perfectly stable
      final readings = List.filled(24, 72);
      expect(BpmFilter.canLock(readings), isTrue);
    });

    test('returns true at 30 readings (full buffer) with stable signal', () {
      final readings = List.filled(30, 68);
      expect(BpmFilter.canLock(readings), isTrue);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // currentMedian — convenience wrapper
  // ───────────────────────────────────────────────────────────────────────────
  group('BpmFilter.currentMedian', () {
    test('returns 0 for empty buffer', () {
      expect(BpmFilter.currentMedian([]), 0);
    });

    test('returns median of all buffered readings', () {
      // sorted: [68, 70, 72] → 70
      expect(BpmFilter.currentMedian([72, 68, 70]), 70);
    });
  });
}
