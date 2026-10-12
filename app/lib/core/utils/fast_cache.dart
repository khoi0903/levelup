import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/onboarding/domain/models/plan_models.dart';
import '../../features/users/domain/models/me_response.dart';

/// Lưu và lấy bản JSON cuối cùng của GET /me và GET /plans/current
/// trong SharedPreferences theo uid để mở app tức thì.
class FastCache {
  static SharedPreferences? _prefsInstance;
  static final Map<String, String> _memFallback = {};

  static const String _mePrefix = 'fast_cache_me_';
  static const String _planPrefix = 'fast_cache_plan_';

  static void setMockPrefs(SharedPreferences? prefs) {
    _prefsInstance = prefs;
  }

  static Future<SharedPreferences?> _getPrefs() async {
    if (_prefsInstance != null) return _prefsInstance;
    try {
      _prefsInstance = await SharedPreferences.getInstance()
          .timeout(const Duration(milliseconds: 50));
      return _prefsInstance;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveMe(String uid, MeResponse me) async {
    final jsonStr = jsonEncode(me.toJson());
    _memFallback['$_mePrefix$uid'] = jsonStr;
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setString('$_mePrefix$uid', jsonStr);
      }
    } catch (_) {}
  }

  static Future<MeResponse?> getMe(String uid) async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs != null
          ? prefs.getString('$_mePrefix$uid')
          : _memFallback['$_mePrefix$uid'];
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return MeResponse.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> savePlan(String uid, PlanView plan) async {
    final jsonStr = jsonEncode(plan.toJson());
    _memFallback['$_planPrefix$uid'] = jsonStr;
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setString('$_planPrefix$uid', jsonStr);
      }
    } catch (_) {}
  }

  static Future<PlanView?> getPlan(String uid) async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs != null
          ? prefs.getString('$_planPrefix$uid')
          : _memFallback['$_planPrefix$uid'];
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return PlanView.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearAll() async {
    _memFallback.clear();
    try {
      final prefs = await _getPrefs();
      if (prefs != null) {
        final keys = prefs
            .getKeys()
            .where((k) => k.startsWith(_mePrefix) || k.startsWith(_planPrefix))
            .toList();
        for (final key in keys) {
          await prefs.remove(key);
        }
      }
    } catch (_) {}
  }
}
