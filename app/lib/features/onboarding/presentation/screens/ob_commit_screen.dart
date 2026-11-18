import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_palette.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../controllers/onboarding_controller.dart';

String _goalLabel(String? goal) => switch (goal) {
  'lose_fat' => 'Giảm mỡ',
  'build_muscle' => 'Tăng cơ',
  'get_healthier' => 'Khoẻ hơn mỗi ngày',
  'maintain' => 'Giữ dáng',
  _ => 'Tập đều mỗi tuần',
};

/// Màn cam kết trước khi bắt đầu: tóm tắt kế hoạch + nút "Tôi sẽ kiên trì!".
class ObCommitScreen extends ConsumerWidget {
  const ObCommitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final ob = ref.watch(onboardingControllerProvider);
    final me = ref.watch(currentUserProvider);
    final sessions = ob.weekdays.isNotEmpty
        ? ob.weekdays.length
        : (me?.settings.availability.length ?? 0);
    final minutes = ob.sessionMinutes ?? me?.profile?.sessionMinutes;
    final goal = ob.goal?.name ?? me?.profile?.goal;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        Container(
                          width: 84,
                          height: 84,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.flag_rounded,
                            size: 44,
                            color: c.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Kế hoạch của bạn đã sẵn sàng',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Không cần hoàn hảo, chỉ cần đều đặn. Mỗi buổi từ 5 phút đều được tính.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: c.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: Column(
                            children: [
                              _CommitRow(
                                rowKey: 'commit-sessions',
                                icon: Icons.calendar_month_rounded,
                                label: 'Số buổi mỗi tuần',
                                value: sessions > 0 ? '$sessions buổi' : '–',
                              ),
                              Divider(height: 1, color: c.border),
                              _CommitRow(
                                rowKey: 'commit-minutes',
                                icon: Icons.timer_outlined,
                                label: 'Mỗi buổi',
                                value: minutes == null ? '–' : '$minutes phút',
                              ),
                              Divider(height: 1, color: c.border),
                              _CommitRow(
                                rowKey: 'commit-goal',
                                icon: Icons.emoji_events_outlined,
                                label: 'Mục tiêu',
                                value: _goalLabel(goal),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  key: const ValueKey('commit-button'),
                  label: 'Tôi sẽ kiên trì!',
                  height: 60,
                  onPressed: () => context.push('/onboarding/start'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommitRow extends StatelessWidget {
  const _CommitRow({
    required this.rowKey,
    required this.icon,
    required this.label,
    required this.value,
  });

  final String rowKey;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: c.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 15, color: c.textSecondary),
            ),
          ),
          Text(
            value,
            key: ValueKey(rowKey),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
