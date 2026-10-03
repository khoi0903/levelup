import 'pose.dart';

/// The inner `cv.configs[].config` object returned with an exercise.
class CvConfig {
  CvConfig({
    required Iterable<PoseJoint> joints,
    required this.downBelow,
    required this.upAbove,
    required this.minConfidence,
    required this.minRepMs,
  }) : joints = List.unmodifiable(joints) {
    if (this.joints.length != 3 || this.joints.toSet().length != 3) {
      throw ArgumentError('joints must contain three distinct joints');
    }
    if (!downBelow.isFinite ||
        !upAbove.isFinite ||
        downBelow <= 0 ||
        downBelow >= upAbove ||
        upAbove >= 180) {
      throw ArgumentError('Expected 0 < downBelow < upAbove < 180');
    }
    if (!minConfidence.isFinite || minConfidence < 0 || minConfidence > 1) {
      throw ArgumentError('minConfidence must be in [0, 1]');
    }
    if (minRepMs < 0) {
      throw ArgumentError('minRepMs must be nonnegative');
    }
  }

  factory CvConfig.fromJson(Map<String, dynamic> json) {
    final rawJoints = json['joints'];
    if (rawJoints is! List || rawJoints.length != 3) {
      throw const FormatException('joints must be a list of three joint names');
    }
    final joints = rawJoints.map((name) {
      return switch (name) {
        'shoulder' => PoseJoint.shoulder,
        'hip' => PoseJoint.hip,
        'knee' => PoseJoint.knee,
        'ankle' => PoseJoint.ankle,
        _ => throw FormatException('Unsupported joint: $name'),
      };
    }).toList();
    final minRepMs = json['minRepMs'];
    if (minRepMs is! int) {
      throw const FormatException('minRepMs must be an integer');
    }
    try {
      return CvConfig(
        joints: joints,
        downBelow: _number(json, 'downBelow'),
        upAbove: _number(json, 'upAbove'),
        minConfidence: _number(json, 'minConfidence'),
        minRepMs: minRepMs,
      );
    } on ArgumentError catch (error) {
      throw FormatException(error.message.toString());
    }
  }

  final List<PoseJoint> joints;
  final double downBelow;
  final double upAbove;
  final double minConfidence;
  final int minRepMs;

  static double _number(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num) {
      throw FormatException('$key must be a number');
    }
    return value.toDouble();
  }

  Map<String, dynamic> toJson() => {
    'joints': joints.map((joint) => joint.name).toList(),
    'downBelow': downBelow,
    'upAbove': upAbove,
    'minConfidence': minConfidence,
    'minRepMs': minRepMs,
  };
}
