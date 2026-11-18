import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_palette.dart';
import 'anatomy_data.dart';
import 'body_figure.dart' show BodyFigureMode;
import 'body_geometry.dart';

/// Một mảng của hình giải phẫu đã dựng thành [Path] (toạ độ chuẩn hoá).
class AnatomyPart {
  AnatomyPart(this.slug, this.group, this.path) : bounds = path.getBounds();

  /// Tên cơ gốc (ví dụ `quadriceps`).
  final String slug;

  /// Nhóm cơ của app, hoặc `body` / `hair` với phần không chọn được.
  final String group;
  final Path path;
  final Rect bounds;

  bool get isMuscle => group != 'body' && group != 'hair';
}

/// Hình giải phẫu chi tiết (nam/nữ, mặt trước/sau) trong hệ toạ độ chuẩn hoá
/// giống [BodyGeometry]: cao 1.0, trục giữa x = 0. Dựng một lần rồi giữ lại.
///
/// Nét vẽ lấy từ react-native-body-highlighter (MIT, Copyright (c) 2022
/// ELABBASSI Hicham), xem `anatomy_data.dart` và `anatomy_license.dart`.
class AnatomyArt {
  AnatomyArt._(AnatomyViewData data)
    : outline = _parse(data.outline),
      parts = [
        for (final p in data.parts) AnatomyPart(p.slug, p.group, _parse(p.d)),
      ],
      painSpots = {
        for (final e in data.pain.entries)
          e.key: [
            for (var i = 0; i + 1 < e.value.length; i += 2)
              Offset(
                e.value[i] / kAnatomyUnits,
                e.value[i + 1] / kAnatomyUnits,
              ),
          ],
      };

  static final Map<int, AnatomyArt> _cache = {};

  /// Hình theo giới tính và mặt đang xem (dựng khi dùng lần đầu).
  factory AnatomyArt.of({required bool female, required BodySide side}) {
    final key = (female ? 2 : 0) + (side == BodySide.back ? 1 : 0);
    return _cache.putIfAbsent(
      key,
      () => AnatomyArt._(switch (key) {
        0 => kAnatomyMaleFront,
        1 => kAnatomyMaleBack,
        2 => kAnatomyFemaleFront,
        _ => kAnatomyFemaleBack,
      }),
    );
  }

  /// Tỉ lệ rộng / cao của khung vẽ (trùng [BodyGeometry.aspect]).
  static const double aspect = BodyGeometry.aspect;
  static const double painRadius = 0.022;
  static const double painHitRadius = 0.05;

  /// Chạm lệch khỏi mảng cơ trong khoảng này vẫn tính (khe giữa các múi cơ).
  static const double _hitSlop = 0.014;

  /// Đường viền thân người.
  final Path outline;

  /// Mọi mảng theo thứ tự vẽ.
  final List<AnatomyPart> parts;

  /// Tâm các điểm đau theo tên vùng.
  final Map<String, List<Offset>> painSpots;

  /// Các nhóm cơ có mặt ở hình này.
  late final Set<String> groups = {
    for (final p in parts)
      if (p.isMuscle) p.group,
  };

  String? _hit(Offset p) {
    for (final part in parts) {
      if (part.isMuscle && part.bounds.contains(p) && part.path.contains(p)) {
        return part.group;
      }
    }
    return null;
  }

  /// Nhóm cơ tại điểm [p] (toạ độ chuẩn hoá), null nếu không trúng.
  /// Chạm vào bất kỳ cơ con nào cũng trả về cả nhóm.
  String? muscleAt(Offset p) {
    final direct = _hit(p);
    if (direct != null) return direct;
    for (final r in const [_hitSlop / 2, _hitSlop]) {
      for (final d in _ring) {
        final id = _hit(p + d * r);
        if (id != null) return id;
      }
    }
    return null;
  }

