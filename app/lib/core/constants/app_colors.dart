import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Nền màn hình (dọc: #E4E9FF 0% → #F4F6FF 38% → #F7F8FC 100%)
  static const Color bgGradient1 = Color(0xFFE4E9FF);
  static const Color bgGradient2 = Color(0xFFF4F6FF);
  static const Color bgGradient3 = Color(0xFFF7F8FC);

  static const LinearGradient screenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.38, 1.0],
    colors: [
      bgGradient1,
      bgGradient2,
      bgGradient3,
    ],
  );

  // Nền & bề mặt
  static const Color background = Color(0xFFF4F6FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFDDE3F7);
  static const Color borderLight = Color(0xFFDDE3F7);

  // Chữ
  static const Color textPrimary = Color(0xFF171F45);
  static const Color textSecondary = Color(0xFF3A4570);

  // Màu nhấn (primary / accent)
  static const Color primary = Color(0xFF4B63E8);
  static const Color accent = Color(0xFF4B63E8);
  static const Color accentLink = Color(0xFF3B52D9);
  static const Color primaryDark = Color(0xFF3B52D9);
  static const Color accentDark = Color(0xFF3B52D9);
  static const Color primaryLight = Color(0xFFF5F7FF);
  static const Color accentLight = Color(0xFFF5F7FF);

  // Nút chính: màu đặc #4B63E8, không viền, chữ trắng, bóng rgba(75,99,232,0.55) blur 20 offset y 8
  static const Color btnShadow = Color(0x8C4B63E8); // rgba(75, 99, 232, 0.55)

  // Thanh tiến độ: màu đặc #4B63E8, rãnh #E1E6F8
  static const Color progressTrack = Color(0xFFE1E6F8);
  static const Color progressFill = Color(0xFF4B63E8);

  // Thẻ thường: trắng đặc #FFFFFF, viền #DDE3F7 1px, bóng rgba(40,53,105,0.12) blur 14
  static const Color cardNormalBg = Color(0xFFFFFFFF);
  static const Color cardNormalBorder = Color(0xFFDDE3F7);
  static const Color cardNormalShadow = Color(0x1F283569); // rgba(40, 53, 105, 0.12)

  // Thẻ đang chọn: nền #F5F7FF, viền #4B63E8 1.5px, bóng rgba(75,99,232,0.28) blur 18
  static const Color cardSelectedBg = Color(0xFFF5F7FF);
  static const Color cardSelectedBorder = Color(0xFF4B63E8);
  static const Color cardSelectedShadow = Color(0x474B63E8); // rgba(75, 99, 232, 0.28)

  // Radio chưa chọn: nền trắng, viền #C4CCEB 2px
  static const Color radioUnselectedBg = Color(0xFFFFFFFF);
  static const Color radioUnselectedBorder = Color(0xFFC4CCEB);

  // Placeholder
  static const Color placeholder = Color(0xFFE1E6F8);

  // Bo góc constants
  static const double radiusCard = 24.0;
  static const double radiusButton = 16.0;
  static const double radiusPill = 9999.0;
}
