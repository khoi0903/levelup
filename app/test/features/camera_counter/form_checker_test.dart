import 'package:fitness_app/features/camera_counter/domain/camera_counter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'synthetic_pose.dart';

DetectedRep rep(int index, double deepestAngle) => DetectedRep(
  repIndex: index,
  startedAt: Duration.zero,
  completedAt: const Duration(seconds: 1),
  deepestAngle: deepestAngle,
  averageConfidence: 0.9,
);

void main() {
  const checker = FormChecker();

  test('10 standard squats have no depth issues and score 100', () {
    final session = SyntheticSession()..arm();
    for (var i = 0; i < 10; i++) {
      session.squat();
    }
    final form = checker.checkSquats(session.counter.result.reps);
    expect(form.issues, isEmpty);
    expect(form.formScore, 100);
  });

  test('3 shallow squats produce 3 indexed shallow_depth issues', () {
    // 105-degree squats cannot cross the example downBelow=95 threshold.
    // A wider detection threshold permits depth assessment on these reps.
    final session = SyntheticSession(config: squatConfig(downBelow: 120))
      ..arm();
    for (var i = 0; i < 3; i++) {
      session.squat(deepestAngle: 105);
    }
    final result = session.counter.result;
    expect(result.repCount, 3);
    final form = checker.checkSquats(result.reps);
    expect(form.issues.length, 3);
    expect(form.issues.map((issue) => issue.repIndex), [1, 2, 3]);
    expect(
      form.issues.map((issue) => issue.code),
      everyElement('shallow_depth'),
    );
    expect(form.issues.map((issue) => issue.severity), everyElement(1));
    expect(form.formScore, 90);
    expect(form.issues.first.toJson(), {
      'repIndex': 1,
      'code': 'shallow_depth',
      'severity': 1,
    });
  });

  test('strict depth boundary and all three severity levels', () {
    final form = checker.checkSquats([
      rep(1, 80),
      rep(2, 100),
      rep(3, 100.1),
      rep(4, 110),
      rep(5, 110.1),
      rep(6, 120),
      rep(7, 120.1),
      rep(8, 180),
    ]);
    expect(form.issues.map((issue) => issue.repIndex), [3, 4, 5, 6, 7, 8]);
    expect(form.issues.map((issue) => issue.severity), [1, 1, 2, 2, 3, 3]);
    expect(form.formScore, 85);
  });

  test('score averages penalties rather than penalizing workout length', () {
    final short = checker.checkSquats([rep(1, 80), rep(2, 115)]);
    final long = checker.checkSquats([
      rep(1, 80),
      rep(2, 115),
      rep(3, 80),
      rep(4, 115),
    ]);
    expect(short.formScore, 90);
    expect(long.formScore, short.formScore);
    expect(checker.checkSquats([rep(1, 150)]).formScore, 70);
  });

  test('no reps have no issues; issue snapshots cannot be changed', () {
    final empty = checker.checkSquats([]);
    expect(empty.issues, isEmpty);
    expect(empty.formScore, 100);
    final input = [rep(1, 115)];
    final result = checker.checkSquats(input);
    input.clear();
    expect(result.issues.length, 1);
    expect(() => result.issues.clear(), throwsUnsupportedError);
  });

  test('partial or too-fast squats do not create form issues', () {
    final session = SyntheticSession(config: squatConfig(downBelow: 120))
      ..arm();
    session.feed(115);
    session.feed(105);
    session.feed(170);
    session.feed(175);
    expect(session.counter.result.repCount, 0);
    expect(checker.checkSquats(session.counter.result.reps).issues, isEmpty);
  });
}
