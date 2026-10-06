import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/users/presentation/controllers/user_controller.dart';
import 'voice_coach.dart';
import 'voice_models.dart';

const String _prefVoiceEnabled = 'voice_coach_enabled';
const String _prefVoiceStyle = 'voice_coach_style';
const String _prefVoiceSpeed = 'voice_coach_speed';
const String _prefVoiceStartTip = 'voice_coach_start_tip';

class VoiceSettingsNotifier extends StateNotifier<VoiceSettings> {
  VoiceSettingsNotifier() : super(const VoiceSettings()) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_prefVoiceEnabled) ?? true;
      final style = prefs.getString(_prefVoiceStyle) ?? 'coach';
      final speedStr = prefs.getString(_prefVoiceSpeed) ?? 'normal';
      final speed = VoiceSpeed.fromString(speedStr);
      final readStartTip = prefs.getBool(_prefVoiceStartTip) ?? true;

      state = VoiceSettings(
        enabled: enabled,
        selectedStyleId: style,
        speed: speed,
        mutedTemporarily: false,
        readStartTip: readStartTip,
      );
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefVoiceEnabled, enabled);
    } catch (_) {}
  }

  Future<void> setStyle(String styleId) async {
    state = state.copyWith(selectedStyleId: styleId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefVoiceStyle, styleId);
    } catch (_) {}
  }

  Future<void> setSpeed(VoiceSpeed speed) async {
    state = state.copyWith(speed: speed);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefVoiceSpeed, speed.name);
    } catch (_) {}
  }

  Future<void> setReadStartTip(bool enabled) async {
    state = state.copyWith(readStartTip: enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefVoiceStartTip, enabled);
    } catch (_) {}
  }

  void toggleMuteTemporarily() {
    state = state.copyWith(mutedTemporarily: !state.mutedTemporarily);
  }

  void setMutedTemporarily(bool muted) {
    state = state.copyWith(mutedTemporarily: muted);
  }
}

final voiceSettingsProvider =
    StateNotifierProvider<VoiceSettingsNotifier, VoiceSettings>((ref) {
  return VoiceSettingsNotifier();
});

/// VoiceCoach provider - có thể override bằng FakeVoiceCoach trong tests.
///
/// Tạo MỘT lần cho cả app. Không ref.watch: trước đây watch userStatusFutureProvider (autoDispose, tải lại sau
/// mỗi buổi tập / lưu cài đặt, tự hủy khi rời Trang chủ) và voiceSettingsProvider (đổi khi bấm nút loa) làm
/// provider dựng lại → coach cũ bị dispose (dừng ngang câu) và tạo engine TTS mới giữa buổi tập.
/// Giờ chỉ nghe thay đổi rồi cập nhật thông số cho coach đang chạy.
final voiceCoachProvider = Provider<VoiceCoach>((ref) {
  final coach = FlutterTtsVoiceCoach();
  unawaited(coach.init());

  void apply() {
    final coachStyle =
        ref.read(currentUserProvider)?.profile?.coachStyle ?? 'supportive';
    coach.updateSettings(ref.read(voiceSettingsProvider),
        effectiveCoachStyle: coachStyle);
  }

  apply();
  ref.listen(voiceSettingsProvider, (_, _) => apply());
  ref.listen(currentUserProvider, (_, _) => apply());

  ref.onDispose(() {
    coach.dispose();
  });

  return coach;
});
