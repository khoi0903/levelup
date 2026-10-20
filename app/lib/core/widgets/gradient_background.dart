import 'package:flutter/material.dart';
import '../constants/app_palette.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: context.colors.screenGradient,
      ),
      child: child,
    );
  }
}
