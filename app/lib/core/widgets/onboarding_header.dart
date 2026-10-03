import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';

class OnboardingHeader extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onBack;

  const OnboardingHeader({
    super.key,
    required this.currentStep,
    this.totalSteps = 7,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentStep / totalSteps).clamp(0.0, 1.0);
    final stepText = '$currentStep/$totalSteps';

    if (currentStep == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                AppStrings.appName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                stepText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ProgressBar(progress: progress),
        ],
      );
    }

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onBack ?? () => Navigator.of(context).maybePop(),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.cardNormalBg.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.btnBorder, width: 1.2),
                  ),
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.textPrimary,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _ProgressBar(progress: progress),
        ),
        const SizedBox(width: 14),
        Text(
          stepText,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;

  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.progressTrack, // rãnh trắng 40%
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: constraints.maxWidth * progress,
              height: 8,
              decoration: BoxDecoration(
                gradient: AppColors.progressGradient, // gradient #8CA0F2 → #7D93EC → #6D84E8
                borderRadius: BorderRadius.circular(AppColors.radiusPill),
              ),
            ),
          );
        },
      ),
    );
  }
}
