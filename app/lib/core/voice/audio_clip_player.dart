import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'voice_models.dart';

/// Quản lý phát âm thanh thu âm người thật (file MP3) cho Voice Coach.
/// Có cơ chế fallback: nếu không có file âm thanh cho câu đó, hệ thống sẽ tự động dùng TTS.
class AudioClipPlayer {
  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;
  Completer<void>? _playCompleter;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setPlayerMode(PlayerMode.lowLatency);

      _player.onPlayerComplete.listen((_) {
        if (_playCompleter != null && !_playCompleter!.isCompleted) {
          _playCompleter!.complete();
        }
      });
      _initialized = true;
    } catch (_) {}
  }

  /// Map VoiceLineKey hoặc mã lỗi form sang đường dẫn asset MP3 người thật tương ứng.
  String? resolveAssetPath(
    VoiceLineKey? key, {
    Map<String, Object?> params = const {},
    String? slug,
    String? issueCode,
    String? text,
    VoiceGender gender = VoiceGender.female,
  }) {
    final subPath = _resolveSubPath(
      key,
      params: params,
      slug: slug,
      issueCode: issueCode,
      text: text,
    );
    if (subPath == null) return null;

    final prefix = gender == VoiceGender.male ? 'audio/male' : 'audio';
    return '$prefix/$subPath';
  }

  String? _resolveSubPath(
    VoiceLineKey? key, {
    Map<String, Object?> params = const {},
    String? slug,
    String? issueCode,
    String? text,
  }) {
    // 0. Nếu có text (hoặc gọi qua speakText), match theo nội dung câu nói
    if (text != null && text.isNotEmpty) {
      final clean = text.trim().toLowerCase();
      if (clean.contains('bắt đầu') ||
          clean.contains('chiến') ||
          clean.contains('gét gô') ||
          clean.contains('lên luôn') ||
          clean.contains('cháy') ||
          clean.contains('vào việc') ||
          clean.contains('nhịp') ||
          clean.contains('vào hiệp') ||
          clean.contains('lên sóng') ||
          clean.contains('cùng tập') ||
          clean.contains('quẩy') ||
          clean.contains('đến lượt')) {
        return 'countdown/go.mp3';
      }
      if (clean.contains('chuẩn bị') || clean.contains('lên thớt')) {
        return 'countdown/ready.mp3';
      }
      if (clean == '1' || clean == 'một') return 'reps/1.mp3';
      if (clean == '2' || clean == 'hai') return 'reps/2.mp3';
      if (clean == '3' || clean == 'ba') return 'reps/3.mp3';
      if (clean.contains('xong hiệp') || clean.contains('hoàn thành hiệp')) {
        return 'cues/set_done.mp3';
      }
      if (clean.contains('nghỉ')) {
        return 'cues/rest_start.mp3';
      }
      if (clean.contains('hoàn thành buổi tập') ||
          clean.contains('kết thúc buổi tập') ||
          clean.contains('tuyệt vời')) {
        return 'cues/workout_done.mp3';
      }
      if (clean.contains('kỷ lục')) {
        return 'cues/personal_record.mp3';
      }
      if (clean.contains('lùi lại') || clean.contains('khung hình')) {
        return 'cues/lost_person.mp3';
      }
      if (clean.contains('lưng')) {
        return 'form/straight_back.mp3';
      }
      if (clean.contains('hông') || clean.contains('mông')) {
        return 'form/squat_shallow.mp3';
      }
      if (clean.contains('gối')) {
        return 'form/squat_knees.mp3';
      }
      if (clean.contains('tay')) {
        return 'form/hands_overhead.mp3';
      }
    }

    // 1. Đếm rep 1..30
    if (key == VoiceLineKey.rep && params.containsKey('n')) {
      final n = int.tryParse(params['n'].toString());
      if (n != null && n >= 1 && n <= 30) {
        return 'reps/$n.mp3';
      }
    }

    // 2. Đếm ngược & Bắt đầu
    if (key == VoiceLineKey.go) {
      return 'countdown/go.mp3';
    }
    if (key == VoiceLineKey.startCountdown) {
      final n = int.tryParse(params['n']?.toString() ?? '');
      if (n != null && n >= 1 && n <= 3) {
        return 'countdown/$n.mp3';
      }
      return 'countdown/ready.mp3';
    }

    // 3. Các mốc câu nhắc (Cues)
    if (key == VoiceLineKey.almostDone) {
      final left = int.tryParse(params['left']?.toString() ?? '');
      if (left == 2) return 'cues/almost_done_2.mp3';
      if (left == 3) return 'cues/almost_done_3.mp3';
      return null;
    }
    if (key == VoiceLineKey.lastRep) {
      return 'cues/last_rep.mp3';
    }
    if (key == VoiceLineKey.setDone) {
      return 'cues/set_done.mp3';
    }
    if (key == VoiceLineKey.restStart) {
      return 'cues/rest_start.mp3';
    }
    if (key == VoiceLineKey.restEnding) {
      return 'cues/rest_ending.mp3';
    }
    if (key == VoiceLineKey.lostPerson) {
      return 'cues/lost_person.mp3';
    }
    if (key == VoiceLineKey.workoutDone) {
      return 'cues/workout_done.mp3';
    }
    if (key == VoiceLineKey.personalRecord) {
      return 'cues/personal_record.mp3';
    }
    if (key == VoiceLineKey.holdRemaining) {
      final sec = int.tryParse(params['sec']?.toString() ?? '');
      if (sec == 10) return 'cues/hold_remaining_10.mp3';
      if (sec == 5) return 'cues/hold_remaining_5.mp3';
      return null;
    }

    // 4. Nhắc sửa lỗi tư thế (Form Cues)
    if (issueCode != null) {
      switch (issueCode) {
        case 'shallow_depth':
          return 'form/squat_shallow.mp3';
        case 'knees_caving':
          return 'form/squat_knees.mp3';
        case 'straight_back':
        case 'round_back':
        case 'arched_back':
          return 'form/straight_back.mp3';
        case 'arms_not_overhead':
          return 'form/hands_overhead.mp3';
        default:
          return null;
      }
    }

    if (key == VoiceLineKey.formGeneric) {
      return 'form/form_generic.mp3';
    }

    return null;
  }

  /// Phát file MP3 asset người thật.
  /// Trả về true nếu phát thành công; false nếu lỗi để caller fallback sang TTS.
  Future<bool> playAsset(String assetPath) async {
    try {
      await stop();

      final completer = Completer<void>();
      _playCompleter = completer;

      debugPrint('[AudioClipPlayer] >>> Phát file audio người thật: $assetPath');
      await _player.play(AssetSource(assetPath));

      // Giới hạn thời gian chờ phát xong tối đa 6s để hàng đợi không bị kẹt
      await completer.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () {},
      );
      debugPrint('[AudioClipPlayer] <<< Hoàn thành phát audio: $assetPath');
      return true;
    } catch (e) {
      debugPrint('[AudioClipPlayer] LỖI khi phát audio $assetPath: $e');
      return false;
    } finally {
      _playCompleter = null;
    }
  }

  Future<void> stop() async {
    try {
      if (_playCompleter != null && !_playCompleter!.isCompleted) {
        _playCompleter!.complete();
      }
      _playCompleter = null;
      await _player.stop();
    } catch (_) {}
  }

  void dispose() {
    stop();
    _player.dispose();
  }
}
