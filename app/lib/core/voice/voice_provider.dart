import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/users/presentation/controllers/user_controller.dart';
import 'voice_coach.dart';
import 'voice_models.dart';

const String _prefVoiceEnabled = 'voice_coach_enabled';
const String _prefVoiceStyle = 'voice_coach_style';
const String _prefVoiceSpeed = 'voice_coach_speed';

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

      state = VoiceSettings(
        enabled: enabled,
        selectedStyleId: style,
        speed: speed,
        mutedTemporarily: false,
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
final voiceCoachProvider = Provider<VoiceCoach>((ref) {
  final coach = FlutterTtsVoiceCoach();
  unawaited(coach.init());

  final settings = ref.watch(voiceSettingsProvider);
  final userAsync = ref.watch(userStatusFutureProvider);
  final coachStyle = userAsync.valueOrNull?.profile?.coachStyle ?? 'supportive';

  coach.updateSettings(settings, effectiveCoachStyle: coachStyle);

  ref.onDispose(() {
    coach.dispose();
  });

  return coach;
});
