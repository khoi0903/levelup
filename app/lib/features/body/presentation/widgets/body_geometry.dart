import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../domain/models/body_shape.dart';

enum BodySide { front, back }

/// Hình học của hình người trong hệ toạ độ chuẩn hoá: cao 1.0, trục giữa x = 0.
/// Dùng chung cho vẽ và bắt chạm.
///
/// Đường viền là một nét liền bằng đường cong Bézier đi qua các mốc giải phẫu
/// (đầu, cổ, cơ thang, vai, tay, eo, hông, đùi, bắp chân, bàn chân). Các mốc này
/// lấy từ [BodyShape] nên hình đổi mượt theo BMI và tỉ lệ mỡ.
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

  /// Đường viền thân người (một nét liền) để tô nền.
  final List<Path> silhouette = [];

  /// Vùng cơ theo tên nhóm cơ. Chỉ gồm nhóm thấy được ở mặt đang xem.
  /// Mỗi nhóm có thể gồm nhiều mảng cơ (ví dụ chân: tứ đầu + bắp chân).
  final Map<String, Path> muscles = {};

  /// Nét tách các múi cơ trong cùng một mảng (múi bụng, rãnh sống lưng...).
  final List<Path> creases = [];

  /// Nét phụ không thuộc nhóm cơ nào (xương đòn, xương bánh chè).
  final List<Path> details = [];

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

  static Path _mirror(Path p) => p.transform(_flipX);

  static Offset _flip(Offset p) => Offset(-p.dx, p.dy);

  static Offset _dir(Offset v) {
    final d = v.distance;
    return d < 1e-9 ? Offset.zero : v / d;
  }

  /// Nội suy tuyến tính theo bảng (ys tăng dần).
  static double _table(double y, List<double> ys, List<double> vs) {
    if (y <= ys.first) return vs.first;
    for (var i = 1; i < ys.length; i++) {
      if (y <= ys[i]) {
        final t = (y - ys[i - 1]) / (ys[i] - ys[i - 1]);
        return vs[i - 1] + (vs[i] - vs[i - 1]) * t;
      }
    }
    return vs.last;
  }

  /// Nối tiếp [path] bằng đường cong mượt đi qua [pts] (điểm đầu là điểm hiện
  /// tại của path). [before]/[after] là điểm kề ngoài hai đầu để lấy tiếp tuyến.
  static void _splineTo(
    Path path,
    List<Offset> pts, {
    Offset? before,
    Offset? after,
  }) {
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i == 0 ? (before ?? pts[0]) : pts[i - 1];
      final p1 = pts[i], p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : (after ?? p2);
      final len = (p2 - p1).distance / 3;
      final c1 = p1 + _dir(p2 - p0) * len;
      final c2 = p2 - _dir(p3 - p1) * len;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
  }

  /// Mảng kín bo tròn đi qua [pts].
  static Path _blob(List<Offset> pts) {
    final n = pts.length;
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < n; i++) {
      final p0 = pts[(i - 1 + n) % n], p1 = pts[i];
      final p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n];
      final len = (p2 - p1).distance / 3;
      final c1 = p1 + _dir(p2 - p0) * len;
      final c2 = p2 - _dir(p3 - p1) * len;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path..close();
  }

  /// Mảng kín đối xứng qua trục giữa; [right] đi từ đỉnh (x = 0) xuống đáy (x = 0).
  static Path _symBlob(List<Offset> right) => _blob([
    ...right,
    for (var i = right.length - 2; i >= 1; i--) _flip(right[i]),
  ]);

  /// Múi cơ hình thoi dài nằm giữa hai mép [lo] và [hi] (hàm theo y).
  /// [top]/[bottom]: độ tù của hai đầu (0 = nhọn, 1 = phẳng).
  static Path _spindle(
    double y0,
    double y1,
    double Function(double y) lo,
    double Function(double y) hi, {
    double top = 0.45,
    double bottom = 0.45,
  }) {
    const ts = [0.0, 0.14, 0.38, 0.64, 0.86, 1.0];
    final ks = [
      top,
      top + (1 - top) * 0.74,
      1.0,
      1.0,
      bottom + (1 - bottom) * 0.74,
      bottom,
    ];
    final outer = <Offset>[], inner = <Offset>[];
    for (var i = 0; i < ts.length; i++) {
      final y = y0 + (y1 - y0) * ts[i];
      final a = lo(y), b = hi(y);
      final mid = (a + b) / 2;
      final half = math.max((b - a) / 2, 0.002) * ks[i];
      outer.add(Offset(mid + half, y));
      inner.add(Offset(mid - half, y));
    }
    return _blob([...outer, ...inner.reversed]);
  }

  static Path _line(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    _splineTo(path, pts);
    return path;
  }

  /// Gộp các mảng bên phải và ảnh đối xứng của chúng thành một path.
  static Path _both(List<Path> rightParts, [List<Path> centered = const []]) {
    final path = Path();
    for (final p in centered) {
      path.addPath(p, Offset.zero);
    }
    for (final p in rightParts) {
      path
        ..addPath(p, Offset.zero)
        ..addPath(_mirror(p), Offset.zero);
    }
    return path;
  }

  void _build() {
    final s = shape;
    final a = s.arm;
    final sh = s.shoulder, ch = s.chest, h = s.hip, th = s.thigh;
    // Nữ: eo thắt hơn một chút so với số đo gốc.
    final w = s.female ? s.waist * 0.93 : s.waist;
    final front = side == BodySide.front;

    // ---- Mốc giải phẫu (nửa bên phải hình, x dương) ----
    final nw = 0.015 + a * 0.30; // nửa bề rộng cổ
    final jx = sh - a * 0.3; // khớp vai
    final wx = math.max(jx + 0.040, h + a + 0.016); // cổ tay
    final ex = (jx + wx) / 2 + 0.006; // khuỷu
    const jy = 0.195, ey = 0.335, wy = 0.470;

    final legX = math.max(h - th, th * 0.92); // tâm đùi trên
    final kneeX = math.max(legX * 0.98, 0.040);
    const kneeY = 0.715, ankleY = 0.925;
    final hipLow = legX + th;

    const torsoYs = [0.240, 0.272, 0.320, 0.375, 0.420, 0.468, 0.505];
    final torsoXs = [
      ch * 0.97,
      ch,
      ch + (w - ch) * 0.6,
      w,
      w + (h - w) * 0.55,
      h,
      hipLow,
    ];
    double torsoX(double y) => _table(y, torsoYs, torsoXs);

    const armAxisYs = [jy, ey, wy];
    final armAxisXs = [jx, ex, wx];
    const armYs = [0.195, 0.232, 0.265, 0.300, 0.335, 0.372, 0.420, 0.470];
    const armKs = [1.0, 1.0, 0.90, 0.88, 0.76, 0.84, 0.70, 0.50];
    double armX(double y) => _table(y, armAxisYs, armAxisXs);
    double armR(double y) => a * _table(y, armYs, armKs);
    double armOut(double y) => armX(y) + armR(y);
    // Tay không lấn vào thân: mép trong luôn nằm ngoài sườn.
    double armIn(double y) => math.max(armX(y) - armR(y), torsoX(y) + 0.003);

    const legYs = [0.505, 0.56, 0.62, 0.67, 0.715, 0.75, 0.80, 0.87, 0.925];
    const legKs = [1.0, 0.93, 0.82, 0.71, 0.60, 0.57, 0.64, 0.47, 0.33];
    double legC(double y) =>
        _table(y, const [0.505, kneeY], [legX, kneeX]); // tâm chân
    double legR(double y) => th * _table(y, legYs, legKs);
    double legOut(double y) => legC(y) + legR(y);
    double legIn(double y) => math.max(legC(y) - legR(y), 0.003);
    // Mép theo toạ độ ngang u của chân: -1 = mép trong, +1 = mép ngoài.
    double Function(double) legU(double u) =>
        (y) => math.max(legC(y) + u * legR(y), 0.005);

    // ---- Đường viền liền nét ----
    // Đoạn 1: đỉnh đầu -> cổ -> cơ thang -> vai -> tay -> bàn tay -> nách.
    final armpit = Offset(torsoX(0.243), 0.243);
    final seg1 = <Offset>[
      const Offset(0, 0.012),
      const Offset(0.026, 0.017),
      const Offset(0.043, 0.036),
      const Offset(0.050, 0.064),
      const Offset(0.048, 0.088),
      const Offset(0.041, 0.109),
      const Offset(0.031, 0.124),
      Offset(nw + 0.001, 0.133),
      Offset(nw, 0.148),
      Offset(nw + 0.007, 0.159),
      Offset(nw + 0.026, 0.167),
      Offset((nw + jx) / 2 + 0.012, 0.1735),
      Offset(jx - a * 0.2, 0.179),
      Offset(jx + a * 0.5, 0.186),
      Offset(jx + a * 0.93, 0.206),
      for (final y in const [0.232, 0.265, 0.300, 0.335, 0.372, 0.420])
        Offset(armOut(y), y),
      Offset(wx + a * 0.50, 0.468),
      Offset(wx + a * 0.62 + 0.002, 0.490),
      Offset(wx + a * 0.66 + 0.003, 0.512),
      Offset(wx + a * 0.45 + 0.002, 0.532),
      Offset(wx + a * 0.05, 0.540),
      Offset(wx - a * 0.35, 0.530),
      Offset(wx - a * 0.62, 0.508),
      Offset(wx - a * 0.66 - 0.002, 0.487),
      Offset(wx - a * 0.50, 0.468),
      for (final y in const [0.420, 0.372, 0.335, 0.300, 0.268])
        Offset(armIn(y), y),
      armpit,
    ];
    // Đoạn 2: nách -> sườn -> eo -> hông -> đùi -> gối -> bắp chân -> bàn chân
    // -> mép trong chân -> đáy chậu.
    final seg2 = <Offset>[
      armpit,
      for (var i = 1; i < torsoYs.length - 1; i++)
        Offset(torsoXs[i], torsoYs[i]),
      Offset(hipLow, 0.508),
      for (final y in const [0.56, 0.62, 0.67, kneeY, 0.75, 0.80, 0.87])
        Offset(legOut(y), y),
      Offset(kneeX + th * 0.33, ankleY),
      Offset(kneeX + th * 0.33 + 0.006, 0.948),
      Offset(kneeX + th * 0.36 + 0.012, 0.968),
      Offset(kneeX + th * 0.30 + 0.010, 0.981),
      Offset(kneeX, 0.986),
      Offset(kneeX - th * 0.30 - 0.002, 0.980),
      Offset(kneeX - th * 0.33 - 0.002, 0.955),
      Offset(kneeX - th * 0.31, ankleY),
      for (final y in const [0.87, 0.80, 0.75, kneeY, 0.67, 0.62, 0.57])
        Offset(legIn(y), y),
      const Offset(0, 0.532),
    ];
    final seg2L = [for (final p in seg2.reversed) _flip(p)];
    final seg1L = [for (final p in seg1.reversed) _flip(p)];
    final outline = Path()..moveTo(seg1.first.dx, seg1.first.dy);
    _splineTo(outline, seg1, before: _flip(seg1[1]));
    _splineTo(outline, seg2, after: _flip(seg2[seg2.length - 2]));
    _splineTo(outline, seg2L, before: seg2[seg2.length - 2]);
    _splineTo(outline, seg1L, after: seg1[1]);
    outline.close();
    silhouette.add(outline);

    // ---- Vùng cơ ----
    // Cơ delta (chỏm vai), giống nhau ở hai mặt.
    final deltoid = _blob([
      Offset(jx - a * 0.85, 0.190),
      Offset(jx + a * 0.10, 0.188),
      Offset(jx + a * 0.72, 0.200),
      Offset(armOut(0.232) - 0.005, 0.232),
      Offset(armX(0.256) + a * 0.55, 0.256),
      Offset(armX(0.266) + a * 0.05, 0.266),
      Offset(math.max(armX(0.240) - a * 0.60, armIn(0.240) + 0.003), 0.240),
      Offset(jx - a * 1.0, 0.212),
    ]);
    muscles['shoulders'] = _both([deltoid]);

    double armLo(double y) => armIn(y) + 0.004;
    double armHi(double y) => armOut(y) - 0.004;
    final upperArm = _spindle(0.274, 0.336, armLo, armHi, top: 0.3);
    final foreArm = _spindle(
      0.346,
      0.463,
      armLo,
      armHi,
      top: 0.5,
      bottom: 0.45,
    );
    muscles['arms'] = _both([upperArm, foreArm]);

    if (front) {
      // Ngực: hai mảng cong.
      final pecOuter = math.min(
        armX(0.240) - a * 0.60 - 0.008,
        torsoX(0.240) - 0.004,
      );
      final pec = _blob([
        const Offset(0.006, 0.200),
        Offset(sh * 0.45, 0.193),
        Offset(jx - a * 1.12, 0.197),
        Offset(jx - a * 1.15, 0.216),
        Offset(pecOuter, 0.240),
        Offset(ch * 0.80, 0.262),
        Offset(ch * 0.45, 0.274),
        const Offset(0.012, 0.268),
        const Offset(0.006, 0.235),
      ]);
      muscles['chest'] = _both([pec]);

      // Bụng: cơ thẳng bụng (6 múi) + cơ chéo hai bên.
      final aw = (w * 0.50).clamp(0.030, 0.058);
      final rectus = _symBlob([
        const Offset(0, 0.284),
        Offset(aw * 0.8, 0.286),
        Offset(aw, 0.300),
        Offset(aw, 0.400),
        Offset(aw * 0.82, 0.438),
        Offset(aw * 0.40, 0.466),
        const Offset(0, 0.478),
      ]);
      final oblique = _blob([
        Offset(aw + 0.009, 0.297),
        Offset(math.max(torsoX(0.292) - 0.008, aw + 0.014), 0.291),
        Offset(math.max(torsoX(0.335) - 0.007, aw + 0.015), 0.335),
        Offset(math.max(torsoX(0.385) - 0.007, aw + 0.015), 0.385),
        Offset(math.max(torsoX(0.435) - 0.009, aw + 0.014), 0.435),
        Offset(aw * 0.82 + 0.012, 0.458),
        Offset(aw + 0.009, 0.400),
      ]);
      muscles['abs'] = _both([oblique], [rectus]);
      creases.add(_line(const [Offset(0, 0.290), Offset(0, 0.470)]));
      for (final y in const [0.320, 0.358, 0.398]) {
        creases.add(
          _line([
            Offset(-aw, y + 0.004),
            Offset(-aw * 0.5, y + 0.001),
            Offset(0, y),
            Offset(aw * 0.5, y + 0.001),
            Offset(aw, y + 0.004),
          ]),
        );
      }

      // Chân: tứ đầu (3 múi) + cơ chày trước và mép trong bắp chân.
      muscles['legs'] = _both([
        _spindle(0.528, 0.676, legU(-0.44), legU(0.44), top: 0.6, bottom: 0.25),
        _spindle(0.546, 0.700, legU(0.52), legU(0.93), top: 0.35, bottom: 0.5),
        _spindle(
          0.548,
          0.612,
          legU(-0.93),
          legU(-0.52),
          top: 0.5,
          bottom: 0.25,
        ),
        _spindle(0.622, 0.708, legU(-0.93), legU(-0.52), top: 0.2, bottom: 0.7),
        _spindle(0.748, 0.895, legU(-0.08), legU(0.84), top: 0.5, bottom: 0.25),
        _spindle(
          0.745,
          0.862,
          legU(-0.88),
          legU(-0.20),
          top: 0.45,
          bottom: 0.2,
        ),
      ]);

      // Nét phụ: xương đòn, xương bánh chè.
      final clavicle = _line([
        Offset(0.010, 0.189),
        Offset(sh * 0.45, 0.184),
        Offset(jx - a * 1.1, 0.187),
      ]);
      final kneeR = legR(kneeY) * 0.42;
      final kneecap = Path()
        ..addOval(
          Rect.fromCenter(
            center: Offset(kneeX, kneeY + 0.004),
            width: kneeR * 2,
            height: 0.034,
          ),
        );
      details
        ..add(clavicle)
        ..add(_mirror(clavicle))
        ..add(kneecap)
        ..add(_mirror(kneecap));
    } else {
      // Lưng: cơ thang (hình thoi), cơ xô (chữ V), lưng dưới.
      final trap = _symBlob([
        const Offset(0, 0.138),
        Offset(nw * 0.8, 0.142),
        Offset(nw + 0.016, 0.170),
        Offset((nw + jx) / 2 + 0.006, 0.180),
        Offset(jx - a * 1.05, 0.186),
        Offset(jx - a * 1.10, 0.200),
        Offset(sh * 0.42, 0.232),
        Offset(sh * 0.20, 0.290),
        const Offset(0, 0.345),
      ]);
      final lat = _blob([
        Offset(sh * 0.42 + 0.012, 0.241),
        Offset(jx - a * 1.05, 0.217),
        Offset(torsoX(0.248) - 0.007, 0.248),
        Offset(torsoX(0.300) - 0.006, 0.300),
        Offset(torsoX(0.360) - 0.007, 0.360),
        Offset(w * 0.62, 0.412),
        const Offset(0.012, 0.372),
        Offset(sh * 0.20 + 0.014, 0.300),
      ]);
      final lowerBack = _symBlob([
        const Offset(0, 0.388),
        Offset(w * 0.32, 0.402),
        Offset(w * 0.62, 0.424),
        Offset(w * 0.52, 0.438),
        const Offset(0, 0.444),
      ]);
      muscles['back'] = _both([lat], [trap, lowerBack]);
      creases.add(_line(const [Offset(0, 0.150), Offset(0, 0.440)]));

      final glute = _blob([
        const Offset(0.005, 0.462),
        Offset(h * 0.5, 0.450),
        Offset(h - 0.010, 0.470),
        Offset(hipLow - 0.008, 0.505),
        Offset(legC(0.535) + th * 0.55, 0.536),
        Offset(math.max(legC(0.542) - th * 0.1, 0.020), 0.543),
        const Offset(0.006, 0.520),
      ]);
      muscles['glutes'] = _both([glute]);

      // Chân: gân kheo (2 múi) + bụng chân (2 múi).
      muscles['legs'] = _both([
        _spindle(0.558, 0.700, legU(-0.22), legU(0.88), top: 0.5, bottom: 0.4),
        _spindle(0.562, 0.704, legU(-0.88), legU(-0.32), top: 0.3, bottom: 0.5),
        _spindle(0.738, 0.852, legU(0.03), legU(0.86), top: 0.5, bottom: 0.3),
        _spindle(0.738, 0.858, legU(-0.86), legU(-0.05), top: 0.5, bottom: 0.3),
      ]);
    }

    // ---- Điểm đau ----
    List<Offset> both(Offset p) => [p, _flip(p)];
    painSpots['neck'] = const [Offset(0, 0.142)];
    painSpots['shoulder'] = both(Offset(jx, 0.200));
    painSpots['lower_back'] = const [Offset(0, 0.410)];
    painSpots['wrist'] = both(Offset(wx, wy));
    painSpots['hip'] = both(Offset(math.max(h - 0.02, 0.05), 0.478));
    painSpots['knee'] = both(Offset(kneeX, kneeY));
    painSpots['ankle'] = both(Offset(kneeX, ankleY));
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
