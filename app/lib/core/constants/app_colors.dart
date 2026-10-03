import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Nền màn hình (gradient chéo ~172°)
  static const Color bgGradient1 = Color(0xFFDCE4FF); // 0%
  static const Color bgGradient2 = Color(0xFFCBD6FD); // 35%
  static const Color bgGradient3 = Color(0xFFA8B8F8); // 70%
  static const Color bgGradient4 = Color(0xFF8CA0F2); // 100%

  static const LinearGradient screenGradient = LinearGradient(
    begin: Alignment(0.14, -1.0), // ~172°
    end: Alignment(-0.14, 1.0),
    stops: [0.0, 0.35, 0.70, 1.0],
    colors: [
      bgGradient1,
      bgGradient2,
      bgGradient3,
      bgGradient4,
    ],
  );

  // Chữ
  static const Color textPrimary = Color(0xFF171F45);
  static const Color textSecondary = Color(0xFF465381);
  static const Color textMuted = Color(0xFF56648E);

  // Màu nhấn (checkmark, nút chọn, link)
  static const Color accent = Color(0xFF7084E8);
  static const Color accentLink = Color(0xFF4B63E8);
  static const Color accentDark = Color(0xFF4B63E8);
  static const Color accentLight = Color(0xFFDCE4FF);
  static const Color primary = Color(0xFF7084E8);
  static const Color primaryDark = Color(0xFF4B63E8);
  static const Color primaryLight = Color(0xFFDCE4FF);
  static const Color placeholder = Color(0x66FFFFFF);

  // Thanh tiến độ: gradient #8CA0F2 → #7D93EC → #6D84E8, rãnh trắng 40%
  static const Color progressGradient1 = Color(0xFF8CA0F2);
  static const Color progressGradient2 = Color(0xFF7D93EC);
  static const Color progressGradient3 = Color(0xFF6D84E8);
  static const Color progressTrack = Color(0x66FFFFFF); // 40% white

  static const LinearGradient progressGradient = LinearGradient(
    colors: [progressGradient1, progressGradient2, progressGradient3],
  );

  // Nút chính
  static const Color btnGradientStart = Color(0xB8A2B2FF); // rgba(162,178,255,0.72)
  static const Color btnGradientEnd = Color(0xCC8799FA);   // rgba(135,153,250,0.80)
  static const Color btnBorder = Color(0xBFFFFFFF);        // rgba(255,255,255,0.75)
  static const Color btnShadow = Color(0x664E5DC9);        // rgba(78,93,201,0.40)

  static const LinearGradient primaryButtonGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [btnGradientStart, btnGradientEnd],
  );

  // Thẻ đang chọn (GlassCard selected)
  static const Color cardSelectedBg = Color(0xA6FFFFFF);          // trắng 65%
  static const Color cardSelectedBorder = Color(0xF2FFFFFF);      // trắng 95%
  static const Color cardSelectedOuterBorder = Color(0x738799FA); // rgba(135,153,250,0.45)
  static const Color cardSelectedShadow = Color(0x385C6BD6);      // rgba(92,107,214,0.22)

  // Thẻ thường (GlassCard normal)
  static const Color cardNormalBg = Color(0x0AFFFFFF);            // trắng 4%
  static const Color cardNormalBorder = Color(0xBFFFFFFF);        // trắng 75%
  static const Color cardNormalShadow = Color(0x244F5DAC);        // rgba(79,93,172,0.14)

  // Radio chưa chọn
  static const Color radioUnselectedBg = Color(0x33FFFFFF);       // trắng 20%
  static const Color radioUnselectedBorder = Color(0xCCC7D2FE);   // rgba(199,210,254,0.8)

  // Tiện ích & Nền mặc định
  static const Color background = Color(0xFFDCE4FF);
  static const Color surface = Color(0x66FFFFFF);
  static const Color border = Color(0xBFFFFFFF);
  static const Color borderLight = Color(0x66FFFFFF);

  // Bo góc constants
  static const double radiusCard = 24.0;
  static const double radiusButton = 16.0;
  static const double radiusPill = 9999.0;
}
