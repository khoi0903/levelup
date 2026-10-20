import 'package:flutter/material.dart';
import '../constants/app_palette.dart';
import '../widgets/glass_card.dart';

/// Khung placeholder cơ bản cho trạng thái đang tải (skeleton).
class AppSkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const AppSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  State<AppSkeletonBox> createState() => _AppSkeletonBoxState();
}

class _AppSkeletonBoxState extends State<AppSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: context.colors.placeholder.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Skeleton cho màn hình Trang chủ khi đang tải /me, /streak, /plans/current.
class HomeScreenSkeleton extends StatelessWidget {
  const HomeScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonBox(width: 90, height: 14, borderRadius: 6),
                SizedBox(height: 6),
                AppSkeletonBox(width: 180, height: 26, borderRadius: 8),
              ],
            ),
            AppSkeletonBox(width: 72, height: 36, borderRadius: 18),
          ],
        ),
        const SizedBox(height: 16),

        // Tuần này card skeleton
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  AppSkeletonBox(width: 80, height: 16, borderRadius: 6),
                  AppSkeletonBox(width: 60, height: 16, borderRadius: 6),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  7,
                  (index) => const Column(
                    children: [
                      AppSkeletonBox(width: 32, height: 32, borderRadius: 16),
                      SizedBox(height: 6),
                      AppSkeletonBox(width: 20, height: 10, borderRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Buổi tập hôm nay skeleton
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              AppSkeletonBox(width: double.infinity, height: 100, borderRadius: 16),
              SizedBox(height: 12),
              AppSkeletonBox(width: 110, height: 14, borderRadius: 6),
              SizedBox(height: 6),
              AppSkeletonBox(width: 200, height: 22, borderRadius: 8),
              SizedBox(height: 6),
              AppSkeletonBox(width: 140, height: 14, borderRadius: 6),
              SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: AppSkeletonBox(height: 48, borderRadius: 16),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: AppSkeletonBox(height: 48, borderRadius: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Buddy feed skeleton
        const GlassCard(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              AppSkeletonBox(width: 36, height: 36, borderRadius: 18),
              SizedBox(width: 12),
              Expanded(
                child: AppSkeletonBox(height: 16, borderRadius: 6),
              ),
              SizedBox(width: 12),
              AppSkeletonBox(width: 76, height: 32, borderRadius: 16),
            ],
          ),
        ),
      ],
    );
  }
}

/// Thanh LinearProgressIndicator mảnh hiển thị trên đầu trang khi đang tải lại
/// mà đã có sẵn dữ liệu cũ (không che màn hình).
class ReloadingIndicator extends StatelessWidget {
  final bool isReloading;

  const ReloadingIndicator({super.key, required this.isReloading});

  @override
  Widget build(BuildContext context) {
    if (!isReloading) return const SizedBox.shrink();
    return SizedBox(
      height: 3,
      child: LinearProgressIndicator(
        minHeight: 3,
        color: context.colors.primary,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}

/// Skeleton cho màn hình Tập (WorkoutStartScreen).
class WorkoutScreenSkeleton extends StatelessWidget {
  const WorkoutScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const AppSkeletonBox(width: 140, height: 24, borderRadius: 8),
        const SizedBox(height: 8),
        const AppSkeletonBox(width: 220, height: 16, borderRadius: 6),
        const SizedBox(height: 20),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              AppSkeletonBox(width: 160, height: 20, borderRadius: 6),
              SizedBox(height: 12),
              AppSkeletonBox(width: double.infinity, height: 80, borderRadius: 12),
              SizedBox(height: 12),
              AppSkeletonBox(width: double.infinity, height: 80, borderRadius: 12),
              SizedBox(height: 12),
              AppSkeletonBox(width: double.infinity, height: 80, borderRadius: 12),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const AppSkeletonBox(width: double.infinity, height: 50, borderRadius: 16),
      ],
    );
  }
}

/// Skeleton cho màn hình Coach Chat (CoachScreen).
class CoachScreenSkeleton extends StatelessWidget {
  const CoachScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: const [
        Align(
          alignment: Alignment.centerLeft,
          child: AppSkeletonBox(width: 240, height: 60, borderRadius: 16),
        ),
        SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: AppSkeletonBox(width: 180, height: 48, borderRadius: 16),
        ),
        SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: AppSkeletonBox(width: 280, height: 90, borderRadius: 16),
        ),
        SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: AppSkeletonBox(width: 200, height: 48, borderRadius: 16),
        ),
      ],
    );
  }
}

/// Skeleton cho màn hình Dinh dưỡng (NutritionScreen).
class NutritionScreenSkeleton extends StatelessWidget {
  const NutritionScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const AppSkeletonBox(width: 160, height: 16, borderRadius: 6),
        const SizedBox(height: 14),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              AppSkeletonBox(width: 120, height: 18, borderRadius: 6),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppSkeletonBox(width: 70, height: 50, borderRadius: 10),
                  AppSkeletonBox(width: 70, height: 50, borderRadius: 10),
                  AppSkeletonBox(width: 70, height: 50, borderRadius: 10),
                  AppSkeletonBox(width: 70, height: 50, borderRadius: 10),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const GlassCard(
          padding: EdgeInsets.all(16),
          child: AppSkeletonBox(width: double.infinity, height: 70, borderRadius: 12),
        ),
        const SizedBox(height: 14),
        const AppSkeletonBox(width: double.infinity, height: 48, borderRadius: 16),
      ],
    );
  }
}

/// Skeleton cho màn hình Tôi - Hồ sơ & Cài đặt (ProfileScreen).
class ProfileScreenSkeleton extends StatelessWidget {
  const ProfileScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: const [
              AppSkeletonBox(width: 80, height: 80, borderRadius: 40),
              SizedBox(height: 12),
              AppSkeletonBox(width: 160, height: 22, borderRadius: 8),
              SizedBox(height: 6),
              AppSkeletonBox(width: 120, height: 14, borderRadius: 6),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: const [
              AppSkeletonBox(width: double.infinity, height: 44, borderRadius: 10),
              SizedBox(height: 12),
              AppSkeletonBox(width: double.infinity, height: 44, borderRadius: 10),
              SizedBox(height: 12),
              AppSkeletonBox(width: double.infinity, height: 44, borderRadius: 10),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const GlassCard(
          padding: EdgeInsets.all(16),
          child: AppSkeletonBox(width: double.infinity, height: 120, borderRadius: 12),
        ),
      ],
    );
  }
}

/// Skeleton cho màn hình Chuỗi tuần - Streak (StreakScreen).
class StreakScreenSkeleton extends StatelessWidget {
  const StreakScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            children: const [
              AppSkeletonBox(width: 90, height: 90, borderRadius: 45),
              SizedBox(height: 16),
              AppSkeletonBox(width: 140, height: 28, borderRadius: 8),
              SizedBox(height: 8),
              AppSkeletonBox(width: 180, height: 14, borderRadius: 6),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              AppSkeletonBox(width: 120, height: 18, borderRadius: 6),
              SizedBox(height: 14),
              AppSkeletonBox(width: double.infinity, height: 60, borderRadius: 12),
              SizedBox(height: 10),
              AppSkeletonBox(width: double.infinity, height: 60, borderRadius: 12),
            ],
          ),
        ),
      ],
    );
  }
}

