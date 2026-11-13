import 'package:flutter/material.dart';

import '../../../../core/constants/app_palette.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/models/body_models.dart';
import 'body_figure.dart';

const String kEstimateNote = 'Chỉ là ước tính, không phải chẩn đoán y khoa.';

/// Giải thích ngắn cho từng chỉ số: (tên đầy đủ, là gì, cách tính).
const Map<String, (String, String, String)> kMetricInfo = {
  'bmi': (
    'BMI – chỉ số khối cơ thể',
    'Cho biết cân nặng có tương xứng với chiều cao hay không. BMI không phân biệt được cơ và mỡ, nên người nhiều cơ có thể có BMI cao.',
    'Lấy cân nặng (kg) chia cho chiều cao (m) nhân với chính nó.',
  ),
  'bodyFat': (
    'Tỉ lệ mỡ cơ thể',
    'Phần trăm khối lượng cơ thể là mỡ. Con số này giúp theo dõi thay đổi vóc dáng tốt hơn cân nặng.',
    'Lấy theo vóc dáng bạn đã chọn. Nếu chưa chọn, LevelUp ước tính từ BMI, tuổi và giới tính.',
  ),
  'bmr': (
    'BMR – năng lượng nền',
    'Lượng calo cơ thể dùng trong một ngày khi nghỉ hoàn toàn, chỉ để duy trì sự sống (thở, tim đập, giữ ấm).',
    'Tính từ cân nặng, chiều cao, tuổi và giới tính theo công thức Mifflin-St Jeor.',
  ),
  'tdee': (
    'TDEE – tổng năng lượng mỗi ngày',
    'Lượng calo bạn tiêu hao trong một ngày, gồm cả đi lại, làm việc và tập luyện.',
    'Lấy BMR nhân với hệ số vận động theo số buổi tập mỗi tuần của bạn.',
  ),
  'targetKcal': (
    'Calo mục tiêu mỗi ngày',
    'Lượng calo nên ăn mỗi ngày để tiến tới mục tiêu của bạn.',
    'Lấy TDEE rồi giảm bớt nếu mục tiêu là giảm mỡ, tăng thêm nếu là tăng cơ. Không thấp hơn 1200 kcal (nam: 1500 kcal).',
  ),
  'protein': (
    'Đạm (protein)',
    'Giúp giữ và xây cơ, no lâu hơn. Có nhiều trong thịt, cá, trứng, đậu.',
    'Tính theo cân nặng và mục tiêu của bạn, mỗi gam đạm cho 4 kcal.',
  ),
  'carbs': (
    'Tinh bột (carb)',
    'Nguồn năng lượng chính cho buổi tập và sinh hoạt. Có trong cơm, bún, khoai, trái cây.',
    'Là phần calo còn lại sau khi trừ đạm và chất béo, mỗi gam cho 4 kcal.',
  ),
  'fat': (
    'Chất béo',
    'Cần cho hormone và hấp thu vitamin. Có trong dầu ăn, các loại hạt, cá béo.',
    'Chiếm khoảng một phần tư tới một phần ba calo mục tiêu, mỗi gam cho 9 kcal.',
  ),
  'water': (
    'Nước mỗi ngày',
    'Lượng nước nên uống trong ngày, ngày tập nhiều hoặc trời nóng thì cần thêm.',
    'Khoảng 30–35 ml cho mỗi kg cân nặng.',
  ),
};

/// Tên trung tính cho nhóm BMI, không dùng từ đánh giá ngoại hình.
String bmiCategoryLabel(String? category) => switch (category) {
  'underweight' => 'Dưới khoảng chuẩn',
  'normal' => 'Trong khoảng chuẩn',
  'overweight' => 'Trên khoảng chuẩn',
  'obese' => 'Cao hơn khoảng chuẩn',
  _ => '',
};

