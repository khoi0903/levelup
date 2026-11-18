import 'package:flutter/material.dart';

import '../../../../core/constants/app_palette.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../body/domain/models/body_models.dart';
import '../../../body/presentation/widgets/body_stats_view.dart';
import '../../domain/coach_reactions.dart';
import 'coach_reaction_line.dart';

/// BMI tính ngay khi nhập chiều cao/cân nặng: số BMI, nhóm (tên trung tính),
/// thang màu theo ngưỡng châu Á có vạch ở giá trị hiện tại, và một câu coach.
class BmiLiveScale extends StatelessWidget {
  const BmiLiveScale({super.key, required this.bmi});

  final double bmi;

  static const double _min = 15;
  static const double _max = 35;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final category = bmiCategoryFor(bmi);
    final label = bmiCategoryLabel(category);
    // Thanh màu: nền sáng dùng màu viền nhạt, nền tối dùng màu chữ sáng,
    // để cả hai chế độ đều dịu mắt mà vẫn phân biệt được bốn nhóm.
    final bar = c.isDark
        ? [c.infoText, c.successText, c.warningText, c.errorText]
        : [c.infoBorder, c.successBorder, c.warningBorder, c.errorBorder];
    final segments = <(double, double, Color)>[
      (_min, kBmiUnderweightBelow, bar[0]),
      (kBmiUnderweightBelow, kBmiNormalBelow, bar[1]),
      (kBmiNormalBelow, kBmiOverweightBelow, bar[2]),
      (kBmiOverweightBelow, _max, bar[3]),
    ];
    final (chipBg, chipText) = switch (category) {
      'underweight' => (c.infoBg, c.infoText),
      'normal' => (c.successBg, c.successText),
      'overweight' => (c.warningBg, c.warningText),
      _ => (c.errorBg, c.errorText),
    };
    final pos = ((bmi - _min) / (_max - _min)).clamp(0.0, 1.0);

    return GlassCard(
      key: const ValueKey('ob-bmi-live'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(
                'BMI ${bmi.toStringAsFixed(1)}',
                key: const ValueKey('ob-bmi-value'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
              if (label.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    key: const ValueKey('ob-bmi-category'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: chipText,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              const markerW = 4.0;
              return SizedBox(
                height: 20,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Row(
                          children: [
                            for (final s in segments)
                              Expanded(
                                flex: ((s.$2 - s.$1) * 10).round(),
                                child: Container(height: 8, color: s.$3),
                              ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      left: (w * pos - markerW / 2).clamp(0.0, w - markerW),
                      top: 0,
                      child: Container(
                        key: const ValueKey('ob-bmi-marker'),
                        width: markerW,
                        height: 20,
                        decoration: BoxDecoration(
                          color: c.textPrimary,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: c.surface, width: 1),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              final style = TextStyle(fontSize: 11, color: c.textSecondary);
              double x(double v) => w * (v - _min) / (_max - _min);
              return SizedBox(
                height: 16,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final v in const [
                      kBmiUnderweightBelow,
                      kBmiNormalBelow,
                      kBmiOverweightBelow,
                    ])
                      Positioned(
                        left: x(v) - 14,
                        width: 28,
                        child: Text(
                          v % 1 == 0 ? v.toStringAsFixed(0) : '$v',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: style,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          CoachReactionLine(bmiReaction(bmi)),
        ],
      ),
    );
  }
}
