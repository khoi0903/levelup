import 'package:flutter/material.dart';

import '../../../../core/constants/app_palette.dart';
import '../../domain/models/body_shape.dart';
import 'body_geometry.dart';

export 'body_geometry.dart' show BodySide, BodyGeometry;

enum BodyFigureMode {
  /// Chỉ hiện hình người.
  display,

  /// Chạm để chọn nhiều nhóm cơ.
  selectMuscles,

  /// Chạm để chọn nhiều vùng đau.
  selectPain,

  /// Tô đậm nhạt theo mức đã tập (0..1 cho mỗi nhóm cơ).
  heat,
}

/// Hình người 2D (mặt trước / sau), vẽ bằng CustomPainter.
/// Vóc dáng lấy từ [shape]; không gắn nhãn đánh giá cơ thể.
class BodyFigure extends StatelessWidget {
  const BodyFigure({
    super.key,
    required this.shape,
    this.side = BodySide.front,
    this.mode = BodyFigureMode.display,
    this.selected = const {},
    this.heat = const {},
    this.onToggle,
  });

  final BodyShape shape;
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
    final geometry = BodyGeometry(shape, side);
    final interactive =
        onToggle != null &&
        (mode == BodyFigureMode.selectMuscles ||
            mode == BodyFigureMode.selectPain);

    return AspectRatio(
      aspectRatio: BodyGeometry.aspect,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final paint = CustomPaint(
            size: size,
            painter: BodyFigurePainter(
              geometry: geometry,
              mode: mode,
              selected: selected,
              heat: heat,
              baseColor: c.isDark
                  ? const Color(0xFF3B4254)
                  : const Color(0xFFE1E5EF),
              regionColor: c.isDark
                  ? const Color(0xFF525B73)
                  : const Color(0xFFC6CEDF),
              lineColor: c.isDark
                  ? const Color(0xFF687390)
                  : const Color(0xFFA9B4CC),
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
              final p = BodyGeometry.toNormalized(details.localPosition, size);
              final id = mode == BodyFigureMode.selectPain
                  ? geometry.painAt(p)
                  : geometry.muscleAt(p);
              if (id != null) onToggle!(id);
            },
            child: paint,
          );
        },
      ),
    );
  }
}

class BodyFigurePainter extends CustomPainter {
  BodyFigurePainter({
    required this.geometry,
    required this.mode,
    required this.selected,
    required this.heat,
    required this.baseColor,
    required this.regionColor,
    required this.activeColor,
    required this.painColor,
    required this.outlineColor,
    Color? lineColor,
    this.dark = false,
  }) : lineColor = lineColor ?? regionColor;

  final BodyGeometry geometry;
  final BodyFigureMode mode;
  final Set<String> selected;
  final Map<String, double> heat;

  /// Màu nền thân người.
  final Color baseColor;

  /// Màu mảng cơ khi chưa chọn.
  final Color regionColor;

  /// Màu nét viền thân và nét phụ.
  final Color lineColor;
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
  double _level(String id) {
    switch (mode) {
      case BodyFigureMode.heat:
        final v = (heat[id] ?? 0).clamp(0.0, 1.0).toDouble();
        return v <= 0 ? 0 : 0.35 + 0.65 * v;
      case BodyFigureMode.selectMuscles:
        return selected.contains(id) ? 1 : 0;
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
      -BodyGeometry.aspect / 2,
      0,
      BodyGeometry.aspect / 2,
      1,
    );

    // 1. Thân người: nền chuyển sắc nhẹ + bóng mép trong tạo khối.
    final body = geometry.silhouette;
    final baseTop = Color.lerp(baseColor, _white, dark ? 0.06 : 0.35)!;
    final baseBottom = Color.lerp(baseColor, _black, dark ? 0.12 : 0.05)!;
    final fill = Paint()
      ..isAntiAlias = true
      ..shader = _vertical(frame, baseTop, baseBottom);
    for (final part in body) {
      canvas.drawPath(part, fill);
    }
    for (final part in body) {
      canvas.save();
      canvas.clipPath(part);
      canvas.drawPath(
        part,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.030
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.011)
          ..color = (dark ? _black : lineColor).withValues(
            alpha: dark ? 0.30 : 0.38,
          ),
      );
      canvas.restore();
    }

    // 2. Mảng cơ.
    final quiet =
        mode == BodyFigureMode.display || mode == BodyFigureMode.selectPain;
    final idleTop = Color.lerp(regionColor, baseColor, quiet ? 0.50 : 0.18)!;
    final idleBottom = Color.lerp(
      regionColor,
      dark ? _black : lineColor,
      quiet ? 0.0 : 0.22,
    )!;
    final levels = {for (final id in geometry.muscles.keys) id: _level(id)};