void showMetricInfo(BuildContext context, String metric) {
  final info = kMetricInfo[metric];
  if (info == null) return;
  final c = context.colors;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.surface,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info.$1,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              info.$2,
              style: TextStyle(fontSize: 14, height: 1.5, color: c.textPrimary),
            ),
            const SizedBox(height: 10),
            Text(
              'Cách tính',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              info.$3,
              style: TextStyle(fontSize: 14, height: 1.5, color: c.textPrimary),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.infoBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.infoBorder),
              ),
              child: Text(
                kEstimateNote,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.infoText,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _num(num? v, {int digits = 0}) =>
    v == null ? '–' : v.toStringAsFixed(digits);

/// Nội dung màn "Chỉ số của bạn": hình người + các chỉ số, mỗi chỉ số có nút ⓘ.
class BodyStatsView extends StatelessWidget {
  const BodyStatsView({super.key, required this.stats});

  final BodyStats stats;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final category = bmiCategoryLabel(stats.bmiCategory);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                height: 210,
                child: BodyFigure(
                  key: const ValueKey('body-stats-figure'),
                  shape: stats.shape,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetricHeader(label: 'BMI', metric: 'bmi'),
                    Text(
                      _num(stats.bmi, digits: 1),
                      key: const ValueKey('body-stats-bmi'),
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    if (category.isNotEmpty)
                      Container(
                        key: const ValueKey('body-stats-bmi-chip'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: c.primaryLight,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.primary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    _MetricHeader(label: 'Tỉ lệ mỡ', metric: 'bodyFat'),
                    Text(
                      stats.bodyFatPct == null
                          ? '–'
                          : '${_num(stats.bodyFatPct)}%',
                      key: const ValueKey('body-stats-fat'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    if (stats.bodyFatPct != null && stats.bodyFatEstimated)
                      Text(
                        'ước tính',
                        key: const ValueKey('body-stats-fat-estimated'),
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      [
                        if (stats.heightCm != null)
                          '${_num(stats.heightCm)} cm',
                        if (stats.weightKg != null)
                          '${_num(stats.weightKg, digits: stats.weightKg! % 1 == 0 ? 0 : 1)} kg',
                        if (stats.age != null) '${stats.age} tuổi',
                      ].join(' · '),
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                metric: 'bmr',
                label: 'BMR',
                value: _num(stats.bmr),
                unit: 'kcal',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                metric: 'tdee',
                label: 'TDEE',
                value: _num(stats.tdee),
                unit: 'kcal',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _MetricTile(
          metric: 'targetKcal',
          label: 'Calo mục tiêu mỗi ngày',
          value: _num(stats.targetKcal),
          unit: 'kcal',
          highlight: true,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                metric: 'protein',
                label: 'Đạm',
                value: _num(stats.proteinG),
                unit: 'g',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                metric: 'carbs',
                label: 'Tinh bột',
                value: _num(stats.carbsG),
                unit: 'g',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                metric: 'fat',
                label: 'Chất béo',
                value: _num(stats.fatG),
                unit: 'g',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _MetricTile(
          metric: 'water',
          label: 'Nước mỗi ngày',
          value: _num(stats.waterMl),
          unit: 'ml',
        ),
        const SizedBox(height: 12),
        Text(
          kEstimateNote,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: c.textSecondary),
        ),
      ],
    );
  }
}

class _MetricHeader extends StatelessWidget {
  const _MetricHeader({required this.label, required this.metric});

  final String label;
  final String metric;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      key: ValueKey('metric-info-$metric'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => showMetricInfo(context, metric),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.info_outline_rounded, size: 16, color: c.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.metric,
    required this.label,
    required this.value,
    required this.unit,
    this.highlight = false,
  });

  final String metric;
  final String label;
  final String value;
  final String unit;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GlassCard(
      isSelected: highlight,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetricHeader(label: label, metric: metric),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
              ],
            ),
            key: ValueKey('metric-value-$metric'),
          ),
        ],
      ),
    );
  }
}
