import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exceptions.dart';
import '../../../../core/constants/app_palette.dart';
import '../../data/speech/meal_speech.dart';
import '../../domain/models/nutrition_models.dart';
import '../controllers/nutrition_controller.dart';
import 'nutrition_widgets.dart';

/// Bữa mặc định theo giờ trên máy (chỉ để chọn sẵn, người dùng đổi được ở màn sửa bữa).
String defaultMealForHour(int hour) => hour < 10
    ? 'breakfast'
    : hour < 15
    ? 'lunch'
    : hour < 21
    ? 'dinner'
    : 'snack';

const mealLongLabels = {
  'breakfast': 'bữa sáng',
  'lunch': 'bữa trưa',
  'dinner': 'bữa tối',
  'snack': 'bữa phụ',
};

/// Lỗi của "Ghi món bằng câu" (POST /meals/parse): cùng mã lỗi với nhận diện ảnh, chỉ khác lời.
String mealTextError(Object error) {
  if (error is ApiException) {
    if (error.statusCode == 429 || error.code == 'PHOTO_LIMIT_REACHED') {
      return 'Đã hết lượt AI ghi món hôm nay. Bạn vẫn có thể tìm món thủ công.';
    }
    if (error.statusCode == 502 || error.code == 'AI_BAD_OUTPUT') {
      return 'Chưa hiểu được câu này. Thử viết rõ tên món hoặc tìm món thủ công.';
    }
  }
  return nutritionError(error);
}

/// "Ghi món bằng câu": gõ hoặc nói một câu, AI tách thành các món rồi mở màn sửa bữa.
class QuickMealLogCard extends ConsumerStatefulWidget {
  const QuickMealLogCard({super.key, required this.onParsed, this.meal});

  /// Bữa gửi kèm; null thì đoán theo giờ.
  final String? meal;
  final void Function(Recognition result, String meal) onParsed;

  @override
  ConsumerState<QuickMealLogCard> createState() => _QuickMealLogCardState();
}

class _QuickMealLogCardState extends ConsumerState<QuickMealLogCard> {
  final input = TextEditingController();
  late final MealSpeech speech = ref.read(mealSpeechProvider);
  bool busy = false, listening = false, micAvailable = true;
  bool noItems = false;
  Object? error;

  @override
  void dispose() {
    if (listening) speech.stop();
    input.dispose();
    super.dispose();
  }

  Future<void> toggleMic() async {
    if (listening) {
      await speech.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    setState(() => listening = true);
    final ok = await speech.start(
      onText: (text) {
        if (!mounted || text.isEmpty) return;
        final cut = text.length > 300 ? text.substring(0, 300) : text;
        input.value = TextEditingValue(
          text: cut,
          selection: TextSelection.collapsed(offset: cut.length),
        );
        setState(() {});
      },
      onDone: () {
        if (mounted) setState(() => listening = false);
      },
    );
    if (!mounted || ok) return;
    // Máy không có nhận dạng giọng nói hoặc bị từ chối quyền micro: ẩn nút, vẫn gõ được
    setState(() {
      listening = false;
      micAvailable = false;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Chưa dùng được micro. Hãy cấp quyền micro trong Cài đặt hoặc gõ món ăn.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> send() async {
    final text = input.text.trim();
    if (busy || text.isEmpty) return;
    if (listening) await speech.stop();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    final meal = widget.meal ?? defaultMealForHour(DateTime.now().hour);
    setState(() {
      busy = true;
      listening = false;
      error = null;
      noItems = false;
    });
    try {
      final result = await ref
          .read(nutritionRepositoryProvider)
          .parseText(text.length > 300 ? text.substring(0, 300) : text, meal);
      if (!mounted) return;
      if (result.items.isEmpty) {
        setState(() => noItems = true);
        return;
      }
      input.clear();
      widget.onParsed(result, meal);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ghi món bằng câu',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('meal-text-input'),
          controller: input,
          enabled: !busy,
          maxLength: 300,
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.send,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => send(),
          decoration: InputDecoration(
            labelText: 'Bạn đã ăn gì?',
            hintText: 'VD: 1 tô phở bò và 1 ly cà phê sữa',
            counterText: '',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (micAvailable)
                  IconButton(
                    key: const ValueKey('meal-text-mic'),
                    tooltip: listening ? 'Dừng nghe' : 'Nói món ăn',
                    onPressed: busy ? null : toggleMic,
                    icon: Icon(
                      listening ? Icons.stop_circle_outlined : Icons.mic_none,
                      color: listening ? colors.primary : null,
                    ),
                  ),
                busy
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        key: const ValueKey('meal-text-send'),
                        tooltip: 'Gửi',
                        onPressed: input.text.trim().isEmpty ? null : send,
                        icon: const Icon(Icons.send),
                      ),
              ],
            ),
          ),
        ),
        if (listening)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Đang nghe... nói tên món và số lượng.',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ),
        if (noItems || error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              noItems
                  ? 'Chưa nhận ra món nào trong câu. Thử viết rõ tên món hơn nhé.'
                  : mealTextError(error!),
              key: const ValueKey('meal-text-error'),
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
      ],
    );
  }
}

