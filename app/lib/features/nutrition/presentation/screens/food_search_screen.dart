import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/nutrition_models.dart';
import '../controllers/nutrition_controller.dart';
import '../widgets/nutrition_widgets.dart';

Future<Food?> selectFood(BuildContext context, {String initialQuery = ''}) =>
    Navigator.of(context).push<Food>(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(initialQuery: initialQuery),
      ),
    );

class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({super.key, this.initialQuery = ''});
  final String initialQuery;
  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  late final TextEditingController input;
  late String query;
  Timer? debounce;
  @override
  void initState() {
    super.initState();
    query = widget.initialQuery;
    input = TextEditingController(text: query);
  }

  @override
  void dispose() {
    debounce?.cancel();
    input.dispose();
    super.dispose();
  }

  void search(String value) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'Tìm món ăn',
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: input,
            autofocus: true,
            maxLength: 100,
            onChanged: search,
            decoration: const InputDecoration(
              labelText: 'Tên món ăn',
              hintText: 'Ví dụ: com trang (không dấu cũng được)',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: query.isEmpty
              ? const Center(
                  child: Text('Nhập tên món để tìm trong kho thực phẩm.'),
                )
              : ref
                    .watch(foodSearchProvider(query))
                    .when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => FeatureError(
                        error: e,
                        retry: () => ref.invalidate(foodSearchProvider(query)),
                      ),
                      data: (foods) => foods.isEmpty
                          ? const Center(
                              child: Text(
                                'Chưa tìm thấy món. Thử tên khác nhé.',
                              ),
                            )
                          : ListView.builder(
                              itemCount: foods.length,
                              itemBuilder: (context, i) {
                                final food = foods[i];
                                return ListTile(
                                  title: Text(food.nameVi),
                                  subtitle: Text(
                                    '${food.servingDesc} • ${food.servingGrams.round()} g • ${food.macros.kcal.round()} kcal',
                                  ),
                                  trailing: const Icon(
                                    Icons.add_circle_outline,
                                  ),
                                  onTap: () => Navigator.of(context).pop(food),
                                );
                              },
                            ),
                    ),
        ),
      ],
    ),
  );
}
