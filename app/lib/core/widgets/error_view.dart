import 'package:flutter/material.dart';
import '../constants/app_palette.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';

/// Widget hiển thị màn hình / khối lỗi dùng chung cho toàn bộ app.
class ErrorView extends StatelessWidget {
  final String? code;
  final String message;
  final String? title;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  const ErrorView({
    super.key,
    this.code,
    required this.message,
    this.title,
    this.onRetry,
    this.retryLabel = 'Thử lại',
    this.icon = Icons.error_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final displayTitle = title ??
        (code != null && code!.isNotEmpty
            ? 'Có lỗi xảy ra ($code)'
            : 'Đã xảy ra lỗi');

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
                  color: context.colors.primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.border, width: 1.0),
                ),
                child: Icon(
                  icon,
                  size: 34,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                displayTitle,
                key: const ValueKey('error-view-title'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                key: const ValueKey('error-view-message'),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: 150,
                  child: PrimaryButton(
                    label: retryLabel,
                    height: 44,
                    onPressed: onRetry,
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
