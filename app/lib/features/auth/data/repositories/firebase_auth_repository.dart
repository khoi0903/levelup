import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/constants/auth_constants.dart';
import '../../domain/models/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  bool _googleInitialized = false;

  FirebaseAuthRepository({
    fb.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  Future<void> _ensureGoogleInitialized() async {
    if (!_googleInitialized) {
      try {
        await _googleSignIn.initialize(
          serverClientId: AuthConstants.googleServerClientId,
        );
      } catch (_) {}
      _googleInitialized = true;
    }
  }

  AuthUser _mapFirebaseUser(fb.User user) {
    return AuthUser(
      id: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }

  @override
  Stream<AuthUser?> get authStateChanges =>
      _firebaseAuth.authStateChanges().map((u) => u != null ? _mapFirebaseUser(u) : null);

  @override
  AuthUser? get currentUser {
    final user = _firebaseAuth.currentUser;
    return user != null ? _mapFirebaseUser(user) : null;
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return await user.getIdToken(forceRefresh);
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();
      final googleAccount = await _googleSignIn.authenticate();
      final idToken = googleAccount.authentication.idToken;

      final credential = fb.GoogleAuthProvider.credential(
        idToken: idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw Exception('Không lấy được thông tin tài khoản sau khi đăng nhập.');
      }
      return _mapFirebaseUser(user);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw Exception('Đã hủy đăng nhập Google.');
      }
      debugPrint('[auth] Google sign-in lỗi: ${e.code.name} ${e.description}');
      throw Exception('Đăng nhập Google không thành công. Vui lòng thử lại.');
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(mapFirebaseAuthError(e));
    } catch (e) {
      if (e.toString().contains('Đã hủy đăng nhập')) {
        rethrow;
      }
      debugPrint('[auth] Google sign-in lỗi: $e');
      throw Exception('Đăng nhập Google không thành công. Vui lòng thử lại.');
    }
  }

  @override
  Future<AuthUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = userCredential.user;
      if (user == null) {
        throw Exception('Không tìm thấy người dùng.');
      }
      return _mapFirebaseUser(user);
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(mapFirebaseAuthError(e));
    }
  }

  @override
  Future<AuthUser> signUpWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = userCredential.user;
      if (user == null) {
        throw Exception('Không tạo được tài khoản.');
      }
      if (displayName != null && displayName.trim().isNotEmpty) {
        await user.updateDisplayName(displayName.trim());
      }
      return _mapFirebaseUser(user);
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(mapFirebaseAuthError(e));
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(mapFirebaseAuthError(e));
    }
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Ánh xạ mã lỗi FirebaseAuthException sang tiếng Việt thân thiện
  static String mapFirebaseAuthError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Tài khoản không tồn tại. Vui lòng kiểm tra lại email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không chính xác.';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng bởi một tài khoản khác.';
      case 'invalid-email':
        return 'Địa chỉ email không đúng định dạng.';
      case 'weak-password':
        return 'Mật khẩu quá yếu. Vui lòng đặt mật khẩu ít nhất 6 ký tự.';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng. Vui lòng kiểm tra đường truyền và thử lại.';
      case 'too-many-requests':
        return 'Quá nhiều lần thử không thành công. Vui lòng thử lại sau ít phút.';
      case 'user-disabled':
        return 'Tài khoản này đã bị khóa.';
      case 'operation-not-allowed':
        return 'Phương thức đăng nhập này chưa được kích hoạt.';
      default:
        debugPrint('[auth] Firebase lỗi: ${e.code} ${e.message}');
        return 'Đăng nhập không thành công. Vui lòng thử lại sau.';
    }
  }
}
