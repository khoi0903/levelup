import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'voice_models.dart';

/// Phát giọng thu sẵn (MP3 trong assets/audio, giọng nữ; assets/audio/male, giọng nam).
///
/// Chỉ chọn file theo loại câu (key / mã lỗi tư thế), không đoán theo nội dung chữ: câu nào
/// không có file khớp đúng nội dung thì trả null để Voice Coach đọc bằng TTS.
class AudioClipPlayer {
  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;
  Completer<void>? _playCompleter;
  int _playSessionId = 0;

  Future<void> init() async {
    if (_initialized) return;
    try {
      // mediaPlayer (không dùng lowLatency): lowLatency trên Android không báo phát xong,
      // hàng đợi phải chờ hết thời gian chờ mới đọc câu tiếp.
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setPlayerMode(PlayerMode.mediaPlayer);

      _player.onPlayerComplete.listen((_) {
        if (_playCompleter != null && !_playCompleter!.isCompleted) {
          _playCompleter!.complete();
        }
      });
      _initialized = true;
    } catch (_) {}
  }

  /// File đếm số 1..100. Mỗi số một file (11..99 đã ghép sẵn bằng assets/trim_audio.py,
  /// ghép lúc chạy bị khựng giữa hai file).
  String? repSubPath(int n) => n >= 1 && n <= 100 ? 'reps/$n.mp3' : null;

  /// Đường dẫn asset MP3 cho một câu, null nếu câu đó phải đọc bằng TTS.
  ///
  /// - Đếm số, đếm ngược 3-2-1: luôn dùng MP3.
  /// - Câu nhắc (bắt đầu, xong hiệp, nghỉ...): dùng MP3 khi [styledLines] = false (phong cách
  ///   "coach" mặc định). Người dùng chọn phong cách riêng thì đọc câu của phong cách đó bằng TTS.
  /// - Nhắc tư thế: chỉ khi file khớp đúng câu nhắc của bài đó.
  String? resolveAssetPath(
    VoiceLineKey? key, {
    Map<String, Object?> params = const {},
    String? slug,
    String? issueCode,
    String? text,
    bool styledLines = false,
    VoiceGender gender = VoiceGender.female,
  }) {
    final subPath = _resolveSubPath(
      key,
      params: params,
      slug: slug,
      issueCode: issueCode,
      text: text,
      styledLines: styledLines,
    );
    if (subPath == null) return null;
    final prefix = gender == VoiceGender.male ? 'audio/male' : 'audio';
    return '$prefix/$subPath';
  }

  String? _resolveSubPath(
    VoiceLineKey? key, {
    required Map<String, Object?> params,
    required String? slug,
    required String? issueCode,
    required String? text,
    required bool styledLines,
  }) {
    if (issueCode != null && key != VoiceLineKey.formGeneric) {
      // "Đưa hai tay lên trên đầu" trùng câu nhắc của jumping-jack; lỗi khác đọc câu riêng của bài
      return issueCode == 'arms_not_overhead' && slug == 'jumping-jack'
          ? 'form/hands_overhead.mp3'
          : null;
    }
    int? intParam(String name) => int.tryParse(params[name]?.toString() ?? '');

    // Câu chỉ là một con số (speakText("12"))
    final number = int.tryParse(text?.trim() ?? '');
    if (key == null && number != null) return repSubPath(number);

    switch (key) {
      case VoiceLineKey.rep:
        final n = intParam('n');
        return n == null ? null : repSubPath(n);
      case VoiceLineKey.holdLast:
        // Đếm lùi 2, 1 trước khi vào hiệp và 5 giây cuối khi giữ tư thế: chỉ là con số
        final sec = intParam('sec');
        return sec == null ? null : repSubPath(sec);
      case VoiceLineKey.startCountdown:
        final n = intParam('n');
        if (n != null && n >= 1 && n <= 3) return 'countdown/$n.mp3';
        return styledLines ? null : 'countdown/ready.mp3';
      default:
        break;
    }
    if (styledLines) return null;

    switch (key) {
      case VoiceLineKey.go:
        return 'countdown/go.mp3';
      case VoiceLineKey.almostDone:
        final left = intParam('left');
        return left == 2 || left == 3 ? 'cues/almost_done_$left.mp3' : null;
      case VoiceLineKey.lastRep:
        return 'cues/last_rep.mp3';
      case VoiceLineKey.setDone:
        return 'cues/set_done.mp3';
      case VoiceLineKey.restStart:
        return 'cues/rest_start.mp3';
      case VoiceLineKey.restEnding:
        return 'cues/rest_ending.mp3';
      case VoiceLineKey.lostPerson:
        return 'cues/lost_person.mp3';
      case VoiceLineKey.workoutDone:
        return 'cues/workout_done.mp3';
      case VoiceLineKey.personalRecord:
        return 'cues/personal_record.mp3';
      case VoiceLineKey.holdRemaining:
        final sec = intParam('sec');
        return sec == 10 || sec == 5 ? 'cues/hold_remaining_$sec.mp3' : null;
      case VoiceLineKey.formGeneric:
        return 'form/form_generic.mp3';
      default:
        return null;
    }
  }

  /// Phát một file MP3. false chỉ khi lỗi (để Voice Coach đọc bằng TTS);
  /// bị ngắt giữa chừng (stop, câu mới chen vào) vẫn trả true để không đọc lại câu đó.
  Future<bool> playAsset(String assetPath) async {
    try {
      await stop();
      final session = ++_playSessionId;
      final completer = Completer<void>();
      _playCompleter = completer;

      await _player.play(AssetSource(assetPath));
      if (session != _playSessionId) {
        // Bị dừng trong lúc đang mở file: play() xong sau stop() nên file vẫn kêu → dừng lại
        await _player.stop();
        return true;
      }
      // Clip dài nhất ~3 giây; giới hạn để hàng đợi không kẹt nếu máy không báo phát xong
      await completer.future.timeout(const Duration(seconds: 6), onTimeout: () {});
      if (session == _playSessionId) _playCompleter = null;
      return true;
    } catch (e) {
      debugPrint('[AudioClipPlayer] lỗi phát $assetPath: $e');
      _playCompleter = null;
      return false;
    }
  }

  Future<void> stop() async {
    _playSessionId++;
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
