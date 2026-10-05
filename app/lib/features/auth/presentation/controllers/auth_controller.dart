import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/auth_constants.dart';
import '../../../home/presentation/controllers/home_controller.dart';
import '../../../notifications/domain/services/push_service.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';
import '../../../onboarding/presentation/controllers/onboarding_controller.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../../../workout/presentation/controllers/workout_controller.dart';
import '../../data/repositories/fake_auth_repository.dart';
import '../../data/repositories/firebase_auth_repository.dart';
import '../../domain/models/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (AuthConstants.isDevMode) {
    return FakeAuthRepository(
      initialUser: const AuthUser(
        id: AuthConstants.devUid,
        email: '${AuthConstants.devUid}@levelup.vn',
        displayName: 'Dev User',
      ),
    );
  }
  return FirebaseAuthRepository();
});

final authStateChangesProvider = StreamProvider<AuthUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final AuthUser? user;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.user,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    AuthUser? user,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final PushService? _pushService;
  final Ref? _ref;

  AuthNotifier(this._repository, [this._pushService, this._ref])
    : super(AuthState(user: _repository.currentUser));

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final user = await _repository.signInWithGoogle();
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } catch (e) {
      final msg = _cleanErrorMessage(e);
      if (msg.contains('Đã hủy đăng nhập')) {
        state = state.copyWith(isLoading: false);
        return false;
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<bool> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Vui lòng nhập đầy đủ email và mật khẩu.',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final user = await _repository.signInWithEmailPassword(
        email: email,
        password: password,
      );
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _cleanErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> signUpWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Vui lòng nhập đầy đủ email và mật khẩu.',
      );
      return false;
    }

    if (password.length < 6) {
      state = state.copyWith(errorMessage: 'Mật khẩu phải có ít nhất 6 ký tự.');
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final user = await _repository.signUpWithEmailPassword(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _cleanErrorMessage(e),
      );
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    if (email.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'Vui lòng nhập email để đặt lại mật khẩu.',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );
    try {
      await _repository.sendPasswordResetEmail(email);
      state = state.copyWith(
        isLoading: false,
        successMessage:
            'Đã gửi email khôi phục mật khẩu. Vui lòng kiểm tra hộp thư.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _cleanErrorMessage(e),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    if (_ref != null) {
      await appSignOutRef(_ref);
    } else {
      if (_pushService != null) {
        try {
          await _pushService.deleteToken();
        } catch (e) {
          debugPrint('AuthNotifier deleteToken error: $e');
        }
      }
      await _repository.signOut();
    }
    if (mounted) {
      state = const AuthState();
    }
  }

  String _cleanErrorMessage(dynamic e) {
    var str = e.toString();
    if (str.startsWith('Exception: ')) {
      str = str.substring('Exception: '.length);
    }
    return str;
  }
}

Future<void> appSignOut(WidgetRef ref) async {
  await _performSignOutCore(
    read: ref.read,
    invalidate: ref.invalidate,
  );
}

Future<void> appSignOutRef(Ref ref) async {
  await _performSignOutCore(
    read: ref.read,
    invalidate: ref.invalidate,
  );
}

Future<void> appSignOutContainer(ProviderContainer container) async {
  await _performSignOutCore(
    read: container.read,
    invalidate: container.invalidate,
  );
}

Future<void> _performSignOutCore({
  required T Function<T>(ProviderListenable<T>) read,
  required void Function(ProviderOrFamily) invalidate,
}) async {
  try {
    await read(pushServiceProvider).deleteToken();
  } catch (e) {
    debugPrint('deleteToken error on sign out: $e');
  }

  try {
    await read(workoutDraftRepositoryProvider).deleteAllDrafts();
  } catch (e) {
    debugPrint('deleteAllDrafts error on sign out: $e');
  }

  try {
    read(activeWorkoutProvider.notifier).clear();
  } catch (_) {}

  try {
    read(onboardingControllerProvider.notifier).reset();
  } catch (_) {}

  invalidate(onboardingControllerProvider);
  invalidate(onboardingResponseProvider);
  invalidate(weeklyPlanFutureProvider);
  invalidate(userStatusFutureProvider);
  invalidate(homePlanProvider);
  invalidate(activeWorkoutDraftProvider);
  try {
    read(currentUserProvider.notifier).state = null;
  } catch (_) {}

  await read(authRepositoryProvider).signOut();
}

final authControllerProvider =
    StateNotifierProvider.autoDispose<AuthNotifier, AuthState>((ref) {
      final repo = ref.watch(authRepositoryProvider);
      final pushService = ref.watch(pushServiceProvider);
      return AuthNotifier(repo, pushService, ref);
    });
