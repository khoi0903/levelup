import 'dart:math' as math;

import 'pose.dart';

/// Angle ABC in degrees, in [0, 180]. Returns null for unusable geometry.
double? jointAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
  if (![a.x, a.y, b.x, b.y, c.x, c.y].every((value) => value.isFinite)) {
    return null;
  }
  final ax = a.x - b.x;
  final ay = a.y - b.y;
  final cx = c.x - b.x;
  final cy = c.y - b.y;
  // Scale each vector before multiplying to avoid overflow/underflow.
  final aScale = math.max(ax.abs(), ay.abs());
  final cScale = math.max(cx.abs(), cy.abs());
  if (aScale == 0 || cScale == 0 || !aScale.isFinite || !cScale.isFinite) {
    return null;
  }
  final ux = ax / aScale;
  final uy = ay / aScale;
  final vx = cx / cScale;
  final vy = cy / cScale;
  return math.atan2((ux * vy - uy * vx).abs(), ux * vx + uy * vy) *
      180 /
      math.pi;
}
