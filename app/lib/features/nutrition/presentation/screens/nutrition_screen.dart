import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/models/nutrition_models.dart';
import '../controllers/nutrition_controller.dart';
import '../widgets/nutrition_widgets.dart';

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});
  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  bool addingWater = false;
  Object? waterError;
  Future<void> addWater() async {
    if (addingWater) return;
    setState(() {
      addingWater = true;
      waterError = null;
    });
    try {
      await ref.read(nutritionRepositoryProvider).addWater(250);
      if (!mounted) return;
      ref.invalidate(nutritionTodayProvider);
    } catch (e) {
      if (mounted) setState(() => waterError = e);
    } finally {
      if (mounted) setState(() => addingWater = false);
    }
  }

  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'Dinh dưỡng',
    actions: [
      IconButton(
        tooltip: 'Tiến độ',
        onPressed: () => context.push('/progress'),
        icon: const Icon(Icons.insights),
      ),
    ],
    child: ref
        .watch(nutritionTodayProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => FeatureError(
            error: e,
            retry: () => ref.invalidate(nutritionTodayProvider),
          ),
          data: (today) => RefreshIndicator(
            onRefresh: () => ref.refresh(nutritionTodayProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Text(
                  'Hôm nay • ${today.localDate}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                AppCard(child: _Summary(today)),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nước • ${today.waterMl} ml${today.target == null ? '' : ' / ${today.target!.waterMl} ml'}',
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: '+250 ml',
                        onPressed: addWater,
                        isLoading: addingWater,
                      ),
                      if (waterError != null)
                        FeatureError(error: waterError!, retry: addWater),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: 'Chụp món ăn',
                  onPressed: () => context.push('/nutrition/photo'),
                ),
                TextButton(
                  onPressed: () => context.push('/nutrition/add'),
                  child: const Text('Thêm món thủ công'),
                ),
                const SizedBox(height: 8),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Các bữa hôm nay',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final entry in mealLabels.entries) ...[
                        const SizedBox(height: 10),
                        Builder(
                          builder: (context) {
                            final meals = today.meals
                                .where((m) => m.meal == entry.key)
                                .toList();
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(entry.value),
                              subtitle: Text(
                                meals.isEmpty
                                    ? 'Chưa có bữa ăn'
                                    : meals.expand((m) => m.names).join(', '),
                              ),
                              trailing: meals.isEmpty
                                  ? IconButton(
                                      tooltip: 'Thêm bữa ${entry.value}',
                                      onPressed: () => context.push(
                                        '/nutrition/add?meal=${entry.key}',
                                      ),
                                      icon: const Icon(Icons.add),
                                    )
                                  : Text(
                                      '${meals.fold<double>(0, (s, m) => s + m.macros.kcal).round()} kcal',
                                    ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                if (today.suggestion case final suggestion?) ...[
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gợi ý bữa tối',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Text(suggestion.message),
                        for (final food in suggestion.foods)
                          Text(
                            '${food.nameVi} • ${food.macros.kcal.round()} kcal',
                          ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: 'Kiểm tra và thêm bữa tối',
                          onPressed: () => context.push(
                            '/nutrition/add?meal=dinner',
                            extra: suggestion.foods,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              context.push('/nutrition/add?meal=dinner'),
                          child: const Text('Xem lựa chọn khác'),
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

class _Summary extends StatelessWidget {
  const _Summary(this.today);
  final NutritionToday today;
  @override
  Widget build(BuildContext context) {
    final target = today.target?.macros;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 112,
              height: 112,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      strokeWidth: 8,
                      value: target == null || target.kcal <= 0
                          ? 0
                          : (today.consumed.kcal / target.kcal).clamp(0, 1),
                      color: AppColors.progressFill,
                      backgroundColor: AppColors.progressTrack,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${today.consumed.kcal.round()}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const Text('kcal đã ăn'),
                          if (target != null) Text('/ ${target.kcal.round()}'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: [
                  MacroRow(
                    label: 'Đạm',
                    value: today.consumed.proteinG,
                    target: target?.proteinG,
                  ),
                  MacroRow(
                    label: 'Tinh bột',
                    value: today.consumed.carbsG,
                    target: target?.carbsG,
                  ),
                  MacroRow(
                    label: 'Chất béo',
                    value: today.consumed.fatG,
                    target: target?.fatG,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          target == null
              ? 'Chưa có mục tiêu dinh dưỡng'
              : 'Mục tiêu ${target.kcal.round()} kcal',
        ),
        if (today.remaining != null)
          Text(
            today.remaining!.kcal < 0
                ? 'Vượt mục tiêu ${today.remaining!.kcal.abs().round()} kcal'
                : 'Còn lại ${today.remaining!.kcal.round()} kcal',
          ),
      ],
    );
  }
}
