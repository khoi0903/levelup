/// The joints supported by the camera counter, independent of ML Kit.
enum PoseJoint { shoulder, hip, knee, ankle }

enum BodySide { left, right }

enum PoseLandmarkType {
  leftShoulder,
  rightShoulder,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle;

  static PoseLandmarkType forJoint(PoseJoint joint, BodySide side) =>
      switch ((joint, side)) {
        (PoseJoint.shoulder, BodySide.left) => leftShoulder,
        (PoseJoint.shoulder, BodySide.right) => rightShoulder,
        (PoseJoint.hip, BodySide.left) => leftHip,
        (PoseJoint.hip, BodySide.right) => rightHip,
        (PoseJoint.knee, BodySide.left) => leftKnee,
        (PoseJoint.knee, BodySide.right) => rightKnee,
        (PoseJoint.ankle, BodySide.left) => leftAnkle,
        (PoseJoint.ankle, BodySide.right) => rightAnkle,
      };
}

/// Coordinates must use the same scale on both axes (e.g. image pixels).
class PoseLandmark {
  const PoseLandmark({
    required this.type,
    required this.x,
    required this.y,
    required this.likelihood,
  });

  final PoseLandmarkType type;
  final double x;
  final double y;
  final double likelihood;
}

class PoseFrame {
  PoseFrame({
    required this.timestamp,
    required Iterable<PoseLandmark> landmarks,
  }) : landmarks = _indexLandmarks(landmarks) {
    if (timestamp.isNegative) {
      throw ArgumentError.value(timestamp, 'timestamp', 'Must be nonnegative');
    }
  }

  /// Monotonic time elapsed since session start, not a wall-clock date.
  final Duration timestamp;
  final Map<PoseLandmarkType, PoseLandmark> landmarks;

  static Map<PoseLandmarkType, PoseLandmark> _indexLandmarks(
    Iterable<PoseLandmark> landmarks,
  ) {
    final indexed = <PoseLandmarkType, PoseLandmark>{};
    for (final landmark in landmarks) {
      if (indexed.containsKey(landmark.type)) {
        throw ArgumentError('Duplicate landmark: ${landmark.type.name}');
      }
      indexed[landmark.type] = landmark;
    }
    return Map.unmodifiable(indexed);
  }
}
