import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_palette.dart';

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
        color: isSelected ? context.colors.cardSelectedBg : context.colors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
        border: Border.all(
          color: isSelected ? context.colors.cardSelectedBorder : context.colors.border,
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: context.colors.cardSelectedShadow,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
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
                  color: isSelected ? context.colors.accentLink : context.colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

