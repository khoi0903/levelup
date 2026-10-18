import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exceptions.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../nutrition/presentation/widgets/nutrition_widgets.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../../domain/models/product_models.dart';
import '../controllers/product_controller.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    if (me == null || (!me.isAdmin && !me.demoEnabled)) {
      return const FeatureScaffold(
        title: 'Không tìm thấy trang',
        child: SizedBox.shrink(),
      );
    }
    return FeatureScaffold(
      title: 'Admin',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (me.demoEnabled)
            GlassCard(
              child: ListTile(
                title: const Text('Các nút demo'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/demo'),
              ),
            ),
          if (me.isAdmin)
            GlassCard(
              child: ListTile(
                title: const Text('Duyệt món mới'),
                subtitle: const Text('Món AI nhận ra mà kho chưa có'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/admin/foods'),
              ),
            ),
          if (me.isAdmin)
            ref
                .watch(adminConfigProvider)
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => FeatureError(
                    error: e,
                    retry: () => ref.invalidate(adminConfigProvider),
                  ),
                  data: (config) => AdminConfigForm(
                    key: ValueKey(config.version),
                    config: config,
                  ),
                ),
        ],
      ),
    );
  }
}

class AdminConfigForm extends ConsumerStatefulWidget {
  final ProductConfig config;
  const AdminConfigForm({super.key, required this.config});
  @override
  ConsumerState<AdminConfigForm> createState() => _AdminConfigFormState();
}

class _AdminConfigFormState extends ConsumerState<AdminConfigForm> {
  final formKey = GlobalKey<FormState>();
  late Map<String, dynamic> values;
  late List<ReferralMilestone> milestones;
  final email = TextEditingController(),
      days = TextEditingController(text: '7');
  bool busy = false;
  String? message;
  @override
  void initState() {
    super.initState();
    values = widget.config.toJson();
    milestones = [...widget.config.referralMilestones];
  }

  @override
  void dispose() {
    email.dispose();
    days.dispose();
    super.dispose();
  }

