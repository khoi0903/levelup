import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../domain/models/body_shape.dart';

enum BodySide { front, back }

/// Hình học của hình người trong hệ toạ độ chuẩn hoá: cao 1.0, trục giữa x = 0.
/// Dùng chung cho vẽ và bắt chạm.
class BodyGeometry {
  BodyGeometry(this.shape, this.side) {
    _build();
  }

  /// Tỉ lệ rộng / cao của khung vẽ.
  static const double aspect = 0.52;
  static const double painRadius = 0.026;
  static const double painHitRadius = 0.05;

  final BodyShape shape;
  final BodySide side;

  /// Các mảng thân người (đầu, cổ, thân, tay, chân) để tô nền.
  final List<Path> silhouette = [];

  /// Vùng cơ theo tên nhóm cơ. Chỉ gồm nhóm thấy được ở mặt đang xem.
  final Map<String, Path> muscles = {};

  /// Tâm các điểm đau theo tên vùng.
  final Map<String, List<Offset>> painSpots = {};

  static const List<String> frontMuscles = [
    'chest',
    'shoulders',
    'arms',
    'abs',
    'legs',
  ];
  static const List<String> backMuscles = [
    'back',
    'shoulders',
    'arms',
    'glutes',
    'legs',
  ];

  static List<String> musclesFor(BodySide side) =>
      side == BodySide.front ? frontMuscles : backMuscles;

  static final Float64List _flipX = Float64List.fromList(const [
    -1, 0, 0, 0, //
    0, 1, 0, 0, //
    0, 0, 1, 0, //
    0, 0, 0, 1, //
  ]);

  static Path _capsule(Offset a, double ra, Offset b, double rb) {
    final d = b - a;
    final len = d.distance;
    final n = len == 0 ? const Offset(1, 0) : Offset(-d.dy / len, d.dx / len);
    final quad = Path()
      ..moveTo(a.dx + n.dx * ra, a.dy + n.dy * ra)
      ..lineTo(b.dx + n.dx * rb, b.dy + n.dy * rb)
      ..lineTo(b.dx - n.dx * rb, b.dy - n.dy * rb)
      ..lineTo(a.dx - n.dx * ra, a.dy - n.dy * ra)
      ..close();
    final ends = _union(
      Path()..addOval(Rect.fromCircle(center: a, radius: ra)),
      Path()..addOval(Rect.fromCircle(center: b, radius: rb)),
    );
    return _union(quad, ends);
  }

  static Path _union(Path a, Path b) => Path.combine(PathOperation.union, a, b);

  static Path _mirror(Path p) => p.transform(_flipX);

  /// Đường viền thân đi qua các điểm bên phải rồi đối xứng sang trái.
  static Path _symmetric(List<Offset> right) {
    final path = Path()..moveTo(right.first.dx, right.first.dy);
    for (var i = 1; i < right.length; i++) {
      final p0 = right[i - 1], p1 = right[i];
      final my = (p0.dy + p1.dy) / 2;
      path.cubicTo(p0.dx, my, p1.dx, my, p1.dx, p1.dy);
    }
    path.lineTo(-right.last.dx, right.last.dy);
    for (var i = right.length - 1; i >= 1; i--) {
      final p0 = right[i], p1 = right[i - 1];
      final my = (p0.dy + p1.dy) / 2;
      path.cubicTo(-p0.dx, my, -p1.dx, my, -p1.dx, p1.dy);
    }
    return path..close();
  }

