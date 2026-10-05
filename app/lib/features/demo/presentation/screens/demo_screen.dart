import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../controllers/demo_controller.dart';

class DemoScreen extends ConsumerWidget {
  const DemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoControllerProvider);
    final notifier = ref.read(demoControllerProvider.notifier);

    final actions = [
      (
        'seed',
        'Nạp dữ liệu demo',
        'Nạp lịch sử 4 tuần: 9 buổi, streak 3 tuần, cân nặng, 21 bữa ăn',
        Icons.cloud_download_rounded,
      ),
      (
        'skip-two',
        'Giả lập bỏ 2 buổi',
        'Đánh dấu bỏ 2 buổi gần nhất để kích hoạt lời nhắc từ AI Coach',
        Icons.event_busy_rounded,
      ),
      (
        'close-week',
        'Chốt tuần ngay',
        'Đóng tuần hiện tại để tính streak và cấp thẻ đóng băng nếu cần',
        Icons.event_available_rounded,
      ),
      (
        'review',
        'Tạo tổng kết tuần',
        'Yêu cầu AI Coach phân tích và tạo bài tổng kết tuần tập luyện',
        Icons.auto_awesome_rounded,
      ),
      (
        'checkin',
        'Gửi check-in sáng',
        'Gửi thông báo nhắc nhở check-in buổi sáng đến thiết bị',
        Icons.wb_sunny_rounded,
      ),
      (
        'push-test',
        'Gửi thông báo thử',
        'Bắn một thông báo thử nghiệm qua Firebase Cloud Messaging',
        Icons.notifications_active_rounded,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Giả lập Demo',
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
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              // Notice banner
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.developer_mode_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Chế độ giả lập phục vụ trình diễn và kiểm thử nhanh các kịch bản.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Result status banner
              if (state.message != null) ...[
                Container(
                  key: const ValueKey('demo-result-container'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: state.isError
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(AppColors.radiusCard),
                    border: Border.all(
                      color: state.isError
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFF86EFAC),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        state.isError
                            ? Icons.error_outline_rounded
                            : Icons.check_circle_outline_rounded,
                        color: state.isError ? Colors.redAccent : Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          state.message!,
                          key: const ValueKey('demo-result-text'),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: state.isError
                                ? const Color(0xFF991B1B)
                                : const Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Action buttons
              ...actions.map((item) {
                final actionKey = item.$1;
                final title = item.$2;
                final subtitle = item.$3;
                final icon = item.$4;
                final isRunning = state.runningAction == actionKey;
                final isAnyRunning = state.runningAction != null;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    onTap: isAnyRunning
                        ? null
                        : () => notifier.runAction(actionKey),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isRunning
                                ? AppColors.primaryLight
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: isRunning
                              ? const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                    ),
                                  ),
                                )
                              : Icon(icon, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
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
                        if (isRunning)
                          const Text(
                            'Đang chạy...',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          )
                        else
                          const Icon(
                            Icons.play_circle_fill_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
