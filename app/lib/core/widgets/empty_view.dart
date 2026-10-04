import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';

/// Widget hiển thị trạng thái trống dùng chung (chưa có dữ liệu, chưa ghép cặp, chưa có review...).
class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyView({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1.0),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                key: const ValueKey('empty-view-title'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  key: const ValueKey('empty-view-subtitle'),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: 180,
                  child: PrimaryButton(
                    label: actionLabel!,
                    height: 44,
                    onPressed: onAction,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
