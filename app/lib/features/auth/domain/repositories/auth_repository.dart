import '../models/auth_user.dart';

abstract class AuthRepository {
  /// Stream theo dõi trạng thái đăng nhập của người dùng.
  Stream<AuthUser?> get authStateChanges;

  /// Người dùng hiện tại, null nếu chưa đăng nhập.
  AuthUser? get currentUser;

  /// Lấy ID Token (JWT) để gửi header Authorization tới backend.
  Future<String?> getIdToken({bool forceRefresh = false});

  /// Đăng nhập bằng Google.
  Future<AuthUser> signInWithGoogle();

  /// Đăng nhập bằng Email và Mật khẩu.
  Future<AuthUser> signInWithEmailPassword({
    required String email,
    required String password,
  });

  /// Đăng ký tài khoản mới bằng Email và Mật khẩu.
  Future<AuthUser> signUpWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  });

  /// Gửi email đặt lại mật khẩu.
  Future<void> sendPasswordResetEmail(String email);

  /// Đăng xuất khỏi hệ thống (Firebase + Google Sign-In).
  Future<void> signOut();
}