    // Quầng sáng dưới các mảng đang chọn / đã tập.
    geometry.muscles.forEach((id, path) {
      final v = levels[id]!;
      if (v <= 0) return;
      canvas.drawPath(
        path,
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.012)
          ..color = activeColor.withValues(alpha: 0.42 * v),
      );
    });
    geometry.muscles.forEach((id, path) {
      final v = levels[id]!;
      final Color top, bottom;
      if (v <= 0) {
        top = idleTop;
        bottom = idleBottom;
      } else {
        final strong = Color.lerp(idleBottom, activeColor, v)!;
        top = Color.lerp(strong, _white, 0.20)!;
        bottom = Color.lerp(strong, _black, 0.06)!;
      }
      canvas.drawPath(
        path,
        Paint()
          ..isAntiAlias = true
          ..shader = _vertical(path.getBounds(), top, bottom),
      );
      // Viền sáng mảnh quanh mỗi mảng cơ cho cảm giác nổi khối.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = px(0.0022, 0.5)
          ..color = (v > 0 ? _white : baseTop).withValues(
            alpha: v > 0 ? 0.28 : (dark ? 0.25 : 0.65),
          ),
      );
    });

    // 3. Nét tách múi cơ và nét phụ.
    final crease = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = px(0.0048, 0.8)
      ..color = Color.lerp(baseTop, baseBottom, 0.4)!;
    for (final path in geometry.creases) {
      canvas.drawPath(path, crease);
    }
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = px(0.0030, 0.7)
      ..color = lineColor.withValues(alpha: 0.75);
    for (final path in geometry.details) {
      canvas.drawPath(path, line);
    }

    // 4. Viền thân liền nét.
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = px(0.0036, 0.9)
      ..color = lineColor;
    for (final part in body) {
      canvas.drawPath(part, outline);
    }

    // 5. Điểm đau.
    if (mode == BodyFigureMode.selectPain) {
      geometry.painSpots.forEach((id, centers) {
        final on = selected.contains(id);
        for (final center in centers) {
          if (on) {
            canvas.drawCircle(
              center,
              BodyGeometry.painRadius * 1.55,
              Paint()
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.006)
                ..color = painColor.withValues(alpha: 0.30),
            );
          }
          canvas.drawCircle(
            center,
            BodyGeometry.painRadius,
            Paint()
              ..color = on ? painColor : outlineColor.withValues(alpha: 0.92),
          );
          canvas.drawCircle(
            center,
            BodyGeometry.painRadius,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = px(0.0055, 1)
              ..color = on ? painColor : lineColor,
          );
          canvas.drawCircle(
            center,
            BodyGeometry.painRadius * 0.34,
            Paint()..color = on ? _white : lineColor,
          );
        }
      });
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BodyFigurePainter old) =>
      old.geometry.shape != geometry.shape ||
      old.geometry.side != geometry.side ||
      old.mode != mode ||
      old.selected != selected ||
      old.heat != heat ||
      old.baseColor != baseColor ||
      old.regionColor != regionColor ||
      old.lineColor != lineColor ||
      old.activeColor != activeColor ||
      old.painColor != painColor ||
      old.outlineColor != outlineColor;
}

/// Nút đổi "Mặt trước" / "Mặt sau".
class BodySideToggle extends StatelessWidget {
  const BodySideToggle({
    super.key,
    required this.side,
    required this.onChanged,
  });

  final BodySide side;
  final ValueChanged<BodySide> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget item(BodySide value, String label) {
      final on = side == value;
      return GestureDetector(
        key: ValueKey('body-side-${value.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? c.buttonFill : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: on ? Colors.white : c.textSecondary,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.mutedBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          item(BodySide.front, 'Mặt trước'),
          item(BodySide.back, 'Mặt sau'),
        ],
      ),
    );
  }
}

/// Bản đồ cơ có nút đổi mặt và hàng chip (chọn được cả khi khó chạm vào hình).
class MuscleMapPicker extends StatefulWidget {
  const MuscleMapPicker({
    super.key,
    required this.shape,
    required this.selected,
    required this.onToggle,
    this.figureHeight = 300,
  });

  final BodyShape shape;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final double figureHeight;

  @override
  State<MuscleMapPicker> createState() => _MuscleMapPickerState();
}

