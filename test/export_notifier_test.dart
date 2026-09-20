import 'package:bitmapper/services/export_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nextNotifiedPercent', () {
    test('reports the first call even at 0%', () {
      expect(nextNotifiedPercent(0, 10, null), 0);
    });

    test('reports a new percent when it changes', () {
      expect(nextNotifiedPercent(1, 10, 0), 10);
      expect(nextNotifiedPercent(5, 10, 10), 50);
      expect(nextNotifiedPercent(10, 10, 90), 100);
    });

    test('returns null when the displayed percent has not changed', () {
      // 10 done out of 1000 stays at 1% for the next several ticks.
      expect(nextNotifiedPercent(10, 1000, 1), null);
      expect(nextNotifiedPercent(11, 1000, 1), null);
      expect(nextNotifiedPercent(19, 1000, 1), null);
      expect(nextNotifiedPercent(20, 1000, 1), 2);
    });

    test('an unknown total (<= 0) reports 0 once, then stays quiet', () {
      expect(nextNotifiedPercent(0, 0, null), 0);
      expect(nextNotifiedPercent(0, 0, 0), null);
      expect(nextNotifiedPercent(0, -1, 0), null);
    });

    test('clamps to 100 even if done somehow exceeds total', () {
      expect(nextNotifiedPercent(12, 10, 90), 100);
    });
  });
}
