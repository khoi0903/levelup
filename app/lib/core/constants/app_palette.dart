import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Bảng màu theo theme (sáng/tối). Widget lấy màu qua `context.colors.<tên>`
/// để tự đổi khi người dùng chuyển chế độ tối. `AppColors` giữ các hằng số
/// của bản sáng và bo góc.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.bgGradient1,
    required this.bgGradient2,
    required this.bgGradient3,
    required this.background,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary,
    required this.buttonFill,
    required this.onPrimary,
    required this.accentLink,
    required this.primaryDark,
    required this.primaryLight,
    required this.btnShadow,
    required this.progressTrack,
    required this.progressFill,
    required this.cardNormalBg,
    required this.cardNormalBorder,
    required this.cardNormalShadow,
    required this.cardSelectedBg,
    required this.cardSelectedBorder,
    required this.cardSelectedShadow,
    required this.radioUnselectedBg,
    required this.radioUnselectedBorder,
    required this.placeholder,
    required this.errorBg,
    required this.errorBorder,
    required this.errorText,
    required this.successBg,
    required this.successBorder,
    required this.successText,
    required this.infoBg,
    required this.infoBorder,
    required this.infoText,
    required this.infoAccent,
    required this.warningBg,
    required this.warningBorder,
    required this.warningText,
    required this.mutedBg,
  });

  final Brightness brightness;
  final Color bgGradient1;
  final Color bgGradient2;
  final Color bgGradient3;
  final Color background;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color primary;

  /// Nền nút chính (chữ trắng). Bản tối giữ #4B63E8 vì `primary` sáng hơn để làm chữ/biểu tượng.
  final Color buttonFill;

  /// Chữ trên nền `primary` của các widget Material (FilledButton, Switch...).
  final Color onPrimary;
  final Color accentLink;
  final Color primaryDark;
  final Color primaryLight;
  final Color btnShadow;
  final Color progressTrack;
  final Color progressFill;
  final Color cardNormalBg;
  final Color cardNormalBorder;
  final Color cardNormalShadow;
  final Color cardSelectedBg;
  final Color cardSelectedBorder;
  final Color cardSelectedShadow;
  final Color radioUnselectedBg;
  final Color radioUnselectedBorder;
  final Color placeholder;

  // Hộp trạng thái: lỗi, thành công, thông tin, cảnh báo, nền xám nhạt.
  final Color errorBg;
  final Color errorBorder;
  final Color errorText;
  final Color successBg;
  final Color successBorder;
  final Color successText;
  final Color infoBg;
  final Color infoBorder;
  final Color infoText;
  final Color infoAccent;
  final Color warningBg;
  final Color warningBorder;
  final Color warningText;
  final Color mutedBg;

  bool get isDark => brightness == Brightness.dark;

  // Tên cũ trong AppColors, giữ để code chuyển đổi đọc giống nhau.
  Color get accent => primary;
  Color get accentDark => primaryDark;
  Color get accentLight => primaryLight;
  Color get borderLight => border;

  LinearGradient get screenGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.38, 1.0],
        colors: [bgGradient1, bgGradient2, bgGradient3],
      );

  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    bgGradient1: AppColors.bgGradient1,
    bgGradient2: AppColors.bgGradient2,
    bgGradient3: AppColors.bgGradient3,
    background: AppColors.background,
    surface: AppColors.surface,
    border: AppColors.border,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    primary: AppColors.primary,
    buttonFill: AppColors.primary,
    onPrimary: Color(0xFFFFFFFF),
    accentLink: AppColors.accentLink,
    primaryDark: AppColors.primaryDark,
    primaryLight: AppColors.primaryLight,
    btnShadow: AppColors.btnShadow,
    progressTrack: AppColors.progressTrack,
    progressFill: AppColors.progressFill,
    cardNormalBg: AppColors.cardNormalBg,
    cardNormalBorder: AppColors.cardNormalBorder,
    cardNormalShadow: AppColors.cardNormalShadow,
    cardSelectedBg: AppColors.cardSelectedBg,
    cardSelectedBorder: AppColors.cardSelectedBorder,
    cardSelectedShadow: AppColors.cardSelectedShadow,
    radioUnselectedBg: AppColors.radioUnselectedBg,
    radioUnselectedBorder: AppColors.radioUnselectedBorder,
    placeholder: AppColors.placeholder,
    errorBg: Color(0xFFFEE2E2),
    errorBorder: Color(0xFFFCA5A5),
    errorText: Color(0xFF991B1B),
    successBg: Color(0xFFDCFCE7),
    successBorder: Color(0xFF86EFAC),
    successText: Color(0xFF166534),
    infoBg: Color(0xFFEFF6FF),
    infoBorder: Color(0xFFBFDBFE),
    infoText: Color(0xFF1E3A8A),
    infoAccent: Color(0xFF2563EB),
    warningBg: Color(0xFFFEF3C7),
    warningBorder: Color(0xFFFDE68A),
    warningText: Color(0xFF92400E),
    mutedBg: Color(0xFFF3F4F6),
  );

  // Bản tối dịu mắt, cùng tông xanh tím với bản sáng. Nút giữ #4B63E8
  // (chữ trắng 4.9:1); chữ chính 13:1, chữ phụ 7.5:1 trên thẻ; `primary`
  // sáng hơn (#7B8FF5) để chữ xanh đạt 4.5:1 cả trên nền chip đang chọn.
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    bgGradient1: Color(0xFF181F3D),
    bgGradient2: Color(0xFF12172F),
    bgGradient3: Color(0xFF10142A),
    background: Color(0xFF10142A),
    surface: Color(0xFF1A2140),
    border: Color(0xFF2C3560),
    textPrimary: Color(0xFFE8ECFF),
    textSecondary: Color(0xFFA9B3D9),
    primary: Color(0xFF7B8FF5),
    buttonFill: Color(0xFF4B63E8),
    onPrimary: Color(0xFF10142A),
    accentLink: Color(0xFF8EA0FF),
    primaryDark: Color(0xFF3B52D9),
    primaryLight: Color(0xFF232C58),
    btnShadow: Color(0x664B63E8),
    progressTrack: Color(0xFF2A3360),
    progressFill: Color(0xFF7B8FF5),
    cardNormalBg: Color(0xFF1A2140),
    cardNormalBorder: Color(0xFF2C3560),
    cardNormalShadow: Color(0x66000000),
    cardSelectedBg: Color(0xFF232C58),
    cardSelectedBorder: Color(0xFF7B8FF5),
    cardSelectedShadow: Color(0x474B63E8),
    radioUnselectedBg: Color(0xFF1A2140),
    radioUnselectedBorder: Color(0xFF4A5590),
    placeholder: Color(0xFF2A3360),
    errorBg: Color(0xFF3A1E2B),
    errorBorder: Color(0xFF6B2E3E),
    errorText: Color(0xFFFFB4B4),
    successBg: Color(0xFF16332A),
    successBorder: Color(0xFF2F6B4F),
    successText: Color(0xFFA7F3C4),
    infoBg: Color(0xFF1C2A4A),
    infoBorder: Color(0xFF2F4A7A),
    infoText: Color(0xFFBFD4FF),
    infoAccent: Color(0xFF7FA8FF),
    warningBg: Color(0xFF3A2E17),
    warningBorder: Color(0xFF6B5320),
    warningText: Color(0xFFFCD9A0),
    mutedBg: Color(0xFF222A4A),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppPaletteContext on BuildContext {
  /// Màu theo theme hiện tại (sáng/tối).
  AppPalette get colors =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