  void _build() {
    final s = shape;
    final a = s.arm;

    // Đầu, cổ
    final head = Path()
      ..addOval(
        Rect.fromCenter(
          center: const Offset(0, 0.068),
          width: 0.098,
          height: 0.118,
        ),
      );
    final neck = Path()
      ..addRect(const Rect.fromLTRB(-0.024, 0.115, 0.024, 0.165));

    // Thân
    final torso = _symmetric([
      const Offset(0.024, 0.150),
      Offset(s.shoulder, 0.185),
      Offset(s.chest, 0.255),
      Offset(s.waist, 0.375),
      Offset(s.hip, 0.465),
      Offset(s.hip * 0.96, 0.525),
    ]);

    // Tay bên phải hình (x dương), bên trái lấy đối xứng
    final shoulderJoint = Offset(s.shoulder - a * 0.3, 0.192);
    final wristX = math.max(shoulderJoint.dx + 0.03, s.hip + a + 0.012);
    final elbow = Offset((shoulderJoint.dx + wristX) / 2 + 0.006, 0.335);
    final wrist = Offset(wristX, 0.468);
    final upperArm = _capsule(shoulderJoint, a, elbow, a * 0.82);
    final foreArm = _capsule(elbow, a * 0.80, wrist, a * 0.58);
    final hand = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(wristX + 0.003, 0.502),
          width: a * 1.5,
          height: 0.05,
        ),
      );
    final armR = _union(upperArm, foreArm);

    // Chân
    final th = s.thigh;
    final legX = math.max(s.hip - th, th * 0.92);
    final kneeX = math.max(legX * 0.9, 0.036);
    final knee = Offset(kneeX, 0.715);
    final ankle = Offset(kneeX, 0.915);
    final thigh = _capsule(Offset(legX, 0.505), th, knee, th * 0.62);
    final calf = _capsule(Offset(kneeX, 0.74), th * 0.60, ankle, th * 0.36);
    final foot = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(kneeX + 0.008, 0.955),
          width: 0.062,
          height: 0.034,
        ),
      );
    final legR = _union(thigh, calf);

    final armWithHand = _union(armR, hand);
    final legWithFoot = _union(legR, foot);
    silhouette
      ..add(head)
      ..add(neck)
      ..add(torso)
      ..add(armWithHand)
      ..add(_mirror(armWithHand))
      ..add(legWithFoot)
      ..add(_mirror(legWithFoot));

    // Vùng cơ
    final deltoid = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(s.shoulder - a * 0.45, 0.19),
          width: a * 2.5,
          height: 0.058,
        ),
      );
    muscles['shoulders'] = _union(deltoid, _mirror(deltoid));

    final armMuscle = Path.combine(PathOperation.difference, armR, deltoid);
    muscles['arms'] = _union(armMuscle, _mirror(armMuscle));
    final legs = _union(legR, _mirror(legR));

    Path clipTorso(Rect r, {double radius = 0.02}) => Path.combine(
      PathOperation.intersect,
      torso,
      Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius))),
    );

    final innerW = math.max(s.shoulder - a * 1.6, 0.05);
    if (side == BodySide.front) {
      final pec = clipTorso(
        Rect.fromLTRB(0.006, 0.19, innerW, 0.275),
        radius: 0.03,
      );
      muscles['chest'] = _union(pec, _mirror(pec));
      final absW = math.max(s.waist * 0.62, 0.034);
      muscles['abs'] = clipTorso(Rect.fromLTRB(-absW, 0.29, absW, 0.455));
      muscles['legs'] = legs;
    } else {
      muscles['back'] = clipTorso(
        Rect.fromLTRB(-innerW, 0.175, innerW, 0.40),
        radius: 0.03,
      );
      final glute = clipTorso(
        Rect.fromLTRB(0.004, 0.42, s.hip, 0.53),
        radius: 0.04,
      );
      final glutes = _union(glute, _mirror(glute));
      muscles['glutes'] = glutes;
      muscles['legs'] = Path.combine(PathOperation.difference, legs, glutes);
    }

    // Điểm đau
    List<Offset> both(Offset p) => [p, Offset(-p.dx, p.dy)];
    painSpots['neck'] = const [Offset(0, 0.138)];
    painSpots['shoulder'] = both(Offset(s.shoulder - a * 0.45, 0.19));
    painSpots['lower_back'] = const [Offset(0, 0.405)];
    painSpots['wrist'] = both(wrist);
    painSpots['hip'] = both(Offset(math.max(s.hip - 0.02, 0.05), 0.478));
    painSpots['knee'] = both(knee);
    painSpots['ankle'] = both(ankle);
  }

  /// Nhóm cơ tại điểm [p] (toạ độ chuẩn hoá), null nếu không trúng.
  String? muscleAt(Offset p) {
    // Vùng nhỏ nằm trên vùng lớn được xét trước.
    const order = [
      'shoulders',
      'chest',
      'abs',
      'glutes',
      'back',
      'arms',
      'legs',
    ];
    for (final id in order) {
      final path = muscles[id];
      if (path != null && path.contains(p)) return id;
    }
    return null;
  }

  /// Vùng đau gần [p] nhất trong bán kính chạm, null nếu không trúng.
  String? painAt(Offset p) {
    String? best;
    var bestDist = painHitRadius;
    painSpots.forEach((id, centers) {
      for (final c in centers) {
        final d = (c - p).distance;
        if (d <= bestDist) {
          bestDist = d;
          best = id;
        }
      }
    });
    return best;
  }

  static double scaleFor(Size size) =>
      math.min(size.height, size.width / aspect);

  /// Đổi điểm chạm trong khung [size] sang toạ độ chuẩn hoá.
  static Offset toNormalized(Offset local, Size size) {
    final scale = scaleFor(size);
    return Offset(
      (local.dx - size.width / 2) / scale,
      (local.dy - (size.height - scale) / 2) / scale,
    );
  }

  /// Đổi toạ độ chuẩn hoá sang điểm trong khung [size].
  static Offset toLocal(Offset normalized, Size size) {
    final scale = scaleFor(size);
    return Offset(
      normalized.dx * scale + size.width / 2,
      normalized.dy * scale + (size.height - scale) / 2,
    );
  }
}
