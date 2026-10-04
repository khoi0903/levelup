import 'pose.dart';

/// Loại luật tư thế, đọc từ `formRules[].type`.
enum FormRuleType {
  /// Mỗi lần: góc nhỏ nhất (điểm sâu nhất) phải `<= angle`.
  /// Ví dụ squat/hít đất chưa đủ sâu.
  minDepth('min_depth'),

  /// Mỗi lần: góc lớn nhất (điểm cao nhất) phải `>= angle`.
  /// Ví dụ đẩy tạ chưa duỗi hết tay, cầu mông chưa nâng đủ hông.
  maxExtreme('max_extreme'),

  /// Góc phải nằm trong [min, max]. Chế độ reps: xét từng lần, mức lỗi theo
  /// số độ lệch ra ngoài. Chế độ hold: xét tỉ lệ thời gian giữ bị lệch.
  band('band');

  const FormRuleType(this.jsonName);
  final String jsonName;
}

/// Một luật tư thế trong `CvConfig.formRules`.
///
/// `severity` gồm hai mốc chia mức lỗi 1/2/3:
/// - min_depth: góc sâu nhất `<= severity[0]` → 1, `<= severity[1]` → 2, còn lại 3
///   (yêu cầu `angle < severity[0] < severity[1]`).
/// - max_extreme: góc cao nhất `>= severity[0]` → 1, `>= severity[1]` → 2,
///   còn lại 3 (yêu cầu `angle > severity[0] > severity[1]`).
/// - band, chế độ reps: số độ lệch `<= severity[0]` → 1, `<= severity[1]` → 2.
/// - band, chế độ hold: tỉ lệ thời gian lệch `> minFraction` mới có lỗi;
///   `<= severity[0]` → 1, `<= severity[1]` → 2, còn lại 3 (tỉ lệ 0..1).
///
/// `joints` rỗng nghĩa là dùng bộ ba khớp chính của cấu hình; nếu có thì
/// góc được đo cùng bên với góc chính (ví dụ đường thân vai–hông–cổ chân
/// khi đếm hít đất bằng góc khuỷu).
class FormRule {
  FormRule({
    required this.type,
    required this.code,
    Iterable<PoseJoint>? joints,
    this.angle,
    this.min,
    this.max,
    required List<double> severity,
    this.minFraction = 0.1,
  }) : joints = joints == null ? null : List.unmodifiable(joints),
       severity = List.unmodifiable(severity) {
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(code)) {
      throw ArgumentError('Form rule code must be snake_case: $code');
    }
    final j = this.joints;
    if (j != null && (j.length != 3 || j.toSet().length != 3)) {
      throw ArgumentError('Form rule joints must be three distinct joints');
    }
    if (this.severity.length != 2 || !this.severity.every(_finite)) {
      throw ArgumentError('severity must contain two numbers');
    }
    final s0 = this.severity[0];
    final s1 = this.severity[1];
    switch (type) {
      case FormRuleType.minDepth:
        final a = angle;
        if (a == null || !_angle(a) || !(a < s0 && s0 < s1 && s1 <= 180)) {
          throw ArgumentError('min_depth expects angle < severity[0] < [1]');
        }
      case FormRuleType.maxExtreme:
        final a = angle;
        if (a == null || !_angle(a) || !(a > s0 && s0 > s1 && s1 >= 0)) {
          throw ArgumentError('max_extreme expects angle > severity[0] > [1]');
        }
      case FormRuleType.band:
        final lo = min;
        final hi = max;
        if (lo == null ||
            hi == null ||
            !_angle(lo) ||
            !_angle(hi) ||
            lo >= hi) {
          throw ArgumentError('band expects 0 <= min < max <= 180');
        }
        if (!(s0 > 0 && s0 < s1)) {
          throw ArgumentError('band expects 0 < severity[0] < severity[1]');
        }
        if (!_finite(minFraction) || minFraction < 0 || minFraction >= 1) {
          throw ArgumentError('minFraction must be in [0, 1)');
        }
    }
  }

  /// Luật squat mặc định khi cấu hình hông–gối–cổ chân không khai báo
  /// `formRules` (giữ đúng hành vi cũ của `FormChecker.checkSquats`).
  factory FormRule.legacySquat({double maxDepthAngle = 100}) => FormRule(
    type: FormRuleType.minDepth,
    code: 'shallow_depth',
    angle: maxDepthAngle,
    severity: [maxDepthAngle + 10, maxDepthAngle + 20],
  );

  /// Đọc luật mới (`type`) hoặc dạng cũ `{code, maxDepthAngle}` của squat.
  factory FormRule.fromJson(Map<String, dynamic> json) {
    try {
      final code = json['code'];
      if (code is! String) {
        throw const FormatException('Form rule code must be a string');
      }
      if (!json.containsKey('type') && json.containsKey('maxDepthAngle')) {
        final rule = FormRule.legacySquat(
          maxDepthAngle: _num(json, 'maxDepthAngle')!,
        );
        return FormRule(
          type: rule.type,
          code: code,
          angle: rule.angle,
          severity: rule.severity,
        );
      }
      final type = FormRuleType.values.where(
        (value) => value.jsonName == json['type'],
      );
      if (type.isEmpty) {
        throw FormatException('Unsupported form rule type: ${json['type']}');
      }
      final rawSeverity = json['severity'];
      if (rawSeverity is! List || rawSeverity.any((value) => value is! num)) {
        throw const FormatException('severity must be a list of numbers');
      }
      final rawJoints = json['joints'];
      return FormRule(
        type: type.single,
        code: code,
        joints: rawJoints == null ? null : parseJoints(rawJoints, 3),
        angle: _num(json, 'angle'),
        min: _num(json, 'min'),
        max: _num(json, 'max'),
        severity: [for (final value in rawSeverity) (value as num).toDouble()],
        minFraction: _num(json, 'minFraction') ?? 0.1,
      );
    } on ArgumentError catch (error) {
      throw FormatException(error.message.toString());
    }
  }

  final FormRuleType type;
  final String code;
  final List<PoseJoint>? joints;
  final double? angle;
  final double? min;
  final double? max;
  final List<double> severity;
  final double minFraction;

  Map<String, dynamic> toJson() => {
    'type': type.jsonName,
    'code': code,
    if (joints != null) 'joints': joints!.map((joint) => joint.name).toList(),
    if (angle != null) 'angle': angle,
    if (min != null) 'min': min,
    if (max != null) 'max': max,
    'severity': severity,
    if (type == FormRuleType.band) 'minFraction': minFraction,
  };

  static bool _finite(double value) => value.isFinite;
  static bool _angle(double value) =>
      value.isFinite && value >= 0 && value <= 180;

  static double? _num(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! num) throw FormatException('$key must be a number');
    return value.toDouble();
  }
}

/// Đọc danh sách tên khớp JSON (`"hip"`, `"footIndex"`...) thành [PoseJoint].
List<PoseJoint> parseJoints(Object? raw, int count) {
  if (raw is! List || raw.length != count) {
    throw FormatException('joints must be a list of $count joint names');
  }
  final byName = PoseJoint.values.asNameMap();
  return [
    for (final name in raw)
      byName[name] ?? (throw FormatException('Unsupported joint: $name')),
  ];
}

/// Tên ổn định của một bộ ba khớp, ví dụ `shoulder-hip-ankle`.
String tripletKey(List<PoseJoint> joints) =>
    joints.map((joint) => joint.name).join('-');
