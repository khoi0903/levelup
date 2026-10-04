import 'package:flutter/material.dart';

/// Banner thông báo khi mất kết nối mạng hoặc server không phản hồi.
class OfflineBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const OfflineBanner({
    super.key,
    this.message = 'Không kết nối được máy chủ. Đang xem dữ liệu ngoại tuyến.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5), // Soft warm amber
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFFD599),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 20,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: const Text(
                'Thử lại',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD97706),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
