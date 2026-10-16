import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/health_connect_service.dart';
import '../../domain/models/health_connect_state.dart';

final healthConnectServiceProvider = Provider<HealthConnectService>((ref) {
  return HealthConnectService();
});

final healthConnectControllerProvider =
    StateNotifierProvider<HealthConnectController, HealthConnectState>((ref) {
  final service = ref.watch(healthConnectServiceProvider);
  return HealthConnectController(service);
});

class HealthConnectController extends StateNotifier<HealthConnectState> {
  final HealthConnectService _service;

  HealthConnectController(this._service) : super(const HealthConnectState()) {
    checkStatus();
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

  /// Làm mới dữ liệu hôm nay (bước chân, calo tiêu thụ)
  Future<void> refreshTodayData() async {
    try {
      final steps = await _service.getTodaySteps();
      final calories = await _service.getTodayCaloriesBurned();
      state = state.copyWith(
        data: HealthDataSummary(
          steps: steps,
          caloriesBurned: calories,
          lastUpdated: DateTime.now(),
        ),
      );
    } catch (e) {
      // Giữ nguyên dữ liệu cũ nếu fetch bị lỗi tạm thời
    }
  }

  /// Hướng dẫn tải Health Connect từ CH Play
  Future<void> installHealthConnect() async {
    await _service.installHealthConnect();
  }
}
