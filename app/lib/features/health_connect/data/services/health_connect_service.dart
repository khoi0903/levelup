import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

class HealthConnectService {
  final Health _health = Health();

  static const List<HealthDataType> requiredTypes = [
    HealthDataType.STEPS,
    // Calo vận động (không gồm calo cơ thể tự đốt khi nghỉ, khoảng 1.500 kcal/ngày)
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  static const List<HealthDataAccess> accessPermissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  /// Khởi tạo và cấu hình Health Connect
  Future<void> configure() async {
    try {
      await _health.configure();
    } catch (e) {
      debugPrint('Health.configure error: $e');
    }
  }

  /// Kiểm tra xem thiết bị Android có hỗ trợ hoặc đã cài Health Connect chưa
  Future<bool> isHealthConnectAvailable() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      try {
        final status = await _health.getHealthConnectSdkStatus();
        return status == HealthConnectSdkStatus.sdkAvailable;
      } catch (e) {
        debugPrint('getHealthConnectSdkStatus error: $e');
        return false;
      }
    } else if (Platform.isIOS) {
      return true;
    }
    return false;
  }

  /// Chuyển hướng người dùng đến Play Store để cài Health Connect nếu chưa có (Android < 14)
  Future<void> installHealthConnect() async {
    if (Platform.isAndroid) {
      try {
        await _health.installHealthConnect();
      } catch (e) {
        debugPrint('installHealthConnect error: $e');
      }
    }
  }

  /// Kiểm tra xem app đã có quyền truy cập các dữ liệu sức khoẻ chưa
  Future<bool> hasPermissions() async {
    if (kIsWeb) return false;
    try {
      final hasPerm = await _health.hasPermissions(
        requiredTypes,
        permissions: accessPermissions,
      );
      return hasPerm ?? false;
    } catch (e) {
      debugPrint('Health hasPermissions error: $e');
      return false;
    }
  }

  /// Yêu cầu cấp quyền từ người dùng (sẽ mở popup xin quyền của Health Connect)
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    try {
      await configure();
      final granted = await _health.requestAuthorization(
        requiredTypes,
        permissions: accessPermissions,
      );
      return granted;
    } catch (e) {
      debugPrint('Health requestAuthorization error: $e');
      return false;
    }
  }

  /// Lấy tổng số bước chân trong ngày hôm nay
  Future<int> getTodaySteps() async {
    if (kIsWeb) return 0;
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(midnight, now);
      return steps ?? 0;
    } catch (e) {
      debugPrint('Health getTodaySteps error: $e');
      return 0;
    }
  }

  /// Lấy tổng calo tiêu hao trong ngày hôm nay
  Future<double> getTodayCaloriesBurned() async {
    if (kIsWeb) return 0.0;
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: midnight,
        endTime: now,
      );
      double totalCalories = 0.0;
      for (final data in healthData) {
        final val = data.value;
        if (val is NumericHealthValue) {
          totalCalories += val.numericValue.toDouble();
        }
      }
      return totalCalories;
    } catch (e) {
      debugPrint('Health getTodayCaloriesBurned error: $e');
      return 0.0;
    }
  }
}