  String errorText(Object e) => e is ApiException && e.fields.isNotEmpty
      ? e.fields.entries.map((f) => '${f.key}: ${f.value}').join('\n')
      : mapErrorMessage(e);
  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    formKey.currentState!.save();
    values['referralMilestones'] = milestones.map((m) => m.toJson()).toList();
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await ref
          .read(productRepositoryProvider)
          .saveConfig(ProductConfig.fromJson(values));
      ref.invalidate(userStatusFutureProvider);
      final refreshed = await ref.read(userStatusFutureProvider.future);
      if (!mounted) return;
      ref.read(currentUserProvider.notifier).state = refreshed;
      if (mounted) setState(() => message = 'Đã lưu cấu hình');
      ref.invalidate(adminConfigProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã lưu cấu hình')));
      }
    } catch (e) {
      if (mounted) setState(() => message = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editMilestone([int? index]) async {
    final result = await showDialog<ReferralMilestone>(
      context: context,
      builder: (_) =>
          _MilestoneDialog(initial: index == null ? null : milestones[index]),
    );
    if (result != null && mounted) {
      setState(() {
        if (index == null) {
          milestones.add(result);
        } else {
          milestones[index] = result;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        for (final entry in {
          'proEnabled': 'Bật Pro',
          'referralEnabled': 'Bật giới thiệu',
        }.entries)
          SwitchListTile(
            title: Text(entry.value),
            value: values[entry.key] == true,
            onChanged: busy
                ? null
                : (v) => setState(() => values[entry.key] = v),
          ),
        const Text(
          'Giới hạn',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        for (final entry in {
          'coachFreePerDay': 'Coach miễn phí / ngày',
          'coachProPerDay': 'Coach Pro / ngày',
          'photosFreePerDay': 'Ảnh miễn phí / ngày',
          'photosProPerDay': 'Ảnh Pro / ngày',
          'referralInviteeDays': 'Ngày Pro cho người mới',
        }.entries)
          number(entry.key, entry.value),
        const SizedBox(height: 18),
        const Text(
          'Mốc giới thiệu',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        for (int i = 0; i < milestones.length; i++)
          ListTile(
            key: ValueKey('milestone-$i'),
            title: Text(
              '${milestones[i].friends} bạn → ${milestones[i].days} ngày',
            ),
            onTap: busy ? null : () => editMilestone(i),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: busy
                  ? null
                  : () => setState(() => milestones.removeAt(i)),
            ),
          ),
        TextButton(
          onPressed: busy ? null : () => editMilestone(),
          child: const Text('Thêm mốc'),
        ),
        const Text(
          'Giá & dùng thử',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        number('monthlyPriceVnd', 'Giá tháng (VND)', positive: true),
        number('yearlyPriceVnd', 'Giá năm (VND)', positive: true),
        number('trialDays', 'Ngày dùng thử'),
        const SizedBox(height: 16),
        if (message != null)
          Text(message!, key: const ValueKey('admin-message')),
        PrimaryButton(
          label: 'Lưu cấu hình',
          onPressed: busy ? null : save,
          isLoading: busy,
        ),
        const SizedBox(height: 24),
        const Text(
          'Cấp Pro theo email',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        TextField(
          controller: email,
          decoration: const InputDecoration(labelText: 'Email'),
          keyboardType: TextInputType.emailAddress,
        ),
        TextField(
          controller: days,
          decoration: const InputDecoration(labelText: 'Số ngày Pro'),
          keyboardType: TextInputType.number,
        ),
        TextButton(
          onPressed: busy
              ? null
              : () async {
                  final count = int.tryParse(days.text);
                  if (count == null ||
                      count <= 0 ||
                      email.text.trim().isEmpty) {
                    setState(() => message = 'Nhập email và số ngày lớn hơn 0');
                    return;
                  }
                  setState(() => busy = true);
                  try {
                    await ref
                        .read(productRepositoryProvider)
                        .grantPro(email.text.trim(), count);
                    if (mounted) setState(() => message = 'Đã cấp Pro');
                  } catch (e) {
                    if (mounted) setState(() => message = errorText(e));
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: const Text('Cấp Pro'),
        ),
      ],
    ),
  );
  Widget number(String field, String label, {bool positive = false}) =>
      TextFormField(
        key: ValueKey('config-$field'),
        initialValue: values[field].toString(),
        enabled: !busy,
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        validator: (v) {
          final n = int.tryParse(v ?? '');
          return n != null && n >= (positive ? 1 : 0) ? null : 'Nhập số hợp lệ';
        },
        onSaved: (v) => values[field] = int.parse(v!),
      );
}

class _MilestoneDialog extends StatefulWidget {
  final ReferralMilestone? initial;
  const _MilestoneDialog({this.initial});
  @override
  State<_MilestoneDialog> createState() => _MilestoneDialogState();
}

class _MilestoneDialogState extends State<_MilestoneDialog> {
  final form = GlobalKey<FormState>();
  late final friends = TextEditingController(
    text: widget.initial?.friends.toString() ?? '',
  );
  late final days = TextEditingController(
    text: widget.initial?.days.toString() ?? '7',
  );
  @override
  void dispose() {
    friends.dispose();
    days.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Thêm mốc' : 'Sửa mốc'),
    content: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            key: const ValueKey('milestone-friends'),
            controller: friends,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Số bạn'),
            validator: (v) => (int.tryParse(v ?? '') ?? 0) > 0
                ? null
                : 'Nhập số bạn lớn hơn 0',
          ),
          TextFormField(
            key: const ValueKey('milestone-days'),
            controller: days,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Ngày Pro'),
            validator: (v) =>
                (int.tryParse(v ?? '') ?? -1) >= 0 ? null : 'Nhập số ngày từ 0',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Huỷ'),
      ),
      TextButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(
              context,
              ReferralMilestone(int.parse(friends.text), int.parse(days.text)),
            );
          }
        },
        child: const Text('Xong'),
      ),
    ],
  );
}
