import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exceptions.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../nutrition/domain/models/nutrition_models.dart';
import '../../../nutrition/presentation/widgets/nutrition_widgets.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../../domain/models/food_candidate.dart';
import '../controllers/food_review_controller.dart';

/// Số gọn: 6.0 → "6", 1.25 → "1.3".
String _fmt(double v) {
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble() ? r.round().toString() : r.toStringAsFixed(1);
}

/// Món đã được admin khác xử lý: tải lại danh sách để thẻ cũ biến mất.
bool _alreadyReviewed(Object e) =>
    e is ApiException &&
    const {'CANDIDATE_REVIEWED', 'CANDIDATE_NOT_FOUND'}.contains(e.code);

/// Admin: món AI nhận ra trong ảnh mà kho chưa có. Duyệt thì thêm vào kho món.
class FoodReviewScreen extends ConsumerWidget {
  const FoodReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(
      currentUserProvider.select((me) => me?.isAdmin ?? false),
    );
    if (!isAdmin) {
      return const FeatureScaffold(
        title: 'Không tìm thấy trang',
        child: SizedBox.shrink(),
      );
    }
    return FeatureScaffold(
      title: 'Duyệt món mới',
      child: ref
          .watch(pendingFoodsProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FeatureError(
              error: e,
              retry: () => ref.invalidate(pendingFoodsProvider),
            ),
            data: (foods) => RefreshIndicator(
              onRefresh: () async => ref.invalidate(pendingFoodsProvider),
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: foods.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        foods.isEmpty
                            ? 'Chưa có món nào chờ duyệt.'
                            : 'Món chưa có trong kho, xếp theo số người dùng. '
                                  'Món có nhãn "nên duyệt" đã đủ người gặp.',
                      ),
                    );
                  }
                  return _CandidateCard(candidate: foods[i - 1]);
                },
              ),
            ),
          ),
    );
  }
}

class _CandidateCard extends ConsumerWidget {
  const _CandidateCard({required this.candidate});
  final FoodCandidate candidate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = candidate.suggested;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              candidate.nameVi,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${candidate.userCount} người · chụp ${candidate.sightings} lần · '
              'lưu ${candidate.saves} lần'
              '${candidate.readyForReview ? ' · nên duyệt' : ''}',
            ),
            Text(
              s == null
                  ? 'AI chưa ước tính được số liệu'
                  : 'Gợi ý /100 g: ${_fmt(s.kcal)} kcal · đạm ${_fmt(s.proteinG)} g · '
                        'tinh bột ${_fmt(s.carbsG)} g · béo ${_fmt(s.fatG)} g',
            ),
            if (candidate.typicalGrams != null)
              Text('Khẩu phần hay gặp: ${_fmt(candidate.typicalGrams!)} g'),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _reject(context, ref),
                  child: const Text('Bỏ'),
                ),
                TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => ApproveFoodSheet(candidate: candidate),
                  ),
                  child: const Text('Duyệt'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Bỏ "${candidate.nameVi}"?'),
        content: const Text('Món sẽ không hiện trong danh sách chờ duyệt nữa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Bỏ món'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(foodReviewRepositoryProvider).reject(candidate.id);
      ref.invalidate(pendingFoodsProvider);
    } catch (e) {
      if (_alreadyReviewed(e)) ref.invalidate(pendingFoodsProvider);
      messenger.showSnackBar(SnackBar(content: Text(mapErrorMessage(e))));
    }
  }
}

/// Form duyệt: số liệu cho một khẩu phần, điền sẵn từ gợi ý /100 g × khẩu phần hay gặp.
class ApproveFoodSheet extends ConsumerStatefulWidget {
  const ApproveFoodSheet({super.key, required this.candidate});
  final FoodCandidate candidate;
  @override
  ConsumerState<ApproveFoodSheet> createState() => _ApproveFoodSheetState();
}

class _ApproveFoodSheetState extends ConsumerState<ApproveFoodSheet> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name, desc, grams, kcal, protein, carbs, fat;
  String category = 'do_uong';
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final c = widget.candidate;
    final g = c.typicalGrams ?? 100;
    final serving = (c.suggested ?? const Macros()).scale(g / 100);
    name = TextEditingController(text: c.nameVi);
    desc = TextEditingController(text: '1 phần ${_fmt(g)} g');
    grams = TextEditingController(text: _fmt(g));
    kcal = TextEditingController(text: _fmt(serving.kcal));
    protein = TextEditingController(text: _fmt(serving.proteinG));
    carbs = TextEditingController(text: _fmt(serving.carbsG));
    fat = TextEditingController(text: _fmt(serving.fatG));
  }

  @override
  void dispose() {
    for (final c in [name, desc, grams, kcal, protein, carbs, fat]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Widget _field(
    TextEditingController c,
    String label,
    double max, {
    double min = 0,
  }) => TextFormField(
    controller: c,
    enabled: !busy,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    validator: (_) {
      final v = _num(c);
      return v == null || !v.isFinite || v < min || v > max
          ? 'Từ ${_fmt(min)} đến ${_fmt(max)}'
          : null;
    },
  );

  Widget _text(
    TextEditingController c,
    String label,
    int maxLength,
    String emptyError,
  ) => TextFormField(
    controller: c,
    enabled: !busy,
    maxLength: maxLength,
    decoration: InputDecoration(labelText: label),
    validator: (v) => (v ?? '').trim().isEmpty ? emptyError : null,
  );

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(foodReviewRepositoryProvider)
          .approve(
            widget.candidate.id,
            ApproveFood(
              nameVi: name.text,
              category: category,
              servingDesc: desc.text,
              servingGrams: _num(grams)!,
              macros: Macros(
                kcal: _num(kcal)!,
                proteinG: _num(protein)!,
                carbsG: _num(carbs)!,
                fatG: _num(fat)!,
              ),
            ),
          );
      ref.invalidate(pendingFoodsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (_alreadyReviewed(e)) ref.invalidate(pendingFoodsProvider);
      if (!mounted) return;
      setState(() {
        busy = false;
        error = mapErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      top: 20,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Thêm vào kho món',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            _text(name, 'Tên món', maxFoodNameLength, 'Nhập tên món'),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Nhóm'),
              items: [
                for (final e in foodCategories.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: busy ? null : (v) => setState(() => category = v!),
            ),
            _text(
              desc,
              'Mô tả khẩu phần (vd 1 ly 500 ml)',
              maxServingDescLength,
              'Nhập mô tả khẩu phần',
            ),
            _field(grams, 'Khẩu phần (gram)', maxServingGrams, min: 1),
            _field(kcal, 'Calo của khẩu phần (kcal)', maxKcal),
            _field(protein, 'Đạm (g)', maxProteinG),
            _field(carbs, 'Tinh bột (g)', maxCarbsG),
            _field(fat, 'Chất béo (g)', maxFatG),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Thêm vào kho',
              isLoading: busy,
              onPressed: _save,
            ),
          ],
        ),
      ),
    ),
  );
}