class _MuscleMapPickerState extends State<MuscleMapPicker> {
  BodySide _side = BodySide.front;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BodySideToggle(
          side: _side,
          onChanged: (s) => setState(() => _side = s),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: widget.figureHeight,
          child: BodyFigure(
            key: const ValueKey('muscle-map-figure'),
            shape: widget.shape,
            side: _side,
            mode: BodyFigureMode.selectMuscles,
            selected: widget.selected,
            onToggle: widget.onToggle,
          ),
        ),
        const SizedBox(height: 14),
        BodyChipWrap(
          keyPrefix: 'muscle-chip',
          ids: kMuscleGroups,
          labels: kMuscleLabels,
          selected: widget.selected,
          onToggle: widget.onToggle,
        ),
      ],
    );
  }
}

/// Bản đồ vùng đau + chip, có lựa chọn "Không đau chỗ nào".
class PainMapPicker extends StatefulWidget {
  const PainMapPicker({
    super.key,
    required this.shape,
    required this.selected,
    required this.onToggle,
    required this.onClear,
    this.figureHeight = 280,
  });

  final BodyShape shape;

  /// Tên vùng đau đang chọn (theo `BodyArea`, gồm cả `other`).
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final VoidCallback onClear;
  final double figureHeight;

  @override
  State<PainMapPicker> createState() => _PainMapPickerState();
}

class _PainMapPickerState extends State<PainMapPicker> {
  BodySide _side = BodySide.front;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BodySideToggle(
          side: _side,
          onChanged: (s) => setState(() => _side = s),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: widget.figureHeight,
          child: BodyFigure(
            key: const ValueKey('pain-map-figure'),
            shape: widget.shape,
            side: _side,
            mode: BodyFigureMode.selectPain,
            selected: widget.selected,
            onToggle: widget.onToggle,
          ),
        ),
        const SizedBox(height: 14),
        BodyChipWrap(
          keyPrefix: 'pain-chip',
          ids: const [...kPainAreas, 'other'],
          labels: kPainLabels,
          selected: widget.selected,
          onToggle: widget.onToggle,
          leading: _BodyChip(
            key: const ValueKey('pain-chip-none'),
            label: 'Không đau chỗ nào',
            selected: widget.selected.isEmpty,
            onTap: widget.onClear,
          ),
        ),
      ],
    );
  }
}

class BodyChipWrap extends StatelessWidget {
  const BodyChipWrap({
    super.key,
    required this.keyPrefix,
    required this.ids,
    required this.labels,
    required this.selected,
    required this.onToggle,
    this.leading,
  });

  final String keyPrefix;
  final List<String> ids;
  final Map<String, String> labels;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        ?leading,
        for (final id in ids)
          _BodyChip(
            key: ValueKey('$keyPrefix-$id'),
            label: labels[id] ?? id,
            selected: selected.contains(id),
            onTap: () => onToggle(id),
          ),
      ],
    );
  }
}

class _BodyChip extends StatelessWidget {
  const _BodyChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: selected ? c.cardSelectedBg : c.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? c.cardSelectedBorder : c.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? c.primary : c.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 5 hình thu nhỏ theo các mức tỉ lệ mỡ gợi ý; chạm để chọn.
class BodyShapePicker extends StatelessWidget {
  const BodyShapePicker({
    super.key,
    required this.bmi,
    required this.female,
    required this.selectedPct,
    required this.onSelected,
    this.thumbHeight = 150,
  });

  final double? bmi;
  final bool female;
  final int? selectedPct;
  final ValueChanged<int> onSelected;
  final double thumbHeight;

  /// BMI dùng để vẽ mỗi hình: lệch nhẹ quanh BMI thật để 5 hình khác nhau rõ.
  static double thumbBmi(double? bmi, int index) =>
      ((bmi ?? 22) + (index - 2) * 1.6).clamp(
        BodyShape.minBmi,
        BodyShape.maxBmi,
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final presets = bodyFatPresets(female: female);
    return Row(
      children: [
        for (var i = 0; i < presets.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                key: ValueKey('body-shape-${presets[i]}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(presets[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selectedPct == presets[i]
                        ? c.cardSelectedBg
                        : c.cardNormalBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selectedPct == presets[i]
                          ? c.cardSelectedBorder
                          : c.cardNormalBorder,
                      width: selectedPct == presets[i] ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: thumbHeight,
                        child: BodyFigure(
                          shape: BodyShape.from(
                            bmi: thumbBmi(bmi, i),
                            bodyFatPct: presets[i],
                            female: female,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: selectedPct == presets[i]
                              ? c.primary
                              : c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
