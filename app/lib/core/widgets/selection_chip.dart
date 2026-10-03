import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class SelectionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final double height;

  const SelectionChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.height = 44.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.cardSelectedBg : AppColors.cardNormalBg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
        border: Border.all(
          color: isSelected ? AppColors.cardSelectedBorder : AppColors.cardNormalBorder,
          width: 1.5,
        ),
        boxShadow: isSelected
            ? const [
                BoxShadow(
                  color: AppColors.cardSelectedShadow,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppColors.radiusPill),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.accentLink : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
