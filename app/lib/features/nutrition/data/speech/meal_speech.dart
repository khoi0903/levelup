import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Đọc món bằng giọng nói cho ô "Bạn đã ăn gì?". Âm thanh do dịch vụ nhận dạng của máy xử lý,
/// app chỉ nhận lại chữ.
abstract interface class MealSpeech {
  /// Xin quyền micro (lần đầu) và bắt đầu nghe tiếng Việt. Trả false nếu máy không hỗ trợ
  /// hoặc người dùng từ chối quyền. [onText] nhận chữ đang nghe được, [onDone] gọi khi phiên kết thúc.
  Future<bool> start({
    required void Function(String text) onText,
    required VoidCallback onDone,
  });

  Future<void> stop();
}

class DeviceMealSpeech implements MealSpeech {
  final SpeechToText _speech = SpeechToText();
  bool _ready = false;
  String? _localeId;
  VoidCallback? _onDone;

  void _finish() {
    final done = _onDone;
    _onDone = null;
    done?.call();
  }

  @override
  Future<bool> start({
    required void Function(String text) onText,
    required VoidCallback onDone,
  }) async {
    try {
      if (!_ready) {
        // initialize() tự hiện hộp xin quyền micro của hệ điều hành
        _ready = await _speech.initialize(
          onError: (e) {
            debugPrint('meal speech error: ${e.errorMsg}');
            _finish();
          },
          onStatus: (status) {
            if (status == SpeechToText.doneStatus ||
                status == SpeechToText.notListeningStatus) {
              _finish();
            }
          },
        );
        if (_ready) {
          final locales = await _speech.locales();
          _localeId = locales
              .map((l) => l.localeId)
              .firstWhere(
                (id) => id.toLowerCase().startsWith('vi'),
                orElse: () => 'vi_VN',
              );
        }
      }
      if (!_ready) return false;
      _onDone = onDone;
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: _localeId ?? 'vi_VN',
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
        onResult: (r) {
          onText(r.recognizedWords);
          if (r.finalResult) _finish();
        },
      );
      return true;
    } catch (e) {
      debugPrint('meal speech start error: $e');
      _onDone = null;
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
    _finish();
  }
}

final mealSpeechProvider = Provider<MealSpeech>((ref) => DeviceMealSpeech());