  static const List<Offset> _ring = [
    Offset(1, 0),
    Offset(-1, 0),
    Offset(0, 1),
    Offset(0, -1),
    Offset(0.7, 0.7),
    Offset(-0.7, 0.7),
    Offset(0.7, -0.7),
    Offset(-0.7, -0.7),
  ];

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

  static Offset toNormalized(Offset local, Size size) =>
      BodyGeometry.toNormalized(local, size);

  static Offset toLocal(Offset normalized, Size size) =>
      BodyGeometry.toLocal(normalized, size);

  /// Đọc đường nét rút gọn trong `anatomy_data.dart`:
  /// `M x y` tuyệt đối, `l dx dy` và `c` (6 số) tương đối, `z` đóng nét.
  static Path _parse(String d) {
    const k = 1 / kAnatomyUnits;
    final path = Path();
    final n = d.length;
    final v = Float64List(6);
    var i = 0;
    var x = 0.0, y = 0.0, sx = 0.0, sy = 0.0;
    while (i < n) {
      final cmd = d.codeUnitAt(i++);
      if (cmd == 0x7A) {
        path.close();
        x = sx;
        y = sy;
        continue;
      }
      final count = cmd == 0x63 ? 6 : 2;
      for (var j = 0; j < count; j++) {
        if (i < n && d.codeUnitAt(i) == 0x20) i++;
        var neg = false;
        if (i < n && d.codeUnitAt(i) == 0x2D) {
          neg = true;
          i++;
        }
        var value = 0;
        while (i < n) {
          final c = d.codeUnitAt(i) - 0x30;
          if (c < 0 || c > 9) break;
          value = value * 10 + c;
          i++;
        }
        v[j] = (neg ? -value : value) * k;
      }
      switch (cmd) {
        case 0x4D: // M
          x = sx = v[0];
          y = sy = v[1];
          path.moveTo(x, y);
        case 0x6C: // l
          x += v[0];
          y += v[1];
          path.lineTo(x, y);
        case 0x63: // c
          path.cubicTo(
            x + v[0],
            y + v[1],
            x + v[2],
            y + v[3],
            x + v[4],
            y + v[5],
          );
          x += v[4];
          y += v[5];
        default:
          throw FormatException('Lệnh đường nét lạ: ${d[i - 1]}');
      }
    }
    return path;
  }
}

/// Bản đồ cơ chi tiết: chọn nhóm cơ, chọn vùng đau hoặc tô mức đã tập.
/// Chạm vào bất kỳ cơ nào cũng chọn cả nhóm (mọi mảng của nhóm, cả hai bên).
class AnatomyMap extends StatelessWidget {
  const AnatomyMap({
    super.key,
    required this.female,
    this.side = BodySide.front,
    this.mode = BodyFigureMode.selectMuscles,
    this.selected = const {},
    this.heat = const {},
    this.onToggle,
  });

  final bool female;
  final BodySide side;
  final BodyFigureMode mode;

  /// Nhóm cơ (selectMuscles) hoặc vùng đau (selectPain) đang chọn.
  final Set<String> selected;

  /// Mức 0..1 theo nhóm cơ, dùng ở chế độ heat.
  final Map<String, double> heat;

  /// Gọi khi người dùng chạm vào một nhóm cơ / vùng đau.
  final ValueChanged<String>? onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final art = AnatomyArt.of(female: female, side: side);
    final interactive =
        onToggle != null &&
        (mode == BodyFigureMode.selectMuscles ||
            mode == BodyFigureMode.selectPain);

