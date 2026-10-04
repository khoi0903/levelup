import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Dòng nhắc ngay trên nút "Tiếp tục" khi nút bị khóa: nói rõ còn thiếu hoặc sai gì,
/// để người dùng không phải đoán vì sao bấm không được.
class MissingHint extends StatelessWidget {
  final String? message;

  const MissingHint(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              key: const ValueKey('onboarding-missing-hint'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
