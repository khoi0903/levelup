import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';

/// Câu coach đọc trong lúc tập (POST /coach/voice-line). Server quyết định: Pro được câu AI soạn theo
/// tình huống, còn lại câu mẫu theo phong cách coach.
class VoiceLine {
  final String text;
  final bool ai;
  const VoiceLine(this.text, {this.ai = false});
}

abstract class VoiceLineRepository {
  /// [situation]: idle_prompt (đứng lâu, hỏi đổi bài) | skipped (vừa bỏ bài).
  Future<VoiceLine> line({
    required String situation,
    required String exerciseName,
    int? repsDone,
    int? targetReps,
    List<String> formIssues = const [],
  });
}

class ApiVoiceLineRepository implements VoiceLineRepository {
  ApiVoiceLineRepository(this.client);
  final ApiClient client;

  @override
  Future<VoiceLine> line({
    required String situation,
    required String exerciseName,
    int? repsDone,
    int? targetReps,
    List<String> formIssues = const [],
  }) async {
    final res = await client.post(
      '/coach/voice-line',
      data: {
        'situation': situation,
        'exerciseName': exerciseName,
        'repsDone': ?repsDone,
        'targetReps': ?targetReps,
        'formIssues': formIssues.take(5).toList(),
      },
    );
    final j = res.data as Map<String, dynamic>;
    return VoiceLine(j['text'] as String? ?? '', ai: j['ai'] == true);
  }
}

final voiceLineRepositoryProvider = Provider<VoiceLineRepository>(
  (ref) => ApiVoiceLineRepository(ref.watch(apiClientProvider)),
);
