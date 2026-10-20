import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exceptions.dart';
import '../../../../core/constants/app_palette.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../controllers/product_controller.dart';

class ProLimitAction extends ConsumerWidget {
  final Object? error;
  const ProLimitAction({super.key, this.error});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled =
        ref.watch(currentUserProvider)?.subscription.enabled == true;
    final code = error is ApiException ? (error as ApiException).code : null;
    if (!enabled || (code != 'COACH_LIMIT' && code != 'PHOTO_LIMIT_REACHED')) {
      return const SizedBox.shrink();
    }
    return TextButton(
      onPressed: () => context.push('/pro'),
      child: const Text('Xem gói Pro'),
    );
  }
}

class ProductProfileCards extends ConsumerWidget {
  const ProductProfileCards({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    if (me?.subscription.enabled != true) return const SizedBox.shrink();
    return Column(
      children: [
        GlassCard(
          child: ListTile(
            leading: Icon(
              Icons.workspace_premium_outlined,
              color: context.colors.primary,
            ),
            title: const Text('LevelUp Pro'),
            subtitle: Text(
              me!.subscription.tier == 'pro'
                  ? 'Bạn đang dùng Pro'
                  : 'Thêm lượt AI coach và chụp món',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/pro'),
          ),
        ),
        const SizedBox(height: 12),
        if (me.productConfig.referralEnabled) ...[
          GlassCard(
            child: ListTile(
              leading: Icon(
                Icons.group_add_outlined,
                color: context.colors.primary,
              ),
              title: const Text('Mời bạn, nhận Pro'),
              subtitle: const Text('Cùng tập buổi đầu để nhận thưởng'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/referrals'),
            ),
          ),
          const SizedBox(height: 12),
          if (canRedeemReferral(ref)) const ReferralCodeInput(),
        ],
      ],
    );
  }
}

class ReferralCodeInput extends ConsumerStatefulWidget {
  const ReferralCodeInput({super.key});
  @override
  ConsumerState<ReferralCodeInput> createState() => _ReferralCodeInputState();
}

class _ReferralCodeInputState extends ConsumerState<ReferralCodeInput> {
  final controller = TextEditingController();
  bool busy = false, done = false;
  String? message;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> redeem() async {
    setState(() => busy = true);
    try {
      await ref.read(productRepositoryProvider).redeem(controller.text);
      ref.invalidate(userStatusFutureProvider);
      final refreshed = await ref.read(userStatusFutureProvider.future);
      if (!mounted) return;
      ref.read(currentUserProvider.notifier).state = refreshed;
      if (mounted) {
        setState(() {
          done = true;
          message = 'Đã nhận Pro từ mã giới thiệu!';
        });
      }
    } catch (e) {
      if (mounted) setState(() => message = mapErrorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('referral-code-input'),
          controller: controller,
          enabled: !busy && !done,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Nhập mã giới thiệu'),
        ),
        TextButton(
          onPressed: busy || done ? null : redeem,
          child: Text(busy ? 'Đang kiểm tra…' : 'Áp dụng mã'),
        ),
        if (message != null)
          Text(message!, key: const ValueKey('referral-message')),
      ],
    ),
  );
}
