import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as mlkit;

import '../domain/pose.dart';

/// Copies ML Kit's pixel coordinates unchanged. Filtering belongs to domain.
class MlkitPoseAdapter {
  const MlkitPoseAdapter();

  /// 16 khớp domain dùng (vai, khuỷu, cổ tay, hông, gối, cổ chân, gót,
  /// mũi chân); tên enum domain trùng tên ML Kit. Các điểm mặt, ngón tay bị bỏ.
  static const _types = {
    mlkit.PoseLandmarkType.leftShoulder: PoseLandmarkType.leftShoulder,
    mlkit.PoseLandmarkType.rightShoulder: PoseLandmarkType.rightShoulder,
    mlkit.PoseLandmarkType.leftElbow: PoseLandmarkType.leftElbow,
    mlkit.PoseLandmarkType.rightElbow: PoseLandmarkType.rightElbow,
    mlkit.PoseLandmarkType.leftWrist: PoseLandmarkType.leftWrist,
    mlkit.PoseLandmarkType.rightWrist: PoseLandmarkType.rightWrist,
    mlkit.PoseLandmarkType.leftHip: PoseLandmarkType.leftHip,
    mlkit.PoseLandmarkType.rightHip: PoseLandmarkType.rightHip,
    mlkit.PoseLandmarkType.leftKnee: PoseLandmarkType.leftKnee,
    mlkit.PoseLandmarkType.rightKnee: PoseLandmarkType.rightKnee,
    mlkit.PoseLandmarkType.leftAnkle: PoseLandmarkType.leftAnkle,
    mlkit.PoseLandmarkType.rightAnkle: PoseLandmarkType.rightAnkle,
    mlkit.PoseLandmarkType.leftHeel: PoseLandmarkType.leftHeel,
    mlkit.PoseLandmarkType.rightHeel: PoseLandmarkType.rightHeel,
    mlkit.PoseLandmarkType.leftFootIndex: PoseLandmarkType.leftFootIndex,
    mlkit.PoseLandmarkType.rightFootIndex: PoseLandmarkType.rightFootIndex,
  };

  /// null means no person; missing joints stay absent, never synthesized.
  PoseFrame toFrame(mlkit.Pose? pose, {required Duration timestamp}) {
    final landmarks = <PoseLandmark>[];
    if (pose != null) {
      for (final entry in _types.entries) {
        final point = pose.landmarks[entry.key];
        if (point == null) continue;
        landmarks.add(
          PoseLandmark(
            type: entry.value,
            x: point.x,
            y: point.y,
            likelihood: point.likelihood,
          ),
        );
      }
    }
    return PoseFrame(timestamp: timestamp, landmarks: landmarks);
  }
}
