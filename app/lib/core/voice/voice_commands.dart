import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Lệnh giọng nói trong lúc tập bằng camera.
enum VoiceCommand {
  /// "bỏ bài", "bỏ qua", "đổi bài", "qua bài"
  skip,

  /// "tập tiếp", "tiếp tục", "huỷ", "không"
  resume,

  /// "tạm dừng", "dừng lại", "nghỉ chút"
  pause,

  /// "xong", "xong hiệp", "kết thúc"
  finishSet,
}

const _marks = {
  'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a', 'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a',
  'ặ': 'a', 'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a', 'è': 'e', 'é': 'e', 'ẻ': 'e',
  'ẽ': 'e', 'ẹ': 'e', 'ê': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e', 'ì': 'i', 'í': 'i',
  'ỉ': 'i', 'ĩ': 'i', 'ị': 'i', 'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o', 'ô': 'o', 'ồ': 'o',
  'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o', 'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
  'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u', 'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u',
  'ự': 'u', 'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y', 'đ': 'd',
};

/// "Bỏ  Bài!" → "bo bai": chữ thường, bỏ dấu, bỏ ký tự lạ.
String normalizeVi(String text) {
  final lower = text.toLowerCase();
  final b = StringBuffer();
  for (final ch in lower.split('')) {
    b.write(_marks[ch] ?? ch);
  }
  return b
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

// Thứ tự quan trọng: "không bỏ" là tập tiếp, "xong rồi bỏ" vẫn ưu tiên bỏ bài.
const _phrases = <(VoiceCommand, List<String>)>[
  (VoiceCommand.resume, ['khong bo', 'dung bo', 'tap tiep', 'tiep tuc', 'lam tiep', 'huy', 'thoi khong']),
  (VoiceCommand.skip, ['bo bai', 'bo qua', 'doi bai', 'qua bai', 'bai khac', 'skip', 'next']),
  (VoiceCommand.pause, ['tam dung', 'dung lai', 'nghi chut', 'nghi mot chut', 'pause']),
  (VoiceCommand.finishSet, ['xong hiep', 'xong roi', 'ket thuc', 'xong']),
  (VoiceCommand.resume, ['tiep', 'khong']),
];

/// Hiểu một câu nói thành lệnh; null khi không chắc (nói chuyện khác, nhạc, tiếng thở...).
VoiceCommand? parseVoiceCommand(String transcript) {
  final t = ' ${normalizeVi(transcript)} ';
  if (t.trim().isEmpty || t.trim().split(' ').length > 6) return null;
  for (final (command, phrases) in _phrases) {
    for (final p in phrases) {
      if (t.contains(' $p ')) return command;
    }
  }
  return null;
}

/// Nghe một câu ngắn trong [window] rồi trả lệnh. Chỉ bật khi người dùng cho phép trong Cài đặt.
abstract class VoiceCommandListener {
  /// Xin quyền micro / khởi tạo; false khi máy không hỗ trợ hoặc bị từ chối.
  Future<bool> init();

  /// Nghe tối đa [window]; trả lệnh đầu tiên hiểu được hoặc null.
  Future<VoiceCommand?> listenOnce({Duration window = const Duration(seconds: 6)});

  Future<void> stop();
}

/// Dùng nhận dạng giọng nói của máy (ưu tiên tiếng Việt). Mỗi lần nghe là một phiên ngắn, không nghe liên tục.
class SpeechToTextCommandListener implements VoiceCommandListener {
  final SpeechToText _speech = SpeechToText();
  bool _ready = false;
  String? _localeId;

  @override
  Future<bool> init() async {
    if (_ready) return true;
    try {
      _ready = await _speech.initialize(onError: (e) => debugPrint('speech error: ${e.errorMsg}'));
      if (_ready) {
        final locales = await _speech.locales();
        _localeId = locales
            .map((l) => l.localeId)
            .firstWhere((id) => id.toLowerCase().startsWith('vi'), orElse: () => 'vi_VN');
      }
    } catch (e) {
      debugPrint('speech init error: $e');
      _ready = false;
    }
    return _ready;
  }

  @override
  Future<VoiceCommand?> listenOnce({Duration window = const Duration(seconds: 6)}) async {
    if (!await init()) return null;
    final done = Completer<VoiceCommand?>();
    try {
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          listenFor: window,
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
          // Gợi ý các câu lệnh để nhận dạng chính xác hơn (máy hỗ trợ thì dùng)
          contextualPhrases: const [
            'bỏ bài', 'bỏ qua', 'đổi bài', 'tập tiếp', 'tiếp tục', 'huỷ',
            'tạm dừng', 'dừng lại', 'xong hiệp', 'xong rồi',
          ],
        ),
        onResult: (r) {
          final command = parseVoiceCommand(r.recognizedWords);
          if (command != null && !done.isCompleted) {
            done.complete(command);
            unawaited(_speech.stop());
          } else if (r.finalResult && !done.isCompleted) {
            done.complete(null);
          }
        },
      );
    } catch (e) {
      debugPrint('speech listen error: $e');
      if (!done.isCompleted) done.complete(null);
    }
    return done.future.timeout(window + const Duration(seconds: 1), onTimeout: () {
      unawaited(_speech.stop());
      return null;
    });
  }

  @override
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
  }
}

final voiceCommandListenerProvider = Provider<VoiceCommandListener>(
  (ref) => SpeechToTextCommandListener(),
);
