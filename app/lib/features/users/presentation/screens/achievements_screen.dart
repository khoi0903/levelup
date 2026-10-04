import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../workout/domain/models/workout_models.dart';
import '../controllers/user_controller.dart';

/// Màn hình Danh sách Huy hiệu (F7).
/// Dữ liệu huy hiệu lấy trực tiếp từ trường `achievements` trong GET /me.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  static const List<Achievement> systemCatalog = [
    Achievement(
      code: 'sessions_1',
      nameVi: 'Bước đầu vững vàng',
      descriptionVi: 'Hoàn thành buổi tập đầu tiên, hãy tự hào về bước khởi đầu này!',
      category: 'sessions',
    ),
    Achievement(
      code: 'first_workout',
      nameVi: 'Bước đầu tiên',
      descriptionVi: 'Hoàn thành buổi tập đầu tiên cùng LevelUp',
      category: 'sessions',
    ),
    Achievement(
      code: 'sessions_10',
      nameVi: 'Mười buổi tiến bộ',
      descriptionVi: 'Hoàn thành 10 buổi tập, mỗi buổi đều giúp bạn tiến thêm một bước!',
      category: 'sessions',
    ),
    Achievement(
      code: 'streak_1w',
      nameVi: 'Chiến binh 1 tuần',
      descriptionVi: 'Hoàn thành trọn vẹn tuần tập đầu tiên',
      category: 'streak',
    ),
    Achievement(
      code: 'streak_2',
      nameVi: 'Hai tuần giữ nhịp',
      descriptionVi: 'Đạt mục tiêu tập luyện 2 tuần liên tiếp, tiếp tục giữ nhịp!',
      category: 'streak',
    ),
    Achievement(
      code: 'streak_4',
      nameVi: 'Một tháng bền bỉ',
      descriptionVi: 'Đạt mục tiêu tập luyện 4 tuần liên tiếp, thói quen vững vàng hơn!',
      category: 'streak',
    ),
    Achievement(
      code: 'strength_pr_1',
      nameVi: 'Kỷ lục của riêng bạn',
      descriptionVi: 'Lập kỷ lục cá nhân đầu tiên, bứt phá giới hạn bản thân!',
      category: 'strength',
    ),
    Achievement(
      code: 'buddy_pair_1',
      nameVi: 'Có bạn đồng hành',
      descriptionVi: 'Ghép buddy đầu tiên, cùng nhau giữ động lực mỗi tuần!',
      category: 'buddy',
    ),
    Achievement(
      code: 'checkin_days_7',
      nameVi: 'Bảy ngày hiện diện',
      descriptionVi: 'Check-in 7 ngày liên tiếp, mỗi lần hiện diện đều đáng ghi nhận!',
      category: 'streak',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userStatusFutureProvider);
    final me = userAsync.valueOrNull;

    // Huy hiệu đã mở khóa từ GET /me (mới nhất trước)
    final earnedList = me?.achievements ?? const [];
    final earnedMap = <String, Achievement>{for (final a in earnedList) a.code: a};

    // Ghép các huy hiệu từ catalog và bất kỳ huy hiệu nào user đã có
    final displayedBadges = <Achievement>[];
    final seenCodes = <String>{};

    // Đưa huy hiệu đã đạt lên trước
    for (final a in earnedList) {
      displayedBadges.add(a);
      seenCodes.add(a.code);
    }
    // Sau đó thêm các huy hiệu trong catalog chưa đạt
    for (final a in systemCatalog) {
      if (!seenCodes.contains(a.code)) {
        displayedBadges.add(a);
        seenCodes.add(a.code);
      }
    }

    final totalCount = displayedBadges.length;
    final earnedCount = earnedList.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Huy hiệu của bạn',
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
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            children: [
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.military_tech_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bộ sưu tập huy hiệu',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Đã mở khóa $earnedCount/$totalCount huy hiệu',
                            key: const ValueKey('achievements-count-text'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Danh sách huy hiệu',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              for (final badge in displayedBadges)
                _buildBadgeItem(badge, earnedBadge: earnedMap[badge.code]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeItem(Achievement badge, {Achievement? earnedBadge}) {
    final isEarned = earnedBadge != null;
    final earnedDateText = _formatEarnedDate(earnedBadge?.earnedAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        isSelected: isEarned,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isEarned ? AppColors.primaryLight : const Color(0xFFF3F4F6),
              ),
              child: Icon(
                isEarned ? Icons.military_tech_rounded : Icons.lock_outline_rounded,
                color: isEarned ? AppColors.primary : Colors.grey,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          badge.nameVi,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isEarned ? AppColors.textPrimary : Colors.grey.shade700,
                          ),
                        ),
                      ),
                      if (isEarned) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle_rounded,
                            size: 16, color: AppColors.primary),
                      ],
                    ],
                  ),
                  if (badge.descriptionVi != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      badge.descriptionVi!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isEarned ? AppColors.textSecondary : Colors.grey,
                      ),
                    ),
                  ],
                  if (earnedDateText != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Đạt ngày $earnedDateText',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _formatEarnedDate(String? isoString) {
    if (isoString == null) return null;
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return null;
    }
  }
}
