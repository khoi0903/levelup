import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_palette.dart';
import '../../../../core/tutorial/tutorial.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../users/domain/models/me_response.dart';
import '../../../users/domain/models/settings_request.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../../domain/models/body_models.dart';
import '../../domain/models/body_shape.dart';
import '../controllers/body_controller.dart';
import 'body_figure.dart';

/// Thẻ mở màn "Chỉ số của bạn" + thẻ "Cơ đã tập tuần này" trong tab Tôi.
class BodyProfileCards extends StatelessWidget {
  const BodyProfileCards({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          key: const ValueKey('body-stats-entry'),
          onTap: () => context.push('/body'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.accessibility_new_rounded, color: c.primary, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chỉ số của bạn',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'BMI, tỉ lệ mỡ, calo và nước mỗi ngày',
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.textSecondary),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const MusclesWeekCard(),
      ],
    );
  }
}

/// Thẻ "Cơ đã tập tuần này": hình người tô đậm nhạt theo số hiệp mỗi nhóm cơ.
class MusclesWeekCard extends ConsumerStatefulWidget {
  const MusclesWeekCard({super.key});

  @override
  ConsumerState<MusclesWeekCard> createState() => _MusclesWeekCardState();
}

class _MusclesWeekCardState extends ConsumerState<MusclesWeekCard> {
  BodySide _side = BodySide.front;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final week = ref.watch(musclesWeekProvider);
    final shape =
        ref.watch(bodyStatsProvider).valueOrNull?.shape ?? BodyShape.from();
    final data = week.valueOrNull ?? const MuscleWeek();
    final visible = BodyGeometry.musclesFor(_side);

