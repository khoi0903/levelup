import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Widget hiển thị ảnh mẫu bài tập với cơ chế dự phòng 3 tầng:
/// 1. [thumbnailUrl] nếu có → ảnh từ mạng (lỗi thì rơi xuống tầng 2).
/// 2. `assets/exercises/<slug>.webp` nếu có (lỗi thì rơi xuống tầng 3).
/// 3. Icon tạ trên nền nhạt.
class ExerciseImage extends StatelessWidget {
  const ExerciseImage({
    super.key,
    this.slug,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.semanticLabel,
  });

  final String? slug;
  final String? thumbnailUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadiusGeometry? borderRadius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget content;

    final networkUrl = thumbnailUrl?.trim();
    if (networkUrl != null && networkUrl.isNotEmpty) {
      content = Image.network(
        networkUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return _buildAssetOrPlaceholder(context);
        },
      );
    } else {
      content = _buildAssetOrPlaceholder(context);
    }

    if (borderRadius != null) {
      content = ClipRRect(
        borderRadius: borderRadius!,
        child: content,
      );
    }

    return Semantics(
      label: semanticLabel ?? 'Ảnh minh họa bài tập',
      image: true,
      child: content,
    );
  }

  Widget _buildAssetOrPlaceholder(BuildContext context) {
    final cleanSlug = slug?.trim();
    if (cleanSlug != null && cleanSlug.isNotEmpty) {
      return Image.asset(
        'assets/exercises/$cleanSlug.webp',
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(context);
        },
      );
    }
    return _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: AppColors.placeholder,
      alignment: Alignment.center,
      child: Icon(
        Icons.fitness_center_rounded,
        size: (height != null && height! < 50) ? 22 : 36,
        color: AppColors.textSecondary.withValues(alpha: 0.7),
      ),
    );
  }
}
