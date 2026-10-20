import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_palette.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/selection_chip.dart';
import '../../domain/models/workout_models.dart';
import '../controllers/workout_controller.dart';
import '../widgets/workout_widgets.dart';

/// Nhãn RPE 1–10 (Figma: "Buổi tập vừa rồi như thế nào?").
const Map<int, (String, String)> rpeLabelsVi = {
  1: ('Rất dễ', 'Như đi dạo, gần như không mất sức.'),
  2: ('Dễ', 'Thở bình thường, còn rất nhiều sức.'),
  3: ('Dễ', 'Hơi ấm người, vẫn nói chuyện thoải mái.'),
  4: ('Vừa phải', 'Bắt đầu thấy mỏi nhẹ.'),
  5: ('Vừa phải', 'Còn sức làm thêm khoảng 5 lần nữa.'),
  6: ('Hơi nặng', 'Còn sức làm thêm khoảng 4 lần nữa.'),
  7: ('Hơi nặng nhưng làm được', 'Còn sức làm thêm khoảng 2–3 lần nữa.'),
  8: ('Nặng', 'Chỉ còn sức làm thêm 1–2 lần.'),
  9: ('Rất nặng', 'Gần hết sức, khó làm thêm lần nào.'),
  10: ('Quá sức', 'Không thể làm thêm dù chỉ một lần.'),
};

class WorkoutFinishScreen extends ConsumerStatefulWidget {
  const WorkoutFinishScreen({super.key});

  @override
  ConsumerState<WorkoutFinishScreen> createState() =>
      _WorkoutFinishScreenState();
}

class _WorkoutFinishScreenState extends ConsumerState<WorkoutFinishScreen> {
  int _rpe = 7;
  final Set<PainArea> _pain = {};
  String? _painType;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pain.isNotEmpty && _painType == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Vui lòng chọn loại đau: mỏi cơ hay đau nhói / đau khớp.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    final result = await ref
        .read(activeWorkoutProvider.notifier)
        .submit(
          rpe: _rpe,
          painAreas: PainArea.values.where(_pain.contains).toList(),
          painType: _pain.isNotEmpty ? _painType : null,
          note: _noteController.text,
        );
    if (!mounted || result == null) return;
    context.go('/workout/result');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(activeWorkoutProvider);
    if (s == null) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => context.go('/home'),
            child: const Text('Về trang chủ'),
          ),
        ),
      );
    }
    final error = s.error;
    final (title, detail) = rpeLabelsVi[_rpe]!;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: GradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    children: [
                      WorkoutHeader(
                        title: 'LevelUp',
                        stepLabel: '${s.sets.length} hiệp',
                        progress: 1,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Buổi tập vừa rồi như thế nào?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      GridView.count(
                        crossAxisCount: 5,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.4,
                        children: [
                          for (var i = 1; i <= 10; i++)
                            AppCard(
                              key: ValueKey('rpe-$i'),
                              isSelected: _rpe == i,
                              padding: EdgeInsets.zero,
                              borderRadius: 16,
                              onTap: () => setState(() => _rpe = i),
                              child: Center(
                                child: Text(
                                  '$i',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _rpe == i
                                        ? context.colors.primary
                                        : context.colors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        borderRadius: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_rpe · $title',
                              key: const ValueKey('rpe-label'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: context.colors.textPrimary,
                              ),
                            ),
                            Text(
                              detail,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Có chỗ nào đau không?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final area in PainArea.values)
                            SelectionChip(
                              label: area.labelVi,
                              height: 40,
                              isSelected: _pain.contains(area),
                              onTap: () => setState(() {
                                if (!_pain.remove(area)) {
                                  _pain.add(area);
                                }
                                if (_pain.isEmpty) {
                                  _painType = null;
                                }
                              }),
                            ),
                        ],
                      ),
                      if (_pain.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Cảm giác đau như thế nào?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            SelectionChip(
                              key: const ValueKey('pain-type-soreness'),
                              label: 'Mỏi cơ bình thường',
                              height: 40,
                              isSelected: _painType == 'soreness',
                              onTap: () => setState(() => _painType = 'soreness'),
                            ),
                            SelectionChip(
                              key: const ValueKey('pain-type-sharp'),
                              label: 'Đau nhói / đau khớp',
                              height: 40,
                              isSelected: _painType == 'sharp',
                              onTap: () => setState(() => _painType = 'sharp'),
                            ),
                          ],
                        ),
                        if (_painType == 'soreness') ...[
                          const SizedBox(height: 8),
                          Text(
                            'Mỏi sau tập là bình thường. Giãn cơ, uống đủ nước nhé.',
                            key: ValueKey('pain-hint-soreness'),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ] else if (_painType == 'sharp') ...[
                          const SizedBox(height: 8),
                          Text(
                            'Coach sẽ đổi bài tránh vùng này và hỏi thăm bạn ngày mai. Đau kéo dài thì nên đi khám.',
                            key: ValueKey('pain-hint-sharp'),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 18),
                      Text(
                        'Ghi chú cho coach',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _noteController,
                        maxLength: 500,
                        maxLines: 3,
                        minLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Không bắt buộc',
                          filled: true,
                          fillColor: context.colors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.colors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.colors.border,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(
                    children: [
                      if (error != null) ...[
                        ErrorBanner(
                          key: const ValueKey('retry-banner'),
                          message: error.isNetworkError
                              ? 'Chưa gửi được vì mất mạng. Đã lưu trên máy, sẽ gửi khi có mạng.'
                              : 'Chưa lưu được buổi tập. Bấm Thử lại nhé, buổi tập vẫn được giữ trên máy.',
                          onRetry: s.submitting ? null : _submit,
                        ),
                        const SizedBox(height: 12),
                      ],
                      PrimaryButton(
                        label: 'Xem kết quả',
                        isLoading: s.submitting,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