    return GlassCard(
      key: const ValueKey('muscles-week-card'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cơ đã tập tuần này',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
              ),
              BodySideToggle(
                side: _side,
                onChanged: (s) => setState(() => _side = s),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 220,
                child: Opacity(
                  opacity: data.isEmpty ? 0.6 : 1,
                  child: BodyFigure(
                    key: const ValueKey('muscles-week-figure'),
                    shape: shape,
                    side: _side,
                    mode: BodyFigureMode.heat,
                    heat: data.heat,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final m in visible)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (data.sets[m] ?? 0) > 0
                                    ? Color.lerp(
                                        c.buttonFill.withValues(alpha: 0.35),
                                        c.buttonFill,
                                        data.heat[m] ?? 0,
                                      )
                                    : c.border,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    kMuscleLabels[m] ?? m,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: (data.sets[m] ?? 0) > 0
                                          ? c.textPrimary
                                          : c.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    (data.sets[m] ?? 0) > 0
                                        ? '${data.sets[m]} hiệp'
                                        : 'Tuần này chưa tập',
                                    key: ValueKey('muscles-week-$m'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: (data.sets[m] ?? 0) > 0
                                          ? c.primary
                                          : c.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Ít',
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [
                        c.buttonFill.withValues(alpha: 0.35),
                        c.buttonFill,
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Nhiều',
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
            ],
          ),
          if (week.hasError && !week.hasValue) ...[
            const SizedBox(height: 8),
            Text(
              'Chưa tải được dữ liệu tuần này.',
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mục cài đặt "Cơ thể" trong tab Tôi: chiều cao, cân nặng, vóc dáng,
/// nhóm cơ ưu tiên (PATCH /me) và "Xem lại hướng dẫn".
class BodySettingsCard extends ConsumerWidget {
  const BodySettingsCard({super.key, required this.me});

  final MeResponse me;

  Future<bool> _patch(WidgetRef ref, SettingsRequest request) async {
    final ok = await ref
        .read(settingsControllerProvider.notifier)
        .patchSettings(request);
    if (ok) {
      ref.invalidate(bodyStatsProvider);
    }
    return ok;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    // Giữ provider PATCH /me sống trong lúc bảng chọn đang mở.
    ref.watch(settingsControllerProvider);
    final stats = ref.watch(bodyStatsProvider).valueOrNull;
    final female = (stats?.gender ?? me.profile?.gender) == 'female';
    final heightCm = stats?.heightCm ?? me.profile?.heightCm;
    final weightKg = stats?.weightKg ?? me.profile?.startWeightKg;
    final bmi = stats?.bmi ?? computeBmi(heightCm, weightKg);
    final fatPct = stats == null || stats.bodyFatEstimated
        ? null
        : stats.bodyFatPct?.round();
    final focus = stats?.focusMuscles ?? const <String>[];
    final presets = bodyFatPresets(female: female);
    final presetIndex = fatPct == null
        ? -1
        : presets.indexOf(nearestBodyFatPreset(fatPct, female: female)!);

    String fmt(double? v) =>
        v == null ? '–' : v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Cơ thể',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              _Row(
                rowKey: 'body-edit-size',
                icon: Icons.straighten_rounded,
                label: 'Chiều cao, cân nặng',
                value: '${fmt(heightCm)} cm · ${fmt(weightKg)} kg',
                onTap: () async {
                  final result = await showDialog<(double, double)>(
                    context: context,
                    builder: (_) =>
                        _SizeDialog(heightCm: heightCm, weightKg: weightKg),
                  );
                  if (result == null) return;
                  await _patch(
                    ref,
                    SettingsRequest(heightCm: result.$1, weightKg: result.$2),
                  );
                },
              ),
              Divider(height: 1, color: c.border),
              _Row(
                rowKey: 'body-edit-shape',
                icon: Icons.accessibility_new_rounded,
                label: 'Vóc dáng',
                value: presetIndex < 0
                    ? 'Chưa chọn'
                    : 'Hình ${presetIndex + 1}',
                onTap: () async {
                  final picked = await showModalBottomSheet<int>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: c.surface,
                    showDragHandle: true,
                    builder: (sheetContext) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Vóc dáng nào giống bạn nhất?',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            BodyShapePicker(
                              bmi: bmi,
                              female: female,
                              selectedPct: presetIndex < 0
                                  ? null
                                  : presets[presetIndex],
                              thumbHeight: 130,
                              onSelected: (pct) =>
                                  Navigator.of(sheetContext).pop(pct),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                  if (picked == null) return;
                  await _patch(ref, SettingsRequest(bodyFatPct: picked));
                },
              ),
              Divider(height: 1, color: c.border),
              _Row(
                rowKey: 'body-edit-focus',
                icon: Icons.fitness_center_rounded,
                label: 'Nhóm cơ muốn cải thiện',
                value: focus.isEmpty
                    ? 'Chưa chọn'
                    : focus.map((m) => kMuscleLabels[m] ?? m).join(', '),
                onTap: () async {
                  final picked = await showModalBottomSheet<List<String>>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: c.surface,
                    showDragHandle: true,
                    builder: (_) => _FocusSheet(
                      shape: stats?.shape ?? BodyShape.from(female: female),
                      initial: focus.toSet(),
                    ),
                  );
                  if (picked == null) return;
                  await _patch(ref, SettingsRequest(focusMuscles: picked));
                },
              ),
              Divider(height: 1, color: c.border),
              _Row(
                rowKey: 'replay-tutorials',
                icon: Icons.school_outlined,
                label: 'Xem lại hướng dẫn',
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await replayTutorials(ref);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Hướng dẫn sẽ hiện lại khi bạn mở từng màn hình.',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.rowKey,
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  final String rowKey;
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      key: ValueKey(rowKey),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  if (value != null)
                    Text(
                      value!,
                      key: ValueKey('$rowKey-value'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SizeDialog extends StatefulWidget {
  const _SizeDialog({this.heightCm, this.weightKg});

  final double? heightCm;
  final double? weightKg;

  @override
  State<_SizeDialog> createState() => _SizeDialogState();
}

class _SizeDialogState extends State<_SizeDialog> {
  late final TextEditingController _height = TextEditingController(
    text: widget.heightCm?.round().toString() ?? '',
  );
  late final TextEditingController _weight = TextEditingController(
    text: widget.weightKg == null
        ? ''
        : widget.weightKg!.toStringAsFixed(widget.weightKg! % 1 == 0 ? 0 : 1),
  );
  String? _error;

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _submit() {
    final h = double.tryParse(_height.text.trim().replaceAll(',', '.'));
    final w = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    if (h == null || h < 100 || h > 230) {
      setState(() => _error = 'Chiều cao từ 100 tới 230 cm');
      return;
    }
    if (w == null || w < 25 || w > 250) {
      setState(() => _error = 'Cân nặng từ 25 tới 250 kg');
      return;
    }
    Navigator.of(context).pop((h, w));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    InputDecoration deco(String label, String suffix) => InputDecoration(
      labelText: label,
      suffixText: suffix,
      filled: true,
      fillColor: c.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
    return AlertDialog(
      backgroundColor: c.surface,
      title: Text(
        'Chiều cao, cân nặng',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: c.textPrimary,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('body-height-field'),
            controller: _height,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: deco('Chiều cao', 'cm'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('body-weight-field'),
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: deco('Cân nặng', 'kg'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(fontSize: 13, color: c.errorText)),
          ],
          const SizedBox(height: 8),
          Text(
            'Mục tiêu calo và nước sẽ được tính lại theo số đo mới.',
            style: TextStyle(fontSize: 12, color: c.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Huỷ'),
        ),
        TextButton(
          key: const ValueKey('body-size-save'),
          onPressed: _submit,
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

class _FocusSheet extends StatefulWidget {
  const _FocusSheet({required this.shape, required this.initial});

  final BodyShape shape;
  final Set<String> initial;

  @override
  State<_FocusSheet> createState() => _FocusSheetState();
}

class _FocusSheetState extends State<_FocusSheet> {
  late final Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nhóm cơ bạn muốn cải thiện',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            MuscleMapPicker(
              shape: widget.shape,
              selected: _selected,
              figureHeight: 260,
              onToggle: (m) => setState(() {
                if (!_selected.remove(m)) _selected.add(m);
              }),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              key: const ValueKey('body-focus-save'),
              label: 'Lưu',
              onPressed: () =>
                  Navigator.of(context)
                      .pop(kMuscleGroups.where(_selected.contains).toList()),
            ),
          ],
        ),
      ),
    );
  }
}
