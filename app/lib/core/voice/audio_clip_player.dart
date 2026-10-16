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

  /// Bảng đối chiếu tên bài tập (slug và nameVi) cho 34 bài trong LevelUp.
  static const Map<String, String> _nameToSlug = {
    'jumping-jack': 'jumping-jack',
    'bật nhảy tại chỗ': 'jumping-jack',
    'jumping jack': 'jumping-jack',
    'bodyweight-squat': 'bodyweight-squat',
    'squat không tạ': 'bodyweight-squat',
    'bodyweight squat': 'bodyweight-squat',
    'goblet-squat': 'goblet-squat',
    'squat ôm tạ': 'goblet-squat',
    'goblet squat': 'goblet-squat',
    'plank': 'plank',
    'glute-bridge': 'glute-bridge',
    'nâng hông': 'glute-bridge',
    'glute bridge': 'glute-bridge',
    'dead-bug': 'dead-bug',
    'duỗi tay chân đối bên': 'dead-bug',
    'dead bug': 'dead-bug',
    'push-up': 'push-up',
    'hít đất': 'push-up',
    'push up': 'push-up',
    'reverse-lunge': 'reverse-lunge',
    'lunge bước lùi': 'reverse-lunge',
    'reverse lunge': 'reverse-lunge',
    'dumbbell-shoulder-press': 'dumbbell-shoulder-press',
    'đẩy vai tạ đơn': 'dumbbell-shoulder-press',
    'dumbbell shoulder press': 'dumbbell-shoulder-press',
    'standing-calf-raise': 'standing-calf-raise',
    'nhón gót đứng': 'standing-calf-raise',
    'standing calf raise': 'standing-calf-raise',
    'wall-sit': 'wall-sit',
    'ngồi tựa tường': 'wall-sit',
    'wall sit': 'wall-sit',
    'bird-dog': 'bird-dog',
    'vươn tay chân đối bên': 'bird-dog',
    'bird dog': 'bird-dog',
    'side-lying-leg-raise': 'side-lying-leg-raise',
    'nằm nghiêng nâng chân': 'side-lying-leg-raise',
    'side lying leg raise': 'side-lying-leg-raise',
    'wall-push-up': 'wall-push-up',
    'hít đất vào tường': 'wall-push-up',
    'wall push up': 'wall-push-up',
    'march-in-place': 'march-in-place',
    'đi bộ tại chỗ': 'march-in-place',
    'march in place': 'march-in-place',
    'step-jack': 'step-jack',
    'bước ngang kết hợp đưa tay': 'step-jack',
    'step jack': 'step-jack',
    'dumbbell-bent-over-row': 'dumbbell-bent-over-row',
    'kéo tạ đơn gập người': 'dumbbell-bent-over-row',
    'dumbbell bent over row': 'dumbbell-bent-over-row',
    'seated-resistance-band-row': 'seated-resistance-band-row',
    'ngồi kéo dây kháng lực': 'seated-resistance-band-row',
    'seated resistance band row': 'seated-resistance-band-row',
    'dumbbell-biceps-curl': 'dumbbell-biceps-curl',
    'cuốn tay trước với tạ đơn': 'dumbbell-biceps-curl',
    'dumbbell biceps curl': 'dumbbell-biceps-curl',
    'dumbbell-floor-press': 'dumbbell-floor-press',
    'đẩy ngực tạ đơn trên sàn': 'dumbbell-floor-press',
    'dumbbell floor press': 'dumbbell-floor-press',
    'arm-circles': 'arm-circles',
    'xoay tay vòng tròn nhỏ': 'arm-circles',
    'arm circles': 'arm-circles',
    'prone-y-t-raise': 'prone-y-t-raise',
    'nâng tay chữ y và t nằm sấp': 'prone-y-t-raise',
    'prone y t raise': 'prone-y-t-raise',
    'wall-slide': 'wall-slide',
    'trượt tay trên tường': 'wall-slide',
    'wall slide': 'wall-slide',
    'close-grip-wall-push-up': 'close-grip-wall-push-up',
    'hít đất tường tay hẹp': 'close-grip-wall-push-up',
    'close grip wall push up': 'close-grip-wall-push-up',
    'wall-triceps-extension': 'wall-triceps-extension',
    'duỗi tay sau vào tường': 'wall-triceps-extension',
    'wall triceps extension': 'wall-triceps-extension',
    'self-resisted-biceps-curl': 'self-resisted-biceps-curl',
    'cuốn tay trước tự kháng lực': 'self-resisted-biceps-curl',
    'self resisted biceps curl': 'self-resisted-biceps-curl',
    'low-superman': 'low-superman',
    'nâng thân nằm sấp nhẹ': 'low-superman',
    'low superman': 'low-superman',
    'prone-snow-angel': 'prone-snow-angel',
    'thiên thần tuyết nằm sấp': 'prone-snow-angel',
    'prone snow angel': 'prone-snow-angel',
    'prone-row': 'prone-row',
    'chèo tay nằm sấp không tạ': 'prone-row',
    'prone row': 'prone-row',
    'supine-heel-slide': 'supine-heel-slide',
    'trượt gót nằm ngửa': 'supine-heel-slide',
    'supine heel slide': 'supine-heel-slide',
    'slow-mountain-climber': 'slow-mountain-climber',
    'kéo gối chậm chống tay': 'slow-mountain-climber',
    'slow mountain climber': 'slow-mountain-climber',
    'quadruped-glute-kickback': 'quadruped-glute-kickback',
    'đá chân sau chống gối': 'quadruped-glute-kickback',
    'quadruped glute kickback': 'quadruped-glute-kickback',
    'standing-hamstring-curl': 'standing-hamstring-curl',
    'gập gối đứng không tạ': 'standing-hamstring-curl',
    'standing hamstring curl': 'standing-hamstring-curl',
    'side-step-touch': 'side-step-touch',
    'bước ngang chạm chân': 'side-step-touch',
    'side step touch': 'side-step-touch',
  };

  /// Tìm slug bài tập từ slug trực tiếp, params hoặc text.
  static String? _findSlug({
    String? slug,
    Map<String, Object?> params = const {},
    String? text,
  }) {
    if (slug != null && slug.isNotEmpty) {
      final s = slug.trim().toLowerCase();
      if (_nameToSlug.containsKey(s)) return _nameToSlug[s];
      return slug;
    }
    if (params.containsKey('slug')) {
      final s = params['slug']?.toString().trim().toLowerCase();
      if (s != null && s.isNotEmpty) {
        if (_nameToSlug.containsKey(s)) return _nameToSlug[s];
        return s;
      }
    }
    if (params.containsKey('exercise')) {
      final ex = params['exercise']?.toString().trim().toLowerCase();
      if (ex != null && ex.isNotEmpty) {
        if (_nameToSlug.containsKey(ex)) return _nameToSlug[ex];
      }
    }
    if (text != null && text.isNotEmpty) {
      final clean = text.trim().toLowerCase();
      if (_nameToSlug.containsKey(clean)) return _nameToSlug[clean];
    }
    return null;
  }

  /// Đường dẫn asset MP3 cho một câu, null nếu câu đó phải đọc bằng TTS.
  ///
  /// - Đếm số, đếm ngược 3-2-1: luôn dùng MP3.
  /// - Tên bài tập (exercise_next) và mẹo (startTip): dùng MP3 nếu có sẵn.
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
    bool isStartTip = false,
    VoiceGender gender = VoiceGender.female,
  }) {
    final subPath = _resolveSubPath(
      key,
      params: params,
      slug: slug,
      issueCode: issueCode,
      text: text,
      styledLines: styledLines,
      isStartTip: isStartTip,
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
    bool isStartTip = false,
  }) {
    if (isStartTip) {
      final s = _findSlug(slug: slug, params: params, text: text);
      return s != null ? 'tips/$s.mp3' : null;
    }

    if (key == VoiceLineKey.exerciseNext) {
      final s = _findSlug(slug: slug, params: params, text: text);
      return s != null ? 'exercises/$s.mp3' : null;
    }

    if (slug != null && key == null && issueCode == null) {
      final s = _findSlug(slug: slug);
      if (s != null) return 'exercises/$s.mp3';
    }

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
