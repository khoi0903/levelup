import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/glass_card.dart';
import '../../../nutrition/presentation/widgets/nutrition_widgets.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../controllers/product_controller.dart';
import '../widgets/product_widgets.dart';

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    if (me?.subscription.enabled != true ||
        me?.productConfig.referralEnabled != true) {
      return const FeatureScaffold(
        title: 'Không tìm thấy trang',
        child: SizedBox.shrink(),
      );
    }
    return FeatureScaffold(
      title: 'Mời bạn, nhận Pro',
      child: ref
          .watch(referralViewProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FeatureError(
              error: e,
              retry: () => ref.invalidate(referralViewProvider),
            ),
            data: (v) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                GlassCard(
                  child: Column(
                    children: [
                      const Text('Mã giới thiệu của bạn'),
                      SelectableText(
                        v.code,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                      Text(
                        'Bạn mới nhận ${me!.productConfig.referralInviteeDays} ngày Pro. Bạn được tính khi bạn mới tập buổi đầu từ 5 phút.',
                      ),
                      Wrap(
                        spacing: 12,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.copy),
                            label: const Text('Sao chép mã'),
                            onPressed: () => _copy(context, v.code),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.link),
                            label: const Text('Sao chép link'),
                            onPressed: () => _copy(context, v.link),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '${v.successfulCount} bạn đã tập buổi đầu',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (v.nextMilestone != null) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: (v.successfulCount / v.nextMilestone!.friends).clamp(
                      0,
                      1,
                    ),
                  ),
                  Text(
                    'Thêm ${v.nextMilestone!.friends - v.successfulCount} bạn để nhận ${v.nextMilestone!.days} ngày Pro',
                  ),
                ] else
                  const Text('Bạn đã đạt tất cả mốc!'),
                const SizedBox(height: 16),
                for (final m in v.milestones)
                  ListTile(
                    title: Text('${m.friends} bạn → ${m.days} ngày Pro'),
                    trailing: v.rewardsEarned.any((r) => r.friends == m.friends)
                        ? const Icon(Icons.check_circle_outline)
                        : null,
                  ),
                if (v.rewardsEarned.isNotEmpty)
                  Text(
                    'Đã nhận ${v.rewardsEarned.fold<int>(0, (sum, r) => sum + r.days)} ngày Pro',
                  ),
                if (canRedeemReferral(ref)) const ReferralCodeInput(),
              ],
            ),
          ),
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã sao chép')));
    }
  }
}
