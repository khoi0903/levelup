import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;
  final bool isDark;
  final Widget? icon;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 48.0,
    this.isDark = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.textPrimary : AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusButton),
        border: Border.all(
          color: isDark ? Colors.transparent : AppColors.border,
          width: 1.0,
        ),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: AppColors.cardNormalShadow,
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppColors.radiusButton),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  icon!,
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

