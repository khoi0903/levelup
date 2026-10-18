import '../../../product/presentation/widgets/product_widgets.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exceptions.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/photo/meal_photo.dart';
import '../../domain/models/nutrition_models.dart';
import '../controllers/nutrition_controller.dart';
import '../widgets/nutrition_widgets.dart';
import 'food_search_screen.dart';

class MealEditorScreen extends ConsumerStatefulWidget {
  const MealEditorScreen({
    super.key,
    this.photoMode = false,
    this.meal = 'lunch',
    this.initialFoods = const [],
  });
  final bool photoMode;
  final String meal;
  final List<Food> initialFoods;
  @override
  ConsumerState<MealEditorScreen> createState() => _MealEditorScreenState();
}

class _MealEditorScreenState extends ConsumerState<MealEditorScreen> {
  late String meal;
  late List<MealItem> items;
  String? recognitionId;
  MealPhoto? photo;
  bool busy = false;
  bool manualFallback = false;
  Object? error;
  bool photoError = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    meal = mealLabels.containsKey(widget.meal) ? widget.meal : 'lunch';
    items = widget.initialFoods.map(MealItem.fromFood).toList();
  }

  Future<void> pick(MealPhotoSource source) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      photoError = true;
    });
    try {
      final selected = await ref.read(mealPhotoPickerProvider).pick(source);
      if (!mounted || selected == null) return;
      setState(() {
        photo = selected;
        recognitionId = null;
        items = [];
        generation++;
      });
      await recognize(selected);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> recognize(MealPhoto selected) async {
    try {
      final result = await ref
          .read(nutritionRepositoryProvider)
          .recognize(selected);
      if (!mounted) return;
      setState(() {
        recognitionId = result.recognitionId;
        items = result.items;
        generation++;
        manualFallback = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e;
        if (e is ApiException &&
            (e.statusCode == 503 || e.code == 'AI_UNAVAILABLE')) {
          manualFallback = true;
          recognitionId = null;
          photo = null;
        }
      });
    }
  }

  Future<void> retryPhoto() async {
    if (busy || photo == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    await recognize(photo!);
    if (mounted) setState(() => busy = false);
  }

  Future<void> addFood({int? replace}) async {
    if (busy || (replace == null && items.length >= 30)) return;
    final food = await selectFood(
      context,
      initialQuery: replace == null ? '' : items[replace].name,
    );
    if (!mounted || food == null) return;
    setState(() {
      final item = MealItem.fromFood(food);
      if (replace == null) {
        items = [...items, item];
      } else {
        items = [...items]..[replace] = item;
        generation++;
      }
    });
  }

  Future<void> save() async {
    if (busy || items.isEmpty || items.any((i) => !i.valid)) return;
    setState(() {
      busy = true;
      error = null;
      photoError = false;
    });
    try {
      await ref
          .read(nutritionRepositoryProvider)
          .saveMeal(
            MealRequest(
              meal: meal,
              method: recognitionId == null ? 'search' : 'photo',
              recognitionId: recognitionId,
              items: items,
            ),
          );
      if (!mounted) return;
      ref.invalidate(nutritionTodayProvider);
      context.go('/nutrition');
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = items
        .where((e) => e.valid)
        .fold(const Macros(), (a, b) => a + b.macros);
    return FeatureScaffold(
      title: widget.photoMode && !manualFallback
          ? 'Kiểm tra lại món ăn'
          : 'Thêm món thủ công',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.photoMode && !manualFallback) ...[
            AppCard(
              child: Column(
                children: [
                  if (photo != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.memory(
                        photo!.bytes,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Text('Không thể xem trước ảnh'),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Icon(Icons.add_a_photo_outlined, size: 64),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Chụp cả phần ăn để ước lượng khẩu phần chính xác hơn.',
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Chụp ảnh',
                    onPressed: busy ? null : () => pick(MealPhotoSource.camera),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => pick(MealPhotoSource.gallery),
                    child: const Text('Chọn ảnh từ thư viện'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (error != null)
            AppCard(
              child: Column(
                children: [
                  Text(nutritionError(error!)),
                  ProLimitAction(error: error),
                  if (photoError && photo != null && !busy)
                    TextButton(
                      onPressed: retryPhoto,
                      child: const Text('Thử nhận diện lại'),
                    ),
                  if (!photoError && !busy)
                    TextButton(
                      onPressed: save,
                      child: const Text('Thử lưu lại'),
                    ),
                  TextButton(
                    onPressed: busy ? null : () => addFood(),
                    child: const Text('Tìm món thủ công'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          if (items.isNotEmpty)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${total.kcal.round()} kcal ước tính',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    'Đạm ${total.proteinG.round()} g • Tinh bột ${total.carbsG.round()} g • Chất béo ${total.fatG.round()} g',
                  ),
                  const Text(
                    'Hãy kiểm tra tên món và khẩu phần trước khi lưu.',
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Chưa có món. Tìm và thêm món vào bữa ăn.'),
            ),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            items[i].name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Xóa món ${items[i].name}',
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                  items = [...items]..removeAt(i);
                                  generation++;
                                }),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    if (!items[i].hasNutrition) ...[
                      const Text(
                        'Món chưa khớp kho thực phẩm. Hãy tìm món thay thế.',
                      ),
                      TextButton(
                        onPressed: busy ? null : () => addFood(replace: i),
                        child: const Text('Tìm món thay thế'),
                      ),
                    ] else ...[
                      TextFormField(
                        key: ValueKey('grams-$generation-$i'),
                        initialValue: '${items[i].grams}',
                        enabled: !busy,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Khẩu phần (gram)',
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          final grams = double.tryParse(
                            (value ?? '').replaceAll(',', '.'),
                          );
                          return grams == null ||
                                  !grams.isFinite ||
                                  grams < 1 ||
                                  grams > 3000
                              ? 'Nhập từ 1 đến 3000 g'
                              : null;
                        },
                        onChanged: (value) => setState(() {
                          final grams = double.tryParse(
                            value.replaceAll(',', '.'),
                          );
                          items = [...items]
                            ..[i] = items[i].withGrams(
                              grams != null &&
                                      grams.isFinite &&
                                      grams >= 1 &&
                                      grams <= 3000
                                  ? grams
                                  : 0,
                            );
                        }),
                      ),
                      Text('${items[i].macros.kcal.round()} kcal'),
                      if (items[i].estimated)
                        Text(
                          'AI ước tính, món chưa có trong kho. Hãy sửa khẩu phần nếu chưa đúng.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      TextButton(
                        onPressed: busy ? null : () => addFood(replace: i),
                        child: const Text('Đổi món'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          TextButton(
            onPressed: busy || items.length >= 30 ? null : () => addFood(),
            child: const Text('+ Thêm món qua tìm kiếm'),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chọn bữa ăn'),
                Wrap(
                  spacing: 8,
                  children: mealLabels.entries
                      .map(
                        (entry) => ChoiceChip(
                          label: Text(entry.value),
                          selected: meal == entry.key,
                          onSelected: busy
                              ? null
                              : (_) => setState(() => meal = entry.key),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: 'Lưu bữa ăn',
                  isLoading: busy,
                  onPressed: items.isEmpty || items.any((e) => !e.valid)
                      ? null
                      : save,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
