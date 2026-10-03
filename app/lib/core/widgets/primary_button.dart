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
        color: isEnabled
            ? AppColors.primary
            : AppColors.primary.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppColors.radiusButton),
        boxShadow: isEnabled
            ? const [
                BoxShadow(
                  color: AppColors.btnShadow,
                  blurRadius: 20,
                  offset: Offset(0, 8),
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
                            fontWeight: FontWeight.w800,
                            color: isEnabled
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.65),
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

