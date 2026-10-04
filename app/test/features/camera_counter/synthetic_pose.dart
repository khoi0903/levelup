import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fitness_app/features/camera_counter/domain/cv_config.dart';
import 'package:fitness_app/features/camera_counter/domain/pose.dart';
import 'package:fitness_app/features/camera_counter/domain/rep_counter.dart';

CvConfig squatConfig({double downBelow = 95, int minRepMs = 600}) =>
    CvConfig.fromJson({
      'joints': ['hip', 'knee', 'ankle'],
      'downBelow': downBelow,
      'upAbove': 160,
      'minConfidence': 0.6,
      'minRepMs': minRepMs,
    });

/// Hip and ankle vectors have the requested angle around the knee.
List<PoseLandmark> sideLandmarks(
  BodySide side,
  double angle,
  double confidence,
) {
  final radians = angle * math.pi / 180;
  return [
    PoseLandmark(
      type: PoseLandmarkType.forJoint(PoseJoint.shoulder, side),
      x: 2,
      y: 0,
      likelihood: confidence,
    ),
    PoseLandmark(
      type: PoseLandmarkType.forJoint(PoseJoint.hip, side),
      x: 1,
      y: 0,
      likelihood: confidence,
    ),
    PoseLandmark(
      type: PoseLandmarkType.forJoint(PoseJoint.knee, side),
      x: 0,
      y: 0,
      likelihood: confidence,
    ),
    PoseLandmark(
      type: PoseLandmarkType.forJoint(PoseJoint.ankle, side),
      x: math.cos(radians),
      y: math.sin(radians),
      likelihood: confidence,
    ),
  ];
}

PoseFrame poseAt(
  int milliseconds, {
  double leftAngle = 170,
  double rightAngle = 170,
  double leftConfidence = 0.9,
  double rightConfidence = 0.8,
}) => PoseFrame(
  timestamp: Duration(milliseconds: milliseconds),
  landmarks: [
    ...sideLandmarks(BodySide.left, leftAngle, leftConfidence),
    ...sideLandmarks(BodySide.right, rightAngle, rightConfidence),
  ],
);

class SyntheticSession {
  SyntheticSession({CvConfig? config})
    : counter = RepCounter(config: config ?? squatConfig());

  final RepCounter counter;
  int nextMs = 0;

  RepCounterResult feed(
    double angle, {
    int stepMs = 100,
    double leftConfidence = 0.9,
    double rightConfidence = 0.8,
  }) {
    final result = counter.addFrame(
      poseAt(
        nextMs,
        leftAngle: angle,
        rightAngle: angle,
        leftConfidence: leftConfidence,
        rightConfidence: rightConfidence,
      ),
    );
    nextMs += stepMs;
    return result;
  }

  void arm() {
    feed(170);
    feed(175);
  }

  void squat({double deepestAngle = 80, bool insertLowConfidence = false}) {
    // Six hundred milliseconds from the first down to the first up frame.
    for (final angle in [
      140.0,
      deepestAngle + 10,
      deepestAngle + 5,
      deepestAngle,
      125.0,
      140.0,
      150.0,
      170.0,
      175.0,
    ]) {
      if (insertLowConfidence) {
        // Invalid frames deliberately contain a misleading deep angle.
        feed(20, leftConfidence: 0.2, rightConfidence: 0.3);
      }
      // Keep two adjacent reliable samples for each threshold confirmation.
      feed(angle);
      if (insertLowConfidence) feed(angle);
    }
  }
}

typedef Point = (double, double);

/// Điểm C sao cho góc ABC bằng [angle] độ, cách B một đoạn [length].
/// Xoay vector BA một góc [angle] (chiều dương của trục toán học).
Point bend(Point a, Point b, double angle, {double length = 1}) {
  final dx = a.$1 - b.$1;
  final dy = a.$2 - b.$2;
  final norm = math.sqrt(dx * dx + dy * dy);
  final radians = angle * math.pi / 180;
  final ux = dx / norm;
  final uy = dy / norm;
  return (
    b.$1 + length * (ux * math.cos(radians) - uy * math.sin(radians)),
    b.$2 + length * (ux * math.sin(radians) + uy * math.cos(radians)),
  );
}

/// Khung hình từ toạ độ từng khớp. [right] mặc định giống [left];
/// truyền `{}` để bên phải không có khớp nào.
PoseFrame jointFrame(
  int milliseconds,
  Map<PoseJoint, Point> left, {
  Map<PoseJoint, Point>? right,
  double leftConfidence = 0.9,
  double rightConfidence = 0.8,
}) => PoseFrame(
  timestamp: Duration(milliseconds: milliseconds),
  landmarks: [
    for (final entry in left.entries)
      PoseLandmark(
        type: PoseLandmarkType.forJoint(entry.key, BodySide.left),
        x: entry.value.$1,
        y: entry.value.$2,
        likelihood: leftConfidence,
      ),
    for (final entry in (right ?? left).entries)
      PoseLandmark(
        type: PoseLandmarkType.forJoint(entry.key, BodySide.right),
        x: entry.value.$1,
        y: entry.value.$2,
        likelihood: rightConfidence,
      ),
  ],
);

/// Ba khớp [joints] với góc ở khớp giữa bằng [angle]; khớp đầu nằm bên
/// phải khớp giữa.
Map<PoseJoint, Point> triplet(List<PoseJoint> joints, double angle) {
  const Point a = (1, 0);
  const Point b = (0, 0);
  return {joints[0]: a, joints[1]: b, joints[2]: bend(a, b, angle)};
}

/// Đưa lần lượt khung cách nhau [stepMs] vào một RepCounter bất kỳ.
class FrameFeeder {
  FrameFeeder(CvConfig config) : counter = RepCounter(config: config);

  final RepCounter counter;
  int nextMs = 0;

  RepCounterResult add(
    Map<PoseJoint, Point> left, {
    Map<PoseJoint, Point>? right,
    int stepMs = 100,
    double leftConfidence = 0.9,
    double rightConfidence = 0.8,
  }) {
    final result = counter.addFrame(
      jointFrame(
        nextMs,
        left,
        right: right,
        leftConfidence: leftConfidence,
        rightConfidence: rightConfidence,
      ),
    );
    nextMs += stepMs;
    return result;
  }

  /// Chỉ góc chính, hai bên như nhau.
  RepCounterResult angle(double angle, {int stepMs = 100}) =>
      add(triplet(counter.config.joints, angle), stepMs: stepMs);

  void angles(Iterable<double> values, {int stepMs = 100}) {
    for (final value in values) {
      angle(value, stepMs: stepMs);
    }
  }
}

/// `mongo/cv-configs.json`, đọc theo đường dẫn tương đối từ `app/`
/// (thư mục làm việc của `flutter test`).
Map<String, dynamic> cvConfigsJson() =>
    jsonDecode(File('../mongo/cv-configs.json').readAsStringSync())
        as Map<String, dynamic>;

/// Bản ghi cấu hình đang dùng (`activeVersion`) của một bài.
Map<String, dynamic> activeCvEntry(Map<String, dynamic> exercise) {
  final version = exercise['activeVersion'];
  return (exercise['configs'] as List).cast<Map<String, dynamic>>().singleWhere(
    (entry) => entry['version'] == version,
  );
}

CvConfig exerciseConfig(String slug) => CvConfig.fromJson(
  activeCvEntry(cvConfigsJson()[slug] as Map<String, dynamic>)['config']
      as Map<String, dynamic>,
);
