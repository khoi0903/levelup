import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_palette.dart';
import '../../domain/models/nutrition_models.dart';
import '../controllers/nutrition_controller.dart';

const _proteinColor = Color(0xFF4B63E8);
const _carbsColor = Color(0xFFF5A623);
const _fatColor = Color(0xFFE8618C);

/// Tỉ lệ năng lượng từ đạm/tinh bột/chất béo (4/4/9 kcal mỗi gam), tổng = 1; món không có số liệu trả 0.
({double protein, double carbs, double fat}) macroShares(Macros m) {
  final p = math.max(0.0, m.proteinG) * 4;
  final c = math.max(0.0, m.carbsG) * 4;
  final f = math.max(0.0, m.fatG) * 9;
  final total = p + c + f;
  if (total <= 0) return (protein: 0, carbs: 0, fat: 0);
  return (protein: p / total, carbs: c / total, fat: f / total);
}

/// Chi tiết một món: biểu đồ vòng đạm/tinh bột/chất béo, kcal và phần trăm so với mục tiêu hôm nay.
Future<void> showFoodDetailSheet(
  BuildContext context, {
  required String name,
  required Macros macros,
  required double grams,
  String servingDesc = '',
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: context.colors.surface,
  builder: (_) => FoodDetailSheet(
    name: name,
    macros: macros,
    grams: grams,
    servingDesc: servingDesc,
  ),
);

class FoodDetailSheet extends ConsumerWidget {
  const FoodDetailSheet({
    super.key,
    required this.name,
    required this.macros,
    required this.grams,
    this.servingDesc = '',
  });
  final String name, servingDesc;
  final Macros macros;
  final double grams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final target = ref
        .watch(nutritionTodayProvider)
        .valueOrNull
        ?.target
        ?.macros;
    final shares = macroShares(macros);
    String pct(double v) => '${(v * 100).round()}%';
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              key: const ValueKey('food-detail-name'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              [
                if (servingDesc.isNotEmpty) servingDesc,
                '${grams.round()} g',
              ].join(' • '),
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CustomPaint(
                    key: const ValueKey('food-detail-donut'),
                    painter: MacroDonutPainter(
                      protein: shares.protein,
                      carbs: shares.carbs,
                      fat: shares.fat,
                      track: colors.progressTrack,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${macros.kcal.round()}',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              const Text('kcal'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Legend(
                        color: _proteinColor,
                        label:
                            'Đạm ${macros.proteinG.toStringAsFixed(1)} g • ${pct(shares.protein)}',
                      ),
                      _Legend(
                        color: _carbsColor,
                        label:
                            'Tinh bột ${macros.carbsG.toStringAsFixed(1)} g • ${pct(shares.carbs)}',
                      ),
                      _Legend(
                        color: _fatColor,
                        label:
                            'Chất béo ${macros.fatG.toStringAsFixed(1)} g • ${pct(shares.fat)}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              '% mục tiêu ngày',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (target == null)
              Text(
                'Chưa có mục tiêu dinh dưỡng để so sánh.',
                style: TextStyle(color: colors.textSecondary),
              )
            else ...[
              _TargetBar(
                label: 'Calo',
                value: macros.kcal,
                target: target.kcal,
                unit: 'kcal',
                color: colors.progressFill,
              ),
              _TargetBar(
                label: 'Đạm',
                value: macros.proteinG,
                target: target.proteinG,
                unit: 'g',
                color: _proteinColor,
              ),
              _TargetBar(
                label: 'Tinh bột',
                value: macros.carbsG,
                target: target.carbsG,
                unit: 'g',
                color: _carbsColor,
              ),
              _TargetBar(
                label: 'Chất béo',
                value: macros.fatG,
                target: target.fatG,
                unit: 'g',
                color: _fatColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
      ],
    ),
  );
}

class _TargetBar extends StatelessWidget {
  const _TargetBar({
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
    required this.color,
  });
  final String label, unit;
  final double value, target;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final ratio = target > 0 ? value / target : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                '${(ratio * 100).round()}% • ${value.round()}/${target.round()} $unit',
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              color: color,
              backgroundColor: context.colors.progressTrack,
            ),
          ),
        ],
      ),
    );
  }
}

class MacroDonutPainter extends CustomPainter {
  const MacroDonutPainter({
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.track,
  });
  final double protein, carbs, fat;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    var start = -math.pi / 2;
    for (final (share, color) in [
      (protein, _proteinColor),
      (carbs, _carbsColor),
      (fat, _fatColor),
    ]) {
      if (share <= 0) continue;
      final sweep = share * math.pi * 2;
      canvas.drawArc(rect, start, sweep, false, paint..color = color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(MacroDonutPainter old) =>
      old.protein != protein ||
      old.carbs != carbs ||
      old.fat != fat ||
      old.track != track;
}
