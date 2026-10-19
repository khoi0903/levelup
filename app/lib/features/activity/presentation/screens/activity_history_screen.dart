import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../nutrition/presentation/widgets/nutrition_widgets.dart';
import '../../domain/models/activity_models.dart';
import '../controllers/activity_history_controller.dart';

const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

/// "2026-10-19" → "T2 19/10".
String activityDayLabel(String localDate) {
  final d = DateTime.tryParse(localDate);
  if (d == null) return localDate;
  return '${_weekdays[d.weekday - 1]} ${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}';
}

/// Lịch sử số bước và calo vận động từng ngày (số máy chủ đã lưu, lớn nhất giữa các điện thoại).
class ActivityHistoryScreen extends ConsumerWidget {
  const ActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FeatureScaffold(
      title: 'Bước chân & vận động',
      child: ref
          .watch(activityHistoryProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FeatureError(
              error: e,
              retry: () => ref.invalidate(activityHistoryProvider),
            ),
            data: (days) => RefreshIndicator(
              onRefresh: () async => ref.invalidate(activityHistoryProvider),
              child: _HistoryBody(days: days),
            ),
          ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({required this.days});
  final List<ActivityDay> days;

  @override
  Widget build(BuildContext context) {
    final withData = days.where((d) => d.steps > 0 || d.totalBurnedKcal > 0);
    final week = days.length > 7 ? days.sublist(days.length - 7) : days;
    final newestFirst = days.reversed.toList();
    final avgSteps = withData.isEmpty
        ? 0
        : withData.map((d) => d.steps).reduce((a, b) => a + b) ~/
              withData.length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '7 ngày gần nhất',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _StepsChart(days: week),
              const SizedBox(height: 8),
              Text(
                withData.isEmpty
                    ? 'Chưa có dữ liệu. Kết nối Health Connect ở Trang chủ để ghi nhận bước chân.'
                    : 'Trung bình $avgSteps bước/ngày (các ngày có dữ liệu)',
                key: const ValueKey('activity-average'),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final d in newestFirst) _DayRow(day: d),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Calo = buổi tập trong app + đi lại, vận động khác (không tính trùng lúc tập). '
            'Dùng nhiều điện thoại thì lấy số lớn nhất. Chỉ để tham khảo.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// Biểu đồ cột số bước, cột cao nhất = ngày nhiều bước nhất (tối thiểu thang 10.000 bước).
class _StepsChart extends StatelessWidget {
  const _StepsChart({required this.days});
  final List<ActivityDay> days;

  @override
  Widget build(BuildContext context) {
    final maxSteps = days.fold<int>(10000, (m, d) => d.steps > m ? d.steps : m);
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in days)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    d.steps >= 1000
                        ? '${(d.steps / 1000).toStringAsFixed(1)}k'
                        : '${d.steps}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 18,
                    height: 90 * d.steps / maxSteps + 2,
                    decoration: BoxDecoration(
                      color: d.steps >= 10000
                          ? AppColors.primary
                          : AppColors.progressFill.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activityDayLabel(d.localDate).split(' ').first,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day});
  final ActivityDay day;

  @override
  Widget build(BuildContext context) {
    final detail = day.workoutKcal > 0
        ? 'Tập ${day.workoutKcal} + đi lại ${day.otherKcal} kcal'
        : '${day.totalBurnedKcal} kcal vận động';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 76,
              child: Text(
                activityDayLabel(day.localDate),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${day.steps} bước',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${day.totalBurnedKcal} kcal',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