    return AspectRatio(
      aspectRatio: AnatomyArt.aspect,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final paint = CustomPaint(
            size: size,
            painter: AnatomyPainter(
              art: art,
              mode: mode,
              selected: selected,
              heat: heat,
              baseColor: c.isDark
                  ? const Color(0xFF2E3550)
                  : const Color(0xFFEDF0F7),
              regionColor: c.isDark
                  ? const Color(0xFF505B7D)
                  : const Color(0xFFCBD2E3),
              lineColor: c.isDark
                  ? const Color(0xFF66719A)
                  : const Color(0xFFA9B4CC),
              hairColor: c.isDark
                  ? const Color(0xFF7783A6)
                  : const Color(0xFF98A3BF),
              activeColor: c.buttonFill,
              painColor: c.errorText,
              outlineColor: c.surface,
              dark: c.isDark,
            ),
          );
          if (!interactive) return paint;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final p = AnatomyArt.toNormalized(details.localPosition, size);
              final id = mode == BodyFigureMode.selectPain
                  ? art.painAt(p)
                  : art.muscleAt(p);
              if (id != null) onToggle!(id);
            },
            child: paint,
          );
        },
      ),
    );
  }
}

class AnatomyPainter extends CustomPainter {
  AnatomyPainter({
    required this.art,
    required this.mode,
    required Set<String> selected,
    required Map<String, double> heat,
    required this.baseColor,
    required this.regionColor,
    required this.lineColor,
    required this.hairColor,
    required this.activeColor,
    required this.painColor,
    required this.outlineColor,
    this.dark = false,
  }) : selected = Set.of(selected),
       heat = Map.of(heat);

  final AnatomyArt art;
  final BodyFigureMode mode;
  final Set<String> selected;
  final Map<String, double> heat;

  /// Màu nền thân người.
  final Color baseColor;

  /// Màu mảng cơ khi chưa chọn.
  final Color regionColor;

  /// Màu nét viền thân.
  final Color lineColor;
  final Color hairColor;
  final Color activeColor;
  final Color painColor;

  /// Màu nền thẻ phía sau (dùng cho chấm điểm đau chưa chọn).
  final Color outlineColor;
  final bool dark;

  static const Color _white = Color(0xFFFFFFFF);
  static const Color _black = Color(0xFF000000);

