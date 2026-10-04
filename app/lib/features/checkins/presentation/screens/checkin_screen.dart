import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../home/presentation/controllers/home_controller.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../controllers/checkin_controller.dart';

/// Màn hình Check-in buổi sáng (F2).
class CheckinScreen extends ConsumerWidget {
  const CheckinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkinControllerProvider);
    final notifier = ref.read(checkinControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Check-in hôm nay',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: state.response != null
              ? _buildResultView(context, ref, state)
              : _buildFormView(context, ref, state, notifier),
        ),
      ),
    );
  }

  Widget _buildFormView(
    BuildContext context,
    WidgetRef ref,
    CheckinState state,
    CheckinNotifier notifier,
  ) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      children: [
        const Text(
          'Chào buổi sáng! Hôm nay bạn cảm thấy thế nào?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Coach sẽ điều chỉnh bài tập hôm nay cho phù hợp với trạng thái của bạn.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),

        // Mức năng lượng
        const Text(
          'Mức năng lượng',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        _buildEnergyOption(
          label: 'Tràn đầy năng lượng',
          subtitle: 'Sẵn sàng chinh phục bài tập hôm nay',
          icon: '⚡',
          value: 'energized',
          selectedValue: state.energy,
          onTap: () => notifier.setEnergy('energized'),
        ),
        const SizedBox(height: 8),
        _buildEnergyOption(
          label: 'Bình thường',
          subtitle: 'Cảm giác ổn định, sẵn sàng tập theo kế hoạch',
          icon: '😊',
          value: 'normal',
          selectedValue: state.energy,
          onTap: () => notifier.setEnergy('normal'),
        ),
        const SizedBox(height: 8),
        _buildEnergyOption(
          label: 'Mệt mỏi / Uể oải',
          subtitle: 'Coach sẽ tự động giảm nhẹ bài tập cho bạn',
          icon: '😴',
          value: 'tired',
          selectedValue: state.energy,
          onTap: () => notifier.setEnergy('tired'),
        ),
        const SizedBox(height: 22),

        // Thời gian ngủ đêm qua
        const Text(
          'Thời gian ngủ đêm qua',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildSleepChip(
                label: '< 6 giờ',
                value: 'lt6',
                selectedValue: state.sleep,
                onTap: () => notifier.setSleep(state.sleep == 'lt6' ? null : 'lt6'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSleepChip(
                label: '6–7 giờ',
                value: 'h6_7',
                selectedValue: state.sleep,
                onTap: () => notifier.setSleep(state.sleep == 'h6_7' ? null : 'h6_7'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSleepChip(
                label: '7–8 giờ',
                value: 'h7_8',
                selectedValue: state.sleep,
                onTap: () => notifier.setSleep(state.sleep == 'h7_8' ? null : 'h7_8'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSleepChip(
                label: '> 8 giờ',
                value: 'gt8',
                selectedValue: state.sleep,
                onTap: () => notifier.setSleep(state.sleep == 'gt8' ? null : 'gt8'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        if (state.error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mapErrorMessage(state.error),
                    key: const ValueKey('checkin-error-text'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF991B1B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        PrimaryButton(
          label: state.isSubmitting ? 'Đang gửi...' : 'Xác nhận check-in',
          onPressed: state.isSubmitting
              ? null
              : () async {
                  final res = await notifier.submit();
                  if (res != null) {
                    ref.invalidate(homePlanProvider);
                    ref.invalidate(userStatusFutureProvider);
                  }
                },
        ),
      ],
    );
  }

  Widget _buildEnergyOption({
    required String label,
    required String subtitle,
    required String icon,
    required String value,
    required String selectedValue,
    required VoidCallback onTap,
  }) {
    final isSelected = value == selectedValue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusCard),
      child: GlassCard(
        isSelected: isSelected,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.radioUnselectedBorder,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepChip({
    required String label,
    required String value,
    required String? selectedValue,
    required VoidCallback onTap,
  }) {
    final isSelected = value == selectedValue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildResultView(BuildContext context, WidgetRef ref, CheckinState state) {
    final response = state.response!;
    final session = response.session;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 40,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Đã hoàn thành check-in!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          response.adjusted
              ? 'Coach đã điều chỉnh buổi tập hôm nay cho bạn.'
              : 'Tuyệt vời! Buổi tập hôm nay vẫn theo đúng kế hoạch ban đầu.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),

        if (session != null) ...[
          GlassCard(
            padding: const EdgeInsets.all(16),
            isSelected: response.adjusted,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      response.adjusted ? 'Buổi tập đã điều chỉnh' : 'Buổi tập hôm nay',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentLink,
                      ),
                    ),
                    Text(
                      '${session.durationMin} phút',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  session.title,
                  key: const ValueKey('checkin-session-title'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (session.adjustedReason != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            session.adjustedReason == 'checkin_tired'
                                ? 'Vì sáng nay bạn chọn "Mệt mỏi", coach đã giảm bớt 1 hiệp cho các động tác.'
                                : 'Buổi tập đã được điều chỉnh: ${session.adjustedReason}',
                            key: const ValueKey('checkin-adjusted-reason'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (session.items.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    session.items.map((i) => i.nameVi ?? i.exerciseId).join(' · '),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        if (session != null) ...[
          PrimaryButton(
            label: 'Bắt đầu tập buổi này',
            onPressed: () => context.go('/workout/${session.id}'),
          ),
          const SizedBox(height: 10),
        ],

        SecondaryButton(
          label: 'Về trang chủ',
          onPressed: () => context.go('/home'),
        ),
      ],
    );
  }
}
