import 'package:flutter/material.dart';

import '../../../../core/api/api_exceptions.dart';
import '../../../../core/constants/app_palette.dart';
import '../../../../core/widgets/gradient_background.dart';

String nutritionError(Object error) {
  if (error is ApiException) {
    if (error.statusCode == 413 || error.code == 'IMAGE_TOO_LARGE') {
      return 'Ảnh quá lớn. Hãy chọn ảnh nhỏ hơn (tối đa 2 MB).';
    }
    if (error.statusCode == 415 || error.code == 'INVALID_IMAGE') {
      return 'Ảnh không hỗ trợ. Hãy chọn ảnh JPEG, PNG hoặc WebP.';
    }
    if (error.statusCode == 429 || error.code == 'PHOTO_LIMIT_REACHED') {
      return 'Đã hết lượt nhận diện hôm nay. Bạn vẫn có thể tìm món thủ công.';
    }
    if (error.statusCode == 503 || error.code == 'AI_UNAVAILABLE') {
      return 'AI chưa sẵn sàng. Hãy tìm món thủ công để tiếp tục.';
    }
    if (error.statusCode == 502) {
      return 'Chưa đọc được món trong ảnh. Thử lại hoặc tìm món thủ công.';
    }
    if (error.statusCode == 401) {
      return 'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại.';
    }
    if (error.isNetworkError) {
      return 'Không thể kết nối. Kiểm tra mạng và thử lại.';
    }
    if (error.isValidationError) {
      return 'Thông tin chưa hợp lệ. Kiểm tra lại khẩu phần hoặc số đo.';
    }
  }
  return 'Chưa thực hiện được. Hãy thử lại.';
}

class FeatureScaffold extends StatelessWidget {
  const FeatureScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.background,
    appBar: AppBar(
      title: Text(title),
      backgroundColor: context.colors.background,
      actions: actions,
    ),
    body: GradientBackground(
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class FeatureError extends StatelessWidget {
  const FeatureError({super.key, required this.error, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(nutritionError(error), textAlign: TextAlign.center),
        TextButton(onPressed: retry, child: const Text('Thử lại')),
      ],
    ),
  );
}

class MacroRow extends StatelessWidget {
  const MacroRow({
    super.key,
    required this.label,
    required this.value,
    this.target,
  });
  final String label;
  final double value;
  final double? target;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${value.round()}${target == null ? '' : '/${target!.round()}'} g',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: target == null || target! <= 0
              ? 0
              : (value / target!).clamp(0, 1),
          color: context.colors.progressFill,
          backgroundColor: context.colors.progressTrack,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    ),
  );
}
