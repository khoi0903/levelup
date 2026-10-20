import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_palette.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/models/progress_models.dart';

class MeasurementPoint {
  const MeasurementPoint(this.date, this.value);
  final DateTime date;
  final double value;
}

List<MeasurementPoint> measurementPoints(
  List<Measurement> items, {
  required bool waist,
}) =>
    items
        .where((e) => (waist ? e.waistCm : e.weightKg) != null)
        .map(
          (e) => MeasurementPoint(
            DateTime.parse('${e.measuredOn}T00:00:00Z'),
            (waist ? e.waistCm : e.weightKg)!,
          ),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

class MeasurementChart extends StatelessWidget {
  const MeasurementChart({super.key, required this.items, required this.waist});
  final List<Measurement> items;
  final bool waist;
  @override
  Widget build(BuildContext context) {
    final points = measurementPoints(items, waist: waist);
    final title = waist ? 'Vòng eo' : 'Cân nặng';
    final unit = waist ? 'cm' : 'kg';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title • 90 ngày',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          if (points.isEmpty)
            Text('Chưa có dữ liệu ${title.toLowerCase()}.')
          else ...[
            Text(
              '${points.last.value.toStringAsFixed(1)} $unit',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (points.length > 1)
              Text(
                'Thay đổi ${(points.last.value - points.first.value).toStringAsFixed(1)} $unit',
              ),
            const SizedBox(height: 12),
            Semantics(
              label:
                  '$title. ${points.map((e) => '${e.date.toIso8601String().substring(0, 10)}: ${e.value} $unit').join('; ')}',
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: CustomPaint(
                  painter: _MeasurementPainter(
                    points,
                    Theme.of(context).textTheme.labelSmall!
                        .copyWith(color: context.colors.textSecondary, fontSize: 10),
                    context.colors,
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text(_date(points.first.date))),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _date(points.last.date),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            if (points.length == 1) const Text('Thêm lần đo để xem xu hướng.'),
            Material(
              color: context.colors.surface,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Xem các lần đo'),
                children: points
                    .map(
                      (p) => ListTile(
                        title: Text(_date(p.date)),
                        trailing: Text('${p.value} $unit'),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
}

class _MeasurementPainter extends CustomPainter {
  _MeasurementPainter(this.points, this.axisStyle, this.colors);
  final List<MeasurementPoint> points;
  final TextStyle axisStyle;
  final AppPalette colors;
  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0, top = 12.0, bottom = 12.0;
    final width = math.max(1.0, size.width - left - 8);
    final height = math.max(1.0, size.height - top - bottom);
    final minValue = points.map((p) => p.value).reduce(math.min);
    final maxValue = points.map((p) => p.value).reduce(math.max);
    final pad = math.max(1.0, (maxValue - minValue) * .15);
    final low = minValue - pad, high = maxValue + pad;
    final span = math.max(
      1,
      points.last.date.difference(points.first.date).inDays,
    );
    final grid = Paint()
      ..color = colors.border
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = top + height * i / 2;
      canvas.drawLine(Offset(left, y), Offset(left + width, y), grid);
      final label = TextPainter(
        text: TextSpan(
          text: (high - (high - low) * i / 2).toStringAsFixed(1),
          style: axisStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(0, y - label.height / 2));
    }
    final offsets = points
        .map(
          (p) => Offset(
            left +
                (points.length == 1
                    ? width / 2
                    : width *
                          p.date.difference(points.first.date).inDays /
                          span),
            top + height * (high - p.value) / (high - low),
          ),
        )
        .toList();
    final paint = Paint()
      ..color = colors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final offset in offsets.skip(1)) {
      path.lineTo(offset.dx, offset.dy);
    }
    canvas.drawPath(path, paint);
    paint.style = PaintingStyle.fill;
    for (final offset in offsets) {
      canvas.drawCircle(offset, 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeasurementPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.axisStyle != axisStyle ||
      oldDelegate.colors != colors;
}
