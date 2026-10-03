import 'rep_counter.dart';

class FormIssue {
  const FormIssue({
    required this.repIndex,
    required this.code,
    required this.severity,
  }) : assert(repIndex > 0),
       assert(severity >= 1 && severity <= 3);

  final int repIndex;
  final String code;
  final int severity;

  Map<String, dynamic> toJson() => {
    'repIndex': repIndex,
    'code': code,
    'severity': severity,
  };
}

class FormCheckResult {
  FormCheckResult._({
    required Iterable<FormIssue> issues,
    required this.formScore,
  }) : issues = List.unmodifiable(issues);

  final List<FormIssue> issues;
  final int formScore;
}

/// Squat depth rules for completed reps measured at the knee.
///
/// A deepest angle >100 degrees gives one shallow_depth issue. Severity is 1
/// up to 110 degrees, 2 up to 120 degrees, and 3 above 120 degrees.
/// Score = 100 minus the mean per-rep penalty (10 * severity), rounded.
/// Empty input returns 100 (no recorded issues), not proof of good form.
///
/// With downBelow <=100, every counted squat already passes the depth rule.
/// To assess shallow completed reps too, use a wider exercise threshold such
/// as downBelow=120. This checker does not invent reps rejected by the counter.
class FormChecker {
  const FormChecker();

  FormCheckResult checkSquats(Iterable<DetectedRep> reps) {
    final issues = <FormIssue>[];
    var repCount = 0;
    var totalPenalty = 0;
    for (final rep in reps) {
      repCount++;
      if (rep.deepestAngle > 100) {
        final severity = rep.deepestAngle <= 110
            ? 1
            : rep.deepestAngle <= 120
            ? 2
            : 3;
        issues.add(
          FormIssue(
            repIndex: rep.repIndex,
            code: 'shallow_depth',
            severity: severity,
          ),
        );
        totalPenalty += 10 * severity;
      }
    }
    final score = repCount == 0
        ? 100
        : (100 - totalPenalty / repCount).round().clamp(0, 100);
    return FormCheckResult._(issues: issues, formScore: score);
  }
}
