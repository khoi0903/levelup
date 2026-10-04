import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Nút vuông 44px nền trắng, dùng cho đóng/quay lại (giống OnboardingHeader).
class WorkoutIconButton extends StatelessWidget {
  const WorkoutIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.cardNormalShadow,
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Header màn tập: nút đóng, tiêu đề + phụ đề, nhãn bước, thanh tiến độ.
class WorkoutHeader extends StatelessWidget {
  const WorkoutHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.stepLabel,
    this.progress,
    this.onClose,
    this.closeIcon = Icons.close_rounded,
  });

  final String title;
  final String? subtitle;
  final String? stepLabel;
  final double? progress;
  final VoidCallback? onClose;
  final IconData closeIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (onClose != null) ...[
              WorkoutIconButton(
                icon: closeIcon,
                onTap: onClose,
                tooltip: 'Thoát',
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (stepLabel != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  stepLabel!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: 14),
          WorkoutProgressBar(progress: progress!),
        ],
      ],
    );
  }
}

class WorkoutProgressBar extends StatelessWidget {
  const WorkoutProgressBar({
    super.key,
    required this.progress,
    this.height = 6,
  });

  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppColors.radiusPill),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: AppColors.progressTrack,
        valueColor: const AlwaysStoppedAnimation(AppColors.progressFill),
      ),
    );
  }
}

/// Thẻ "Số lần" / "Tạ (kg)" với nút − và + (Figma: Squat ôm tạ).
class CounterCard extends StatelessWidget {
  const CounterCard({
    super.key,
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    this.valueKey,
  });

  final String label;
  final String value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusCard - 6),
        border: Border.all(color: AppColors.cardNormalBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardNormalShadow,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _RoundButton(
                icon: Icons.remove_rounded,
                onTap: onDecrement,
                tooltip: 'Giảm $label',
              ),
              Expanded(
                child: Text(
                  value,
                  key: valueKey,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _RoundButton(
                icon: Icons.add_rounded,
                onTap: onIncrement,
                tooltip: 'Tăng $label',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              icon,
              size: 20,
              color: onTap == null
                  ? AppColors.textSecondary.withValues(alpha: 0.4)
                  : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Khung chữ nhấn nhẹ (nền primaryLight) cho mẹo/cue.
class TipBox extends StatelessWidget {
  const TipBox({super.key, required this.child, this.icon});

  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner lỗi có nút thử lại.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Thử lại',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    // Bảng màu dịu mắt không có màu đỏ: báo lỗi bằng nền nhấn nhẹ + viền primary.
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}

/// "12:05" từ số giây.
String formatClock(int totalSec) {
  final s = totalSec < 0 ? 0 : totalSec;
  final m = s ~/ 60;
  final r = s % 60;
  return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
}

/// "12 phút 5 giây" / "45 giây".
String formatDurationVi(int totalSec) {
  final m = totalSec ~/ 60;
  final s = totalSec % 60;
  if (m == 0) return '$s giây';
  if (s == 0) return '$m phút';
  return '$m phút $s giây';
}

/// Mô tả tiếng Việt cho mã lỗi tư thế từ camera_counter.
String formIssueLabelVi(String code) => switch (code) {
  'shallow_depth' => 'Xuống chưa đủ sâu',
  'knee_valgus' => 'Gối hơi chụm vào trong',
  'back_rounding' => 'Lưng hơi cong',
  _ => code.replaceAll('_', ' '),
};
