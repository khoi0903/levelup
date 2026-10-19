import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Câu nhắc cách vẫy tay (3 buổi đầu) và câu hỏi đổi bài mẫu (khi không lấy được câu từ server).
const waveSkipTipVi = 'Mẹo: muốn bỏ bài thì vẫy một tay trên đầu, không cần chạy lại điện thoại.';
/// Vẫy tay khi bật điều khiển giọng nói: coach hỏi lệnh.
const voiceCommandAskVi = 'Mình nghe đây: bỏ bài, tạm dừng, hay xong hiệp?';
const waveSkipPromptVi =
    'Cần đổi bài không? Vẫy tay trên đầu nếu muốn bỏ qua, hoặc cứ tập tiếp nhé.';

/// Số lần đã nhắc cách vẫy tay; đủ [maxTips] lần hoặc đã vẫy thành công thì thôi nhắc.
class WaveSkipTips {
  static const _key = 'wave_skip_tips_spoken';
  static const maxTips = 3;

  Future<bool> shouldSpeak() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_key) ?? 0) < maxTips;
  }

  Future<void> markSpoken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, (prefs.getInt(_key) ?? 0) + 1);
  }

  /// Đã tự vẫy tay được: không cần nhắc nữa.
  Future<void> markLearned() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, maxTips);
  }
}

final waveSkipTipsProvider = Provider<WaveSkipTips>((ref) => WaveSkipTips());
