import 'form_rule.dart';
import 'pose.dart';

/// Hướng chuyển động của một lần đếm.
enum CvDirection {
  /// Nghỉ ở góc lớn; một lần = xuống dưới `downBelow` rồi lên lại trên
  /// `upAbove` (squat, hít đất, cuốn tạ). Mặc định, giống hành vi cũ.
  flex,

  /// Nghỉ ở góc nhỏ; một lần = lên trên `upAbove` rồi về dưới `downBelow`
  /// (tay jumping jack, cầu mông, đẩy tạ qua đầu, nhón gót).
  extend,
}

/// Cách tính kết quả.
enum CvMode {
  /// Đếm số lần (mặc định).
  reps,

  /// Bài giữ tư thế (plank, wall sit): cộng thời gian khi góc nằm trong
  /// [holdMin, holdMax] với đủ độ tin cậy.
  hold,

  /// Mỗi bên hoàn tất một chu kỳ; chu kỳ hai bên chồng nhau tính một lần.
  alternating,

  /// Cộng thời gian khi có chu kỳ hoàn tất trong hai giây gần nhất.
  active,
}

/// Cách chọn bên trái/phải mỗi khung hình.
enum CvSide {
  /// Bên có độ tin cậy trung bình cao hơn (mặc định, như cũ).
  auto,

  /// Trung bình góc hai bên; chỉ một bên dùng được thì lấy bên đó.
  /// Cho động tác đối xứng nhìn từ phía trước (jumping jack, đẩy tạ).
  both,

  /// Bên có góc nhỏ hơn: bên đang chuyển động khi nghỉ ở góc lớn
  /// (nâng chân nằm nghiêng, cuốn tạ luân phiên).
  min,

  /// Bên có góc lớn hơn.
  max,
}

enum OrientationAxis { horizontal, vertical }

/// Kiểm tra hướng thân người, ví dụ vai–cổ chân phải gần nằm ngang khi plank
/// để người đứng thẳng không bị tính là đang giữ plank. Khung hình sai hướng
/// vẫn tính là có người, nhưng không làm tiến trạng thái đếm/giữ.
class CvOrientation {
  CvOrientation({
    required Iterable<PoseJoint> joints,
    required this.axis,
    this.maxTiltDeg = 35,
  }) : joints = List.unmodifiable(joints) {
    if (this.joints.length != 2 || this.joints[0] == this.joints[1]) {
      throw ArgumentError('orientation.joints must be two distinct joints');
    }
    if (!maxTiltDeg.isFinite || maxTiltDeg <= 0 || maxTiltDeg >= 90) {
      throw ArgumentError('orientation.maxTiltDeg must be in (0, 90)');
    }
  }

  factory CvOrientation.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('orientation must be an object');
    }
    final axis = OrientationAxis.values.asNameMap()[json['axis']];
    if (axis == null) {
      throw FormatException('Unsupported orientation axis: ${json['axis']}');
    }
    final tilt = json['maxTiltDeg'] ?? 35;
    if (tilt is! num) {
      throw const FormatException('maxTiltDeg must be a number');
    }
    return CvOrientation(
      joints: parseJoints(json['joints'], 2),
      axis: axis,
      maxTiltDeg: tilt.toDouble(),
    );
  }

  final List<PoseJoint> joints;
  final OrientationAxis axis;
  final double maxTiltDeg;

  Map<String, dynamic> toJson() => {
    'joints': joints.map((joint) => joint.name).toList(),
    'axis': axis.name,
    'maxTiltDeg': maxTiltDeg,
  };
}

/// The inner `cv.configs[].config` object returned with an exercise.
///
/// Tương thích ngược: JSON squat cũ (`joints`, `downBelow`, `upAbove`,
/// `minConfidence`, `minRepMs`) vẫn đọc được và đếm y như trước.
class CvConfig {
  CvConfig({
    required Iterable<PoseJoint> joints,
    required this.downBelow,
    required this.upAbove,
    required this.minConfidence,
    required this.minRepMs,
    this.direction = CvDirection.flex,
    this.mode = CvMode.reps,
    this.side = CvSide.auto,
    this.holdMin,
    this.holdMax,
    this.orientation,
    Iterable<FormRule>? formRules,
    this.placement,
    this.setupTipVi,
  }) : joints = List.unmodifiable(joints),
       _explicitRules = formRules != null,
       formRules = List.unmodifiable(
         formRules ?? _defaultRules(joints.toList(), mode, direction),
       ) {
    if (this.joints.length != 3 || this.joints.toSet().length != 3) {
      throw ArgumentError('joints must contain three distinct joints');
    }
    if (mode != CvMode.hold) {
      if (!downBelow.isFinite ||
          !upAbove.isFinite ||
          downBelow <= 0 ||
          downBelow >= upAbove ||
          upAbove >= 180) {
        throw ArgumentError('Expected 0 < downBelow < upAbove < 180');
      }
    } else {
      final lo = holdMin;
      final hi = holdMax;
      if (lo == null ||
          hi == null ||
          !lo.isFinite ||
          !hi.isFinite ||
          lo < 0 ||
          lo >= hi ||
          hi > 180) {
        throw ArgumentError('Expected 0 <= holdMin < holdMax <= 180');
      }
    }
    if (!minConfidence.isFinite || minConfidence < 0 || minConfidence > 1) {
      throw ArgumentError('minConfidence must be in [0, 1]');
    }
    if (minRepMs < 0) {
      throw ArgumentError('minRepMs must be nonnegative');
    }
    for (final rule in this.formRules) {
      if (isHold && rule.type != FormRuleType.band) {
        throw ArgumentError('Duration modes support band form rules only');
      }
      if (isHold &&
          !(rule.minFraction < rule.severity[0] && rule.severity[1] <= 1)) {
        throw ArgumentError(
          'Hold band severity must satisfy minFraction < [0] < [1] <= 1',
        );
      }
    }
  }

