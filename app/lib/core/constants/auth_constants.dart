/// Cấu hình và hằng số cho luồng xác thực (Authentication).
class AuthConstants {
  AuthConstants._();

  /// Web client ID dùng làm serverClientId cho Google Sign-In trên Firebase project `levelup-pro`.
  static const String googleServerClientId =
      '736710213113-phmlbn7bq8197euanht9ku912ckmrsos.apps.googleusercontent.com';

  /// Chế độ auth: 'dev' hoặc 'firebase'.
  /// Mặc định khi build Android/iOS là 'firebase'. Khi chạy với --dart-define=AUTH_MODE=dev là 'dev'.
  static const String authMode =
      String.fromEnvironment('AUTH_MODE', defaultValue: 'firebase');

  static bool get isDevMode => authMode == 'dev';

  /// DEV UID mặc định khi chạy dev mode
  static const String devUid =
      String.fromEnvironment('DEV_UID', defaultValue: 'dev-local');
}
