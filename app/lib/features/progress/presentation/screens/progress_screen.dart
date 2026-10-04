import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../nutrition/presentation/widgets/nutrition_widgets.dart';
import '../controllers/progress_controller.dart';
import '../widgets/measurement_chart.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(newProgressAchievementsProvider);
    return FeatureScaffold(
      title: 'Tiến độ',
      child: ref
          .watch(measurementHistoryProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FeatureError(
              error: e,
              retry: () => ref.invalidate(measurementHistoryProvider),
            ),
            data: (history) => RefreshIndicator(
              onRefresh: () => ref.refresh(measurementHistoryProvider.future),
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  PrimaryButton(
                    label: 'Nhập cân / số đo',
                    onPressed: () => context.push('/progress/measurements'),
                  ),
                  const SizedBox(height: 16),
                  if (history.items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Bắt đầu bằng lần đo đầu tiên. Mỗi bước nhỏ đều đáng ghi nhận.',
                      ),
                    ),
                  MeasurementChart(items: history.items, waist: false),
                  const SizedBox(height: 14),
                  MeasurementChart(items: history.items, waist: true),
                  if (achievements.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Huy hiệu mới',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          for (final a in achievements)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.emoji_events_outlined),
                              title: Text(a.nameVi ?? a.code),
                              subtitle: a.descriptionVi == null
                                  ? null
                                  : Text(a.descriptionVi!),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
    );
  }
}
