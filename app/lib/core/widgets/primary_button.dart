import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;
  final Widget? icon;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 52.0,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null && !isLoading;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isEnabled ? AppColors.primaryButtonGradient : null,
        color: isEnabled ? null : AppColors.cardNormalBg.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppColors.radiusButton),
        border: Border.all(
          color: isEnabled ? AppColors.btnBorder : Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: isEnabled
            ? const [
                BoxShadow(
                  color: AppColors.btnShadow,
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppColors.radiusButton),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
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
                            fontSize: 16,
                            fontWeight: FontWeight.w800, // ExtraBold
                            color: isEnabled ? Colors.white : Colors.white.withValues(alpha: 0.55),
                            letterSpacing: 0.2,
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
