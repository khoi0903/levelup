import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../data/repositories/api_user_repository.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';
import '../../domain/models/me_response.dart';
import '../../domain/models/settings_request.dart';
import '../../domain/repositories/user_repository.dart';
import '../../../workout/presentation/controllers/workout_controller.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiUserRepository(client);
});

final currentUserProvider = StateProvider<MeResponse?>((ref) => null);

final userStatusFutureProvider = FutureProvider.autoDispose<MeResponse>((
  ref,
) async {
  final repo = ref.watch(userRepositoryProvider);
  final me = await repo.getMe();
  ref.read(currentUserProvider.notifier).state = me;

  // Bật push và đã có quyền thì đăng ký token. Không chờ: lấy token FCM có thể chậm hoặc treo
  // (máy chặn dịch vụ Google), không được giữ người dùng ở màn chờ. Lỗi chỉ ghi log.
  if (me.settings.notifications.pushEnabled) {
    unawaited(
      ref.read(notificationCoordinatorProvider).registerDeviceTokenIfEligible(),
    );
  }

  return me;
});

class SettingsState {
  final bool isSaving;
  final String? successMessage;
  final dynamic error;

  const SettingsState({this.isSaving = false, this.successMessage, this.error});

  SettingsState copyWith({
    bool? isSaving,
    String? successMessage,
    dynamic error,
    bool clearSuccess = false,
    bool clearError = false,
  }) {
    return SettingsState(
      isSaving: isSaving ?? this.isSaving,
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final UserRepository _repository;
  final Ref _ref;
  Future<void>? _runningFuture;

  SettingsNotifier(this._repository, this._ref) : super(const SettingsState());

  /// PATCH /me: gửi các trường thay đổi, cập nhật provider GET /me.
  Future<bool> saveSettings({
    String? displayName,
    String? timezone,
    String? coachStyle,
    String? goal,
    int? sessionMinutes,
    List<UserAvailabilitySlot>? availability,
    NotificationsUpdate? notifications,
    SharingUpdate? sharing,
    String? location,
    List<String>? equipment,
  }) async {
    return patchSettings(
      SettingsRequest(
        displayName: displayName,
        timezone: timezone,
        coachStyle: coachStyle,
        goal: goal,
        sessionMinutes: sessionMinutes,
        availability: availability,
        notifications: notifications,
        sharing: sharing,
        location: location,
        equipment: equipment,
      ),
    );
  }

  /// Gửi PATCH /me tuần tự (không gửi chồng, giá trị cuối cùng thắng).
  Future<bool> patchSettings(SettingsRequest request) async {
    final prev = _runningFuture;
    final completer = Completer<void>();
    _runningFuture = completer.future;

    if (prev != null) {
      try {
        await prev;
      } catch (_) {}
    }

    state = state.copyWith(
      isSaving: true,
      clearSuccess: true,
      clearError: true,
    );

    try {
      final updated = await _repository.updateSettings(request);
      _ref.read(currentUserProvider.notifier).state = updated;
      _ref.invalidate(userStatusFutureProvider);
      if (request.location != null || request.equipment != null) {
        _ref.invalidate(exercisesFutureProvider);
      }
      state = state.copyWith(
        isSaving: false,
        successMessage: 'Đã lưu',
        clearError: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e);
      return false;
    } finally {
      completer.complete();
    }
  }

  void clearSuccess() => state = state.copyWith(clearSuccess: true);

  Future<void> logout() async {
    await appSignOutRef(_ref);
  }
}

final settingsControllerProvider =
    StateNotifierProvider.autoDispose<SettingsNotifier, SettingsState>((ref) {
      final repo = ref.watch(userRepositoryProvider);
      return SettingsNotifier(repo, ref);
    });
