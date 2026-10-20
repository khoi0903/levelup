import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_palette.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final bool isSelected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double? width;
  final double? height;

  const AppCard({
    super.key,
    required this.child,
    this.isSelected = false,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = AppColors.radiusCard,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: isSelected ? context.colors.cardSelectedBg : context.colors.cardNormalBg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isSelected ? context.colors.cardSelectedBorder : context.colors.cardNormalBorder,
        width: isSelected ? 1.5 : 1.0,
      ),
      boxShadow: [
        if (isSelected)
          BoxShadow(
            color: context.colors.cardSelectedShadow,
            blurRadius: 18,
            offset: Offset(0, 6),
          )
        else
          BoxShadow(
            color: context.colors.cardNormalShadow,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
      ],
    );

    Widget cardBody = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: decoration,
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: cardBody,
        ),
      );
    }

    return cardBody;
  }
}

typedef GlassCard = AppCard;

class AppRadio extends StatelessWidget {
  final bool isSelected;
  final double size;

  const AppRadio({
    super.key,
    required this.isSelected,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    if (isSelected) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: context.colors.buttonFill,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          color: Colors.white,
          size: 16,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.radioUnselectedBg,
        shape: BoxShape.circle,
        border: Border.all(
          color: context.colors.radioUnselectedBorder,
          width: 2.0,
        ),
      ),
    );
  }
}

typedef GlassRadio = AppRadio;

