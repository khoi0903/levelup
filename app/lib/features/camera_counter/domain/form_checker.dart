import 'cv_config.dart';
import 'form_rule.dart';
import 'rep_counter.dart';

class FormIssue {
  const FormIssue({
    required this.repIndex,
    required this.code,
    required this.severity,
  }) : assert(repIndex > 0),
       assert(severity >= 1 && severity <= 3);

  /// Lần tập bị lỗi (từ 1). Bài giữ (hold) luôn dùng 1 cho cả hiệp.
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

/// Áp các luật `CvConfig.formRules` lên kết quả đếm.
///
/// Mỗi lỗi trừ `10 * severity` điểm. Chế độ reps:
/// `formScore = round(100 - tổng điểm trừ / repCount)`; chế độ hold: cả hiệp
/// là một đơn vị (`repIndex` 1), `formScore = 100 - tổng điểm trừ`.
/// Kẹp trong 0–100. Chưa có lần nào / chưa giữ giây nào → 100, không lỗi;
/// UI dùng repCount / holdDuration để phân biệt hiệp trống.
///
/// Luật squat cũ (`shallow_depth`): góc gối sâu nhất >100° là lỗi, mức 1 tới
/// 110°, mức 2 tới 120°, mức 3 trên 120°. Cấu hình hông–gối–cổ chân không
/// khai báo formRules tự dùng luật này.
class FormChecker {
  const FormChecker();

  /// Giữ cho mã cũ: luật squat `shallow_depth` mặc định.
  FormCheckResult checkSquats(Iterable<DetectedRep> reps) =>
      _checkReps([FormRule.legacySquat()], reps);

  FormCheckResult check(CvConfig config, RepCounterResult result) {
    if (config.isHold) return _checkHold(config, result);
    return _checkReps(config.formRules, result.reps);
  }

  FormCheckResult _checkReps(List<FormRule> rules, Iterable<DetectedRep> reps) {
    final issues = <FormIssue>[];
    var repCount = 0;
    var totalPenalty = 0;
    for (final rep in reps) {
      repCount++;
      for (final rule in rules) {
        final severity = _repSeverity(rule, rep);
        if (severity == null) continue;
        issues.add(
          FormIssue(
            repIndex: rep.repIndex,
            code: rule.code,
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

  int? _repSeverity(FormRule rule, DetectedRep rep) {
    final AngleRange? range;
    if (rule.joints == null) {
      range = AngleRange(rep.deepestAngle, rep.peakAngle ?? rep.deepestAngle);
    } else {
      // Bộ khớp phụ không đo được trong lần này thì không chấm.
      range = rep.angleRanges[tripletKey(rule.joints!)];
    }
    if (range == null) return null;
    final s = rule.severity;
    switch (rule.type) {
      case FormRuleType.minDepth:
        final deepest = range.min;
        if (deepest <= rule.angle!) return null;
        return deepest <= s[0] ? 1 : (deepest <= s[1] ? 2 : 3);
      case FormRuleType.maxExtreme:
        if (rule.joints == null && rep.peakAngle == null) return null;
        final peak = range.max;
        if (peak >= rule.angle!) return null;
        return peak >= s[0] ? 1 : (peak >= s[1] ? 2 : 3);
      case FormRuleType.band:
        final deviation = [
          rule.min! - range.min,
          range.max - rule.max!,
        ].reduce((a, b) => a > b ? a : b);
        if (deviation <= 0) return null;
        return deviation <= s[0] ? 1 : (deviation <= s[1] ? 2 : 3);
    }
  }

  FormCheckResult _checkHold(CvConfig config, RepCounterResult result) {
    final held = result.holdDuration.inMicroseconds;
    if (held <= 0) return FormCheckResult._(issues: const [], formScore: 100);
    final issues = <FormIssue>[];
    var totalPenalty = 0;
    for (var i = 0; i < config.formRules.length; i++) {
      final rule = config.formRules[i];
      if (rule.type != FormRuleType.band) continue;
      final outside = i < result.holdOutsideByRule.length
          ? result.holdOutsideByRule[i].inMicroseconds
          : 0;
      final fraction = outside / held;
      if (fraction <= rule.minFraction) continue;
      final s = rule.severity;
      final severity = fraction <= s[0] ? 1 : (fraction <= s[1] ? 2 : 3);
      issues.add(FormIssue(repIndex: 1, code: rule.code, severity: severity));
      totalPenalty += 10 * severity;
    }
    return FormCheckResult._(
      issues: issues,
      formScore: (100 - totalPenalty).clamp(0, 100),
    );
  }
}