/// Hàng "Món phổ biến bữa ...": chạm một lần để thêm món với khẩu phần mặc định.
class PopularFoodChips extends ConsumerWidget {
  const PopularFoodChips({
    super.key,
    required this.meal,
    required this.onAdd,
    this.enabled = true,
  });
  final String meal;
  final bool enabled;
  final void Function(Food food) onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foods = ref.watch(popularFoodsProvider(meal)).valueOrNull;
    if (foods == null || foods.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Món phổ biến ${mealLongLabels[meal] ?? ''}'.trim(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final food in foods)
                ActionChip(
                  key: ValueKey('popular-${food.foodId}'),
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(
                    '${food.nameVi} • ${food.macros.kcal.round()} kcal',
                  ),
                  onPressed: enabled ? () => onAdd(food) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

const portionMultipliers = [0.5, 1.0, 1.5, 2.0];
const _fractionLabels = ['½', '1', '1½', '2'];

/// Nhãn khẩu phần quen dùng, vd servingDesc "1 tô", 550 g: "½ tô (275 g)", "1 tô (550 g)".
String portionLabel(String servingDesc, double servingGrams, double times) {
  final at = portionMultipliers.indexOf(times);
  final fraction = at < 0 ? '$times' : _fractionLabels[at];
  final desc = servingDesc.trim();
  final grams = '(${(servingGrams * times).round()} g)';
  if (desc.isEmpty) return '$fraction phần $grams';
  final match = RegExp(r'^1\s+(.+)$').firstMatch(desc);
  if (match != null) return '$fraction ${match.group(1)} $grams';
  return times == 1 ? '$desc $grams' : '$fraction × $desc $grams';
}

/// Chip chọn nhanh ½, 1, 1½, 2 khẩu phần; món không có khẩu phần chuẩn thì không hiện.
class PortionChips extends StatelessWidget {
  const PortionChips({
    super.key,
    required this.item,
    required this.onGrams,
    this.enabled = true,
  });
  final MealItem item;
  final bool enabled;
  final void Function(double grams) onGrams;

  @override
  Widget build(BuildContext context) {
    final serving = item.servingGrams;
    if (serving == null || serving <= 0) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      children: [
        for (final times in portionMultipliers)
          if (serving * times >= 1 && serving * times <= 3000)
            ChoiceChip(
              label: Text(portionLabel(item.servingDesc, serving, times)),
              selected: (item.grams - serving * times).abs() < 0.5,
              onSelected: enabled ? (_) => onGrams(serving * times) : null,
            ),
      ],
    );
  }
}

/// 8 ly nước, mỗi ly 250 ml. Chạm một ly trống để ghi thêm 250 ml.
class WaterGlasses extends StatelessWidget {
  const WaterGlasses({
    super.key,
    required this.waterMl,
    required this.onAdd,
    this.busy = false,
  });
  final int waterMl;
  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final filled = (waterMl ~/ 250).clamp(0, 8);
    final colors = context.colors;
    return Row(
      children: [
        for (var i = 0; i < 8; i++)
          Expanded(
            child: Semantics(
              button: i >= filled,
              label: i < filled ? 'Ly ${i + 1} đã uống' : 'Uống ly ${i + 1}',
              child: InkResponse(
                key: ValueKey('water-glass-$i'),
                radius: 24,
                onTap: busy || i < filled ? null : onAdd,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Icon(
                    i < filled ? Icons.local_drink : Icons.local_drink_outlined,
                    size: 28,
                    color: i < filled ? colors.primary : colors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
