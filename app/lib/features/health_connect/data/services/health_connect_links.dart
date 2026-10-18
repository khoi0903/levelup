import 'package:shared_preferences/shared_preferences.dart';

/// Quyền Health Connect gắn với điện thoại, không gắn với tài khoản. Lưu tài khoản nào đã tự bấm "Kết nối"
/// trên máy này để tài khoản khác đăng nhập cùng máy không đọc (và gửi lên server) số bước của người kia.
class HealthConnectLinks {
  static const _key = 'health_connect_linked_uids';

  Future<bool> isLinked(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).contains(uid);
  }

  Future<void> link(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final uids = prefs.getStringList(_key) ?? const [];
    if (!uids.contains(uid)) await prefs.setStringList(_key, [...uids, uid]);
  }
}
