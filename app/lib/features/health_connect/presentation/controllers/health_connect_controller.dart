import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../activity/data/repositories/api_activity_repository.dart';
import '../../../activity/domain/models/activity_models.dart';
import '../../../activity/domain/repositories/activity_repository.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../../data/services/health_connect_service.dart';
import '../../domain/models/health_connect_state.dart';

final healthConnectServiceProvider = Provider<HealthConnectService>((ref) {
  return HealthConnectService();
});

final healthConnectControllerProvider =
    StateNotifierProvider<HealthConnectController, HealthConnectState>((ref) {
  final service = ref.watch(healthConnectServiceProvider);
  return HealthConnectController(
    service,
    ref: ref,
  );
});

class HealthConnectController extends StateNotifier<HealthConnectState> {
  final HealthConnectService _service;
  final Ref? ref;
  final ActivityRepository? activityRepository;
  final Duration syncInterval;
  final DateTime Function() clock;
  final bool Function()? isPlatformSupportedOverride;

  DateTime? _lastSyncTime;
  int? _lastSentSteps;
  int? _lastSentActiveKcal;
  String? _lastSentLocalDate;

  HealthConnectController(
    this._service, {
    this.ref,
    this.activityRepository,
    this.syncInterval = const Duration(minutes: 15),
    DateTime Function()? clock,
    this.isPlatformSupportedOverride,
  })  : clock = clock ?? DateTime.now,
        super(const HealthConnectState()) {
    checkStatus();
  }

  ActivityRepository? get _effectiveActivityRepo {
    if (activityRepository != null) return activityRepository;
    if (ref != null) {
      try {
        return ref!.read(activityRepositoryProvider);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  bool _isPlatformSupported() {
    if (isPlatformSupportedOverride != null) {
      return isPlatformSupportedOverride!();
    }
    if (kIsWeb) return false;
    if (Platform.isIOS) return false;
    return true;
  }

  /// Kiểm tra trạng thái kết nối Health Connect
  Future<void> checkStatus() async {
    final available = await _service.isHealthConnectAvailable();
    if (!available) {
      state = state.copyWith(status: HealthConnectStatus.needsInstall);
      return;
    }

    final hasPerm = await _service.hasPermissions();
    if (hasPerm) {
      state = state.copyWith(status: HealthConnectStatus.authorized);
      await refreshTodayData();
    } else {
      state = state.copyWith(status: HealthConnectStatus.notAuthorized);
    }
  }

  /// Yêu cầu kết nối và xin cấp quyền từ Health Connect
  Future<bool> connect() async {
    state = state.copyWith(status: HealthConnectStatus.loading);
    try {
      final granted = await _service.requestPermissions();
      if (granted) {
        state = state.copyWith(status: HealthConnectStatus.authorized);
        await refreshTodayData();
        return true;
      } else {
        // Kiểm tra lại vì trên một số phiên bản requestAuthorization có thể trả về false nhưng người dùng đã cấp quyền một phần
        final hasPerm = await _service.hasPermissions();
        if (hasPerm) {
          state = state.copyWith(status: HealthConnectStatus.authorized);
          await refreshTodayData();
          return true;
        }
        state = state.copyWith(status: HealthConnectStatus.notAuthorized);
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: HealthConnectStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Làm mới dữ liệu hôm nay (bước chân, calo tiêu thụ) và đồng bộ lên server nếu đã cấp quyền
  Future<void> refreshTodayData() async {
    try {
      final steps = await _service.getTodaySteps();
      final calories = await _service.getTodayCaloriesBurned();
      state = state.copyWith(
        data: HealthDataSummary(
          steps: steps,
          caloriesBurned: calories,
          lastUpdated: clock(),
        ),
      );
      if (state.isAuthorized) {
        await _maybeSyncActivity(steps, calories.round());
      }
    } catch (e) {
      // Giữ nguyên dữ liệu cũ nếu fetch bị lỗi tạm thời
    }
  }

  /// Đồng bộ dữ liệu vận động lên máy chủ:
  /// - Tối đa 1 lần / 15 phút
  /// - Chỉ gửi khi số liệu tăng so với lần gửi trước
  /// - localDate = /me.localDate nếu trùng ngày trên điện thoại, ngược lại dùng ngày điện thoại
  /// - Bỏ qua im lặng nếu lỗi mạng
  /// - Không gửi gì khi chưa kết nối Health Connect / web / iOS
  Future<void> _maybeSyncActivity(int steps, int activeKcal) async {
    if (!_isPlatformSupported()) return;
    if (!state.isAuthorized) return;
    final repo = _effectiveActivityRepo;
    if (repo == null) return;

    final now = clock();
    final phoneLocalDate =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final me = ref?.read(userStatusFutureProvider).valueOrNull;
    final serverLocalDate = me?.localDate;
    final effectiveLocalDate =
        (serverLocalDate != null && serverLocalDate == phoneLocalDate)
            ? serverLocalDate
            : phoneLocalDate;

    // Reset bộ đếm nếu sang ngày mới
    if (_lastSentLocalDate != null && _lastSentLocalDate != effectiveLocalDate) {
      _lastSentSteps = null;
      _lastSentActiveKcal = null;
      _lastSyncTime = null;
    }

    // Tối đa 1 lần / 15 phút
    if (_lastSyncTime != null && now.difference(_lastSyncTime!) < syncInterval) {
      return;
    }

    // Chỉ gửi khi số liệu tăng so với lần gửi trước
    final hasIncreased = (_lastSentSteps == null && _lastSentActiveKcal == null)
        ? (steps > 0 || activeKcal > 0)
        : (steps > (_lastSentSteps ?? 0) || activeKcal > (_lastSentActiveKcal ?? 0));

    if (!hasIncreased) {
      return;
    }

    final safeSteps = steps.clamp(0, 200000);
    final safeActiveKcal = activeKcal.clamp(0, 10000);

    try {
      await repo.syncTodayActivity(
        ActivitySyncRequest(
          localDate: effectiveLocalDate,
          steps: safeSteps,
          activeKcal: safeActiveKcal,
        ),
      );
      _lastSyncTime = now;
      _lastSentSteps = safeSteps;
      _lastSentActiveKcal = safeActiveKcal;
      _lastSentLocalDate = effectiveLocalDate;
    } catch (_) {
      // Lỗi mạng: bỏ qua im lặng, không SnackBar
    }
  }

  /// Hướng dẫn tải Health Connect từ CH Play
  Future<void> installHealthConnect() async {
    await _service.installHealthConnect();
  }
}

