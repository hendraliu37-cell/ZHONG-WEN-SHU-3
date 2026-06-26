import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/srs/fsrs.dart';

void main() {
  group('FSRS scheduler', () {
    const fsrs = Fsrs();

    test('a new card graded Good gets positive stability and a future due', () {
      final s = fsrs.review(SrsState(), Grade.good);
      expect(s.isNew, isFalse);
      expect(s.reps, 1);
      expect(s.stability, greaterThan(0));
      expect(s.due.isAfter(DateTime.now()), isTrue);
      expect(s.mastery, inInclusiveRange(0, 3));
    });

    test('a new card graded Again comes back very soon (same-day relearn)', () {
      final s = fsrs.review(SrsState(), Grade.again);
      expect(s.due.difference(DateTime.now()).inMinutes, lessThanOrEqualTo(15));
    });

    test('repeated Good reviews increase stability', () {
      var s = fsrs.review(SrsState(), Grade.good);
      final firstStability = s.stability;
      // simulate the next review happening at its due date
      s = fsrs.review(s, Grade.good, now: s.due);
      expect(s.stability, greaterThan(firstStability));
      expect(s.reps, 2);
    });

    test('mastery buckets follow stability thresholds', () {
      expect(SrsState().mastery, 0); // never reviewed
      expect(SrsState(stability: 3, reps: 1, isNew: false).mastery, 1);
      expect(SrsState(stability: 14, reps: 2, isNew: false).mastery, 2);
      expect(SrsState(stability: 60, reps: 5, isNew: false).mastery, 3);
    });
  });
}