  static Shader _vertical(Rect r, Color top, Color bottom) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [top, bottom],
  ).createShader(r);

  /// Mức tô 0..1 của một nhóm cơ theo chế độ hiện tại.
  double _level(String group) {
    switch (mode) {
      case BodyFigureMode.heat:
        final v = (heat[group] ?? 0).clamp(0.0, 1.0).toDouble();
        return v <= 0 ? 0 : 0.35 + 0.65 * v;
      case BodyFigureMode.selectMuscles:
        return selected.contains(group) ? 1 : 0;
      case BodyFigureMode.display:
      case BodyFigureMode.selectPain:
        return 0;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = BodyGeometry.scaleFor(size);
    if (scale <= 0) return;
    canvas.save();
    canvas.translate(size.width / 2, (size.height - scale) / 2);
    canvas.scale(scale);

    // Bề dày nét không nhỏ hơn [minPx] điểm ảnh để hình thu nhỏ vẫn rõ.
    double px(double v, double minPx) => v > minPx / scale ? v : minPx / scale;
    const frame = Rect.fromLTRB(
      -AnatomyArt.aspect / 2,
      0,
      AnatomyArt.aspect / 2,
      1,
    );

    final quiet =
        mode == BodyFigureMode.display || mode == BodyFigureMode.selectPain;
    final baseTop = Color.lerp(baseColor, _white, dark ? 0.04 : 0.30)!;
    final baseBottom = Color.lerp(baseColor, _black, dark ? 0.10 : 0.03)!;
    final idleTop = Color.lerp(regionColor, baseColor, quiet ? 0.45 : 0.22)!;
    final idleBottom = Color.lerp(
      regionColor,
      dark ? _black : lineColor,
      quiet ? 0.0 : 0.14,
    )!;
    final skin = Color.lerp(baseColor, regionColor, dark ? 0.80 : 0.42)!;

    // 0. Tóc nằm sau thân.
    for (final part in art.parts) {
      if (part.group != 'hair') continue;
      canvas.drawPath(
        part.path,
        Paint()
          ..isAntiAlias = true
          ..shader = _vertical(
            part.bounds,
            Color.lerp(hairColor, _white, dark ? 0.08 : 0.14)!,
            Color.lerp(hairColor, _black, dark ? 0.10 : 0.06)!,
          ),
      );
    }

    // 1. Thân người: nền chuyển sắc nhẹ + bóng mép trong tạo khối.
    canvas.drawPath(
      art.outline,
      Paint()
        ..isAntiAlias = true
        ..shader = _vertical(frame, baseTop, baseBottom),
    );
    canvas.save();
    canvas.clipPath(art.outline);
    canvas.drawPath(
      art.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.022
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.008)
        ..color = (dark ? _black : lineColor).withValues(
          alpha: dark ? 0.28 : 0.30,
        ),
    );
    canvas.restore();

    // 2. Quầng sáng dưới các mảng đang chọn / đã tập.
    final levels = {for (final g in art.groups) g: _level(g)};
    for (final part in art.parts) {
      final v = levels[part.group] ?? 0;
      if (v <= 0) continue;
      canvas.drawPath(
        part.path,
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.010)
          ..color = activeColor.withValues(alpha: (dark ? 0.50 : 0.36) * v),
      );
    }

    // 3. Các mảng: phần thân (đầu, bàn tay, gối...) và cơ.
    for (final part in art.parts) {
      if (part.group == 'hair') continue;
      final Color top, bottom;
      final v = levels[part.group] ?? 0;
      if (!part.isMuscle) {
        top = Color.lerp(skin, _white, dark ? 0.03 : 0.25)!;
        bottom = skin;
      } else if (v <= 0) {
        top = idleTop;
        bottom = idleBottom;
      } else {
        final strong = Color.lerp(idleBottom, activeColor, v)!;
        top = Color.lerp(strong, _white, 0.18)!;
        bottom = Color.lerp(strong, _black, 0.06)!;
      }
      canvas.drawPath(
        part.path,
        Paint()
          ..isAntiAlias = true
          ..shader = _vertical(part.bounds, top, bottom),
      );
      if (part.isMuscle) {
        // Viền sáng mảnh cho cảm giác nổi khối.
        canvas.drawPath(
          part.path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = px(0.0016, 0.4)
            ..color = (v > 0 ? _white : baseTop).withValues(
              alpha: v > 0 ? 0.30 : (dark ? 0.22 : 0.60),
            ),
        );
      }
    }

    // 4. Viền thân liền nét.
    canvas.drawPath(
      art.outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..strokeWidth = px(0.0030, 0.8)
        ..color = lineColor.withValues(alpha: dark ? 0.85 : 0.90),
    );

    // 5. Điểm đau: vòng + chấm.
    if (mode == BodyFigureMode.selectPain) {
      const r = AnatomyArt.painRadius;
      art.painSpots.forEach((id, centers) {
        final on = selected.contains(id);
        for (final center in centers) {
          if (on) {
            canvas.drawCircle(
              center,
              r * 1.6,
              Paint()
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.006)
                ..color = painColor.withValues(alpha: 0.32),
            );
          }
          canvas.drawCircle(
            center,
            r,
            Paint()
              ..color = on ? painColor : outlineColor.withValues(alpha: 0.92),
          );
          canvas.drawCircle(
            center,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = px(0.0050, 1)
              ..color = on ? painColor : lineColor,
          );
          canvas.drawCircle(
            center,
            r * 0.34,
            Paint()..color = on ? (dark ? _black : _white) : lineColor,
          );
        }
      });
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(AnatomyPainter old) =>
      !identical(old.art, art) ||
      old.mode != mode ||
      !setEquals(old.selected, selected) ||
      !mapEquals(old.heat, heat) ||
      old.baseColor != baseColor ||
      old.regionColor != regionColor ||
      old.lineColor != lineColor ||
      old.hairColor != hairColor ||
      old.activeColor != activeColor ||
      old.painColor != painColor ||
      old.outlineColor != outlineColor;
}
