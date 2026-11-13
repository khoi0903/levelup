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
                  ? const Color(0xFF3A4152)
                  : const Color(0xFFDDE2EE),
              regionColor: c.isDark
                  ? const Color(0xFF4A5266)
                  : const Color(0xFFCBD2E2),
              activeColor: c.buttonFill,
              painColor: c.errorText,
              outlineColor: c.surface,
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
  });

  final BodyGeometry geometry;
  final BodyFigureMode mode;
  final Set<String> selected;
  final Map<String, double> heat;
  final Color baseColor;
  final Color regionColor;
  final Color activeColor;
  final Color painColor;
  final Color outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = BodyGeometry.scaleFor(size);
    canvas.save();
    canvas.translate(size.width / 2, (size.height - scale) / 2);
    canvas.scale(scale);

    final base = Paint()
      ..color = baseColor
      ..isAntiAlias = true;
    for (final part in geometry.silhouette) {
      canvas.drawPath(part, base);
    }

    if (mode == BodyFigureMode.selectMuscles || mode == BodyFigureMode.heat) {
      final gap = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.006
        ..color = outlineColor.withValues(alpha: 0.9);
      geometry.muscles.forEach((id, path) {
        final Color color;
        if (mode == BodyFigureMode.heat) {
          final v = (heat[id] ?? 0).clamp(0.0, 1.0);
          color = v <= 0
              ? regionColor.withValues(alpha: 0.45)
              : Color.lerp(
                  activeColor.withValues(alpha: 0.35),
                  activeColor,
                  v,
                )!;
        } else {
          color = selected.contains(id) ? activeColor : regionColor;
        }
        canvas.drawPath(path, Paint()..color = color);
        canvas.drawPath(path, gap);
      });
    }

    if (mode == BodyFigureMode.selectPain) {
      geometry.painSpots.forEach((id, centers) {
        final on = selected.contains(id);
        for (final center in centers) {
          if (on) {
            canvas.drawCircle(
              center,
              BodyGeometry.painRadius * 1.5,
              Paint()..color = painColor.withValues(alpha: 0.22),
            );
          }
          canvas.drawCircle(
            center,
            BodyGeometry.painRadius,
            Paint()..color = on ? painColor : outlineColor,
          );
          canvas.drawCircle(
            center,
            BodyGeometry.painRadius,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.006
              ..color = on ? painColor : regionColor,
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
      old.activeColor != activeColor;
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
