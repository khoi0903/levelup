import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../nutrition/presentation/widgets/nutrition_widgets.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../../domain/models/food_candidate.dart';
import '../controllers/food_review_controller.dart';

/// Admin: món AI nhận ra / người dùng nhập tay mà kho chưa có. Duyệt thì thêm vào kho món.
class FoodReviewScreen extends ConsumerWidget {
  const FoodReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    if (me == null || !me.isAdmin) {
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
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Món chưa có trong kho, xếp theo số người dùng. '
                    'Nên duyệt khi có từ 5 người trở lên.',
                  ),
                  const SizedBox(height: 12),
                  if (foods.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Chưa có món nào chờ duyệt.'),
                    ),
                  for (final f in foods) _CandidateCard(candidate: f),
                ],
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
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                    ? 'Chưa có số liệu gợi ý'
                    : 'Gợi ý /100 g: ${s['kcal']!.round()} kcal · đạm ${s['proteinG']} g · '
                          'tinh bột ${s['carbsG']} g · béo ${s['fatG']} g',
              ),
              if (candidate.typicalGrams != null)
                Text('Khẩu phần hay gặp: ${candidate.typicalGrams!.round()} g'),
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
      ),
    );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(foodReviewRepositoryProvider).reject(candidate.id);
      ref.invalidate(pendingFoodsProvider);
    } catch (e) {
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
    String per(String k) {
      final v = ((c.suggested?[k] ?? 0) * g / 10).round() / 10;
      return v == v.roundToDouble() ? v.round().toString() : v.toString();
    }

    name = TextEditingController(text: c.nameVi);
    desc = TextEditingController(text: '1 phần ${g.round()} g');
    grams = TextEditingController(text: g.round().toString());
    kcal = TextEditingController(text: per('kcal'));
    protein = TextEditingController(text: per('proteinG'));
    carbs = TextEditingController(text: per('carbsG'));
    fat = TextEditingController(text: per('fatG'));
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

  Widget _field(TextEditingController c, String label, double max) =>
      TextFormField(
        controller: c,
        enabled: !busy,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        validator: (_) {
          final v = _num(c);
          return v == null || !v.isFinite || v < 0 || v > max
              ? 'Từ 0 đến ${max.round()}'
              : null;
        },
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
              kcal: _num(kcal)!,
              proteinG: _num(protein)!,
              carbsG: _num(carbs)!,
              fatG: _num(fat)!,
            ),
          );
      ref.invalidate(pendingFoodsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
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
            TextFormField(
              controller: name,
              enabled: !busy,
              decoration: const InputDecoration(labelText: 'Tên món'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Nhập tên món' : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Nhóm'),
              items: [
                for (final e in foodCategories.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: busy ? null : (v) => setState(() => category = v!),
            ),
            TextFormField(
              controller: desc,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Mô tả khẩu phần (vd 1 ly 500 ml)',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Nhập mô tả khẩu phần' : null,
            ),
            _field(grams, 'Khẩu phần (gram)', 3000),
            _field(kcal, 'Calo của khẩu phần (kcal)', 3000),
            _field(protein, 'Đạm (g)', 300),
            _field(carbs, 'Tinh bột (g)', 500),
            _field(fat, 'Chất béo (g)', 300),
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
              label: busy ? 'Đang lưu…' : 'Thêm vào kho',
              onPressed: busy ? null : _save,
            ),
          ],
        ),
      ),
    ),
  );
}
