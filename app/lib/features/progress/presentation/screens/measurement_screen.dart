import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../nutrition/presentation/widgets/nutrition_widgets.dart';
import '../../domain/models/progress_models.dart';
import '../controllers/progress_controller.dart';

const measurementFields = [
  (key: 'weightKg', label: 'Cân nặng (kg)', min: 20.0, max: 350.0),
  (key: 'waistCm', label: 'Vòng eo (cm)', min: 30.0, max: 250.0),
  (key: 'hipCm', label: 'Vòng hông (cm)', min: 30.0, max: 250.0),
  (key: 'chestCm', label: 'Vòng ngực (cm)', min: 30.0, max: 250.0),
  (key: 'armCm', label: 'Vòng tay (cm)', min: 10.0, max: 100.0),
];

class MeasurementScreen extends ConsumerStatefulWidget {
  const MeasurementScreen({super.key});
  @override
  ConsumerState<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends ConsumerState<MeasurementScreen> {
  final form = GlobalKey<FormState>();
  final inputs = {
    for (final field in measurementFields) field.key: TextEditingController(),
  };
  bool busy = false;
  Object? error;
  String? emptyError;
  @override
  void dispose() {
    for (final c in inputs.values) {
      c.dispose();
    }
    super.dispose();
  }

  double? value(String key) =>
      double.tryParse(inputs[key]!.text.trim().replaceAll(',', '.'));
  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    final request = MeasurementRequest(
      weightKg: value('weightKg'),
      waistCm: value('waistCm'),
      hipCm: value('hipCm'),
      chestCm: value('chestCm'),
      armCm: value('armCm'),
    );
    if (!request.hasValue) {
      setState(() => emptyError = 'Nhập ít nhất một chỉ số.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      emptyError = null;
    });
    try {
      final result = await ref.read(progressRepositoryProvider).save(request);
      if (!mounted) return;
      ref.invalidate(measurementHistoryProvider);
      ref.read(newProgressAchievementsProvider.notifier).state =
          result.newAchievements;
      if (!mounted) return;
      // Quay về màn Tiến độ đang có trong ngăn xếp (giữ nút quay lại của nó);
      // mở thẳng màn nhập (không có màn trước) thì mới thay bằng /progress
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/progress');
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'Cân và số đo hôm nay',
    child: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Chỉ nhập những chỉ số bạn đã đo. Gửi lại trong ngày sẽ cập nhật số đo hôm nay.',
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              children: [
                for (final field in measurementFields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      key: ValueKey(field.key),
                      controller: inputs[field.key],
                      enabled: !busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: field.label,
                        hintText: 'Không bắt buộc',
                      ),
                      validator: (text) {
                        if (text == null || text.trim().isEmpty) return null;
                        final number = double.tryParse(
                          text.trim().replaceAll(',', '.'),
                        );
                        return number == null ||
                                !number.isFinite ||
                                number < field.min ||
                                number > field.max
                            ? 'Nhập từ ${field.min.round()} đến ${field.max.round()}'
                            : null;
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (emptyError != null) Text(emptyError!),
          if (error != null) FeatureError(error: error!, retry: save),
          PrimaryButton(label: 'Lưu số đo', onPressed: save, isLoading: busy),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}
