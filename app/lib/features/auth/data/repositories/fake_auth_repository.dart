import 'dart:async';
import '../../domain/models/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  AuthUser? _currentUser;
  final _authController = StreamController<AuthUser?>.broadcast();
  Exception? errorToThrow;
  bool signOutCalled = false;
  String? lastResetEmailSent;

  FakeAuthRepository({
    AuthUser? initialUser,
    this.errorToThrow,
  }) : _currentUser = initialUser;

  @override
  Stream<AuthUser?> get authStateChanges => _authController.stream;

  @override
  AuthUser? get currentUser => _currentUser;

  void setCurrentUser(AuthUser? user) {
    _currentUser = user;
    _authController.add(user);
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (_currentUser == null) return null;
    return 'dev-${_currentUser!.id}';
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    if (errorToThrow != null) throw errorToThrow!;
    final user = const AuthUser(
      id: 'google-user-id',
      email: 'user@gmail.com',
      displayName: 'Google User',
    );
    setCurrentUser(user);
    return user;
  }

  @override
  Future<AuthUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    if (password == 'wrong_password') {
      throw Exception('Email hoặc mật khẩu không chính xác.');
    }
    final user = AuthUser(
      id: 'email-user-id',
      email: email,
      displayName: email.split('@').first,
    );
    setCurrentUser(user);
    return user;
  }

  @override
  Future<AuthUser> signUpWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    if (email == 'existing@levelup.vn') {
      throw Exception('Email này đã được sử dụng bởi một tài khoản khác.');
    }
    final user = AuthUser(
      id: 'new-user-id',
      email: email,
      displayName: displayName ?? email.split('@').first,
    );
    setCurrentUser(user);
    return user;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (errorToThrow != null) throw errorToThrow!;
    lastResetEmailSent = email;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    setCurrentUser(null);
  }

  void dispose() {
    _authController.close();
  }
}