  factory CvConfig.fromJson(Map<String, dynamic> json) {
    final joints = parseJoints(json['joints'], 3);
    final mode = _enum(json, 'mode', CvMode.values, CvMode.reps);
    final hold = mode == CvMode.hold;
    final rawMinRepMs = json['minRepMs'] ?? (hold ? 0 : null);
    if (rawMinRepMs is! int) {
      throw const FormatException('minRepMs must be an integer');
    }
    final rawRules = json['formRules'];
    if (rawRules != null && rawRules is! List) {
      throw const FormatException('formRules must be a list');
    }
    final placement = json['placement'];
    final tip = json['setupTipVi'];
    if (placement != null && placement is! String ||
        tip != null && tip is! String) {
      throw const FormatException('placement and setupTipVi must be strings');
    }
    try {
      final holdMin = hold ? _number(json, 'holdMin') : null;
      final holdMax = hold ? _number(json, 'holdMax') : null;
      return CvConfig(
        joints: joints,
        // Bài giữ không cần ngưỡng đếm; mặc định bằng biên của dải giữ.
        downBelow: hold && json['downBelow'] == null
            ? holdMin!
            : _number(json, 'downBelow'),
        upAbove: hold && json['upAbove'] == null
            ? holdMax!
            : _number(json, 'upAbove'),
        minConfidence: _number(json, 'minConfidence'),
        minRepMs: rawMinRepMs,
        direction: _enum(
          json,
          'direction',
          CvDirection.values,
          CvDirection.flex,
        ),
        mode: mode,
        side: _enum(json, 'side', CvSide.values, CvSide.auto),
        holdMin: holdMin,
        holdMax: holdMax,
        orientation: json['orientation'] == null
            ? null
            : CvOrientation.fromJson(json['orientation']),
        formRules: rawRules == null
            ? null
            : [
                for (final rule in rawRules as List)
                  rule is Map<String, dynamic>
                      ? FormRule.fromJson(rule)
                      : throw const FormatException(
                          'Each form rule must be an object',
                        ),
              ],
        placement: placement as String?,
        setupTipVi: tip as String?,
      );
    } on ArgumentError catch (error) {
      throw FormatException(error.message.toString());
    }
  }

  final List<PoseJoint> joints;

  /// Ngưỡng đếm. Với `flex`: vào lần tập khi góc < downBelow, hoàn tất khi
  /// góc > upAbove. Với `extend`: vào khi > upAbove, hoàn tất khi < downBelow.
  final double downBelow;
  final double upAbove;
  final double minConfidence;
  final int minRepMs;
  final CvDirection direction;
  final CvMode mode;
  final CvSide side;

  /// Dải góc được tính là đang giữ (chỉ dùng khi `mode == hold`).
  final double? holdMin;
  final double? holdMax;
  final CvOrientation? orientation;
  final List<FormRule> formRules;
  final bool _explicitRules;

  /// Gợi ý chi tiết vị trí đặt máy (ví dụ `floor_side`), bổ sung cho
  /// `cameraPosition` (side/front) ở cấp trên.
  final String? placement;

  /// Hướng dẫn đặt điện thoại hiển thị cho người dùng.
  final String? setupTipVi;

  bool get isHold => mode == CvMode.hold || mode == CvMode.active;

  /// Mọi bộ ba khớp cần đo: bộ chính (vị trí 0) rồi các bộ riêng của luật.
  List<List<PoseJoint>> get trackedTriplets {
    final seen = <String>{tripletKey(joints)};
    final triplets = [joints];
    for (final rule in formRules) {
      final ruleJoints = rule.joints;
      if (ruleJoints != null && seen.add(tripletKey(ruleJoints))) {
        triplets.add(ruleJoints);
      }
    }
    return List.unmodifiable(triplets);
  }

  static List<FormRule> _defaultRules(
    List<PoseJoint> joints,
    CvMode mode,
    CvDirection direction,
  ) {
    final isSquat =
        joints.length == 3 &&
        joints[0] == PoseJoint.hip &&
        joints[1] == PoseJoint.knee &&
        joints[2] == PoseJoint.ankle;
    return isSquat && mode == CvMode.reps && direction == CvDirection.flex
        ? [FormRule.legacySquat()]
        : const [];
  }

  static T _enum<T extends Enum>(
    Map<String, dynamic> json,
    String key,
    List<T> values,
    T fallback,
  ) {
    final raw = json[key];
    if (raw == null) return fallback;
    return values.asNameMap()[raw] ??
        (throw FormatException('Unsupported $key: $raw'));
  }

  static double _number(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num) {
      throw FormatException('$key must be a number');
    }
    return value.toDouble();
  }

  /// Chỉ ghi các trường khác mặc định để JSON squat cũ giữ nguyên dạng.
  Map<String, dynamic> toJson() => {
    'joints': joints.map((joint) => joint.name).toList(),
    'downBelow': downBelow,
    'upAbove': upAbove,
    'minConfidence': minConfidence,
    'minRepMs': minRepMs,
    if (direction != CvDirection.flex) 'direction': direction.name,
    if (mode != CvMode.reps) 'mode': mode.name,
    if (side != CvSide.auto) 'side': side.name,
    if (holdMin != null) 'holdMin': holdMin,
    if (holdMax != null) 'holdMax': holdMax,
    if (orientation != null) 'orientation': orientation!.toJson(),
    if (_explicitRules)
      'formRules': formRules.map((rule) => rule.toJson()).toList(),
    if (placement != null) 'placement': placement,
    if (setupTipVi != null) 'setupTipVi': setupTipVi,
  };
}
