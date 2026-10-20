import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_palette.dart';
import '../../../../core/voice/voice_provider.dart';
export 'exercise_image.dart';

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
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.border),
              boxShadow: [
                BoxShadow(
                  color: context.colors.cardNormalShadow,
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: context.colors.textPrimary, size: 22),
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
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String? stepLabel;
  final double? progress;
  final VoidCallback? onClose;
  final IconData closeIcon;
  final Widget? trailing;

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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 8),
            ],
            if (stepLabel != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                  border: Border.all(color: context.colors.border),
                ),
                child: Text(
                  stepLabel!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textSecondary,
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
        backgroundColor: context.colors.progressTrack,
        valueColor: AlwaysStoppedAnimation(context.colors.progressFill),
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
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusCard - 6),
        border: Border.all(color: context.colors.cardNormalBorder),
        boxShadow: [
          BoxShadow(
            color: context.colors.cardNormalShadow,
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
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textSecondary,
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
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
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
        color: context.colors.primaryLight,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.colors.border),
            ),
            child: Icon(
              icon,
              size: 20,
              color: onTap == null
                  ? context.colors.textSecondary.withValues(alpha: 0.4)
                  : context.colors.primary,
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
        color: context.colors.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: context.colors.primary),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: context.colors.textPrimary,
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
        color: context.colors.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.primary),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 20,
            color: context.colors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
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

/// Nút loa bật/tắt nhanh giọng đọc huấn luyện viên trên màn hình tập.
class VoiceMuteButton extends ConsumerWidget {
  const VoiceMuteButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(voiceSettingsProvider);
    final isMuted = !settings.effectiveActive;

    return Semantics(
      label: isMuted ? 'Bật tiếng giọng đọc khi tập' : 'Tắt tiếng giọng đọc khi tập',
      button: true,
      child: Tooltip(
        message: isMuted ? 'Bật tiếng' : 'Tắt tiếng',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('voice-mute-button'),
            onTap: () {
              ref.read(voiceSettingsProvider.notifier).toggleMuteTemporarily();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.border),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.cardNormalShadow,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: isMuted ? context.colors.textSecondary : context.colors.primary,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

