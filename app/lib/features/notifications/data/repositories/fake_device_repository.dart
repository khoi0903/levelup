import '../../domain/repositories/device_repository.dart';

class RegisteredDeviceRecord {
  final String token;
  final String platform;

  const RegisteredDeviceRecord({required this.token, required this.platform});
}

class FakeDeviceRepository implements DeviceRepository {
  final List<RegisteredDeviceRecord> registeredDevices = [];
  bool registerCalled = false;
  Exception? errorToThrow;

  @override
  Future<void> registerDevice({
    required String token,
    required String platform,
  }) async {
    registerCalled = true;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    registeredDevices.add(
      RegisteredDeviceRecord(token: token, platform: platform),
    );
  }

  void clear() {
    registeredDevices.clear();
    registerCalled = false;
    errorToThrow = null;
  }
}
