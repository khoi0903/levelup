import 'dart:convert';

import 'voice_models.dart';

Map<String, ExerciseFormCues> parseFormCuesJson(String jsonString) {
  try {
    final dynamic decoded = jsonDecode(jsonString);
    if (decoded is Map<String, dynamic> && decoded['exercises'] is Map) {
      final exercisesMap = decoded['exercises'] as Map<String, dynamic>;
      final result = <String, ExerciseFormCues>{};
      exercisesMap.forEach((slug, raw) {
        if (raw is Map<String, dynamic>) {
          result[slug] = ExerciseFormCues.fromJson(raw);
        } else if (raw is Map) {
          result[slug] = ExerciseFormCues.fromJson(Map<String, dynamic>.from(raw));
        }
      });
      return result;
    }
  } catch (_) {}
  return const {};
}

const Map<String, ExerciseFormCues> defaultFormCues = {
  'jumping-jack': ExerciseFormCues(
    startTip: [
      'Tiếp đất nhẹ với gối hơi chùng',
      'Đưa tay lên trong tầm thoải mái',
    ],
    issues: {
      'arms_not_overhead': FormIssueCue(
        cue: [
          'Đưa hai tay lên trên đầu',
          'Nâng tay cao trong tầm thoải mái',
        ],
        minimal: ['Tay lên cao'],
      ),
    },
  ),
  'bodyweight-squat': ExerciseFormCues(
    startTip: [
      'Giữ gót bám sàn, gối theo hướng mũi chân',
      'Hạ người chậm trong tầm thoải mái',
    ],
    issues: {
      'shallow_depth': FormIssueCue(
        cue: [
          'Hạ hông trong tầm thoải mái',
          'Gập gối thêm, giữ gót bám sàn',
        ],
        minimal: ['Hạ hông chậm'],
      ),
    },
  ),
  'goblet-squat': ExerciseFormCues(
    startTip: [
      'Giữ tạ sát ngực, gối theo hướng mũi chân',
      'Hạ chậm, giữ lưng tự nhiên',
    ],
    issues: {
      'shallow_depth': FormIssueCue(
        cue: [
          'Hạ hông chậm, giữ tạ sát ngực',
          'Hạ người thêm trong tầm thoải mái',
        ],
        minimal: ['Hạ hông chậm'],
      ),
    },
  ),
  'plank': ExerciseFormCues(
    startTip: [
      'Đặt khuỷu tay dưới vai, giữ hông ngang thân',
      'Siết bụng nhẹ, giữ lưng ổn định và thở đều',
    ],
    issues: {
      'body_not_straight': FormIssueCue(
        cue: [
          'Chỉnh vai, hông, cổ chân thẳng hàng',
          'Siết bụng nhẹ, đưa hông ngang thân',
        ],
        minimal: ['Hông ngang thân'],
      ),
    },
  ),
  'glute-bridge': ExerciseFormCues(
    startTip: [
      'Nâng hông bằng cơ mông, giữ lưng ổn định',
      'Giữ hai bàn chân bám sàn',
    ],
    issues: {
      'bridge_hips_not_high_enough': FormIssueCue(
        cue: [
          'Nâng hông để vai, hông, gối thẳng hàng',
          'Siết mông, nâng hông có kiểm soát',
        ],
        minimal: ['Nâng hông chậm'],
      ),
    },
  ),
  'dead-bug': ExerciseFormCues(
    startTip: [
      'Duỗi tay chân đối bên chậm, giữ lưng dưới ổn định',
      'Giữ bụng siết nhẹ và thở ra khi duỗi',
    ],
    issues: {
      'leg_not_extended': FormIssueCue(
        cue: [
          'Duỗi chân chậm, giữ lưng dưới ổn định',
          'Đưa gót ra xa trong tầm kiểm soát',
        ],
        minimal: ['Duỗi chân chậm'],
      ),
    },
  ),
  'push-up': ExerciseFormCues(
    startTip: [
      'Siết bụng nhẹ, giữ vai, hông, cổ chân thẳng hàng',
      'Hạ ngực chậm, khuỷu tay chếch về sau',
    ],
    issues: {
      'body_not_straight': FormIssueCue(
        cue: [
          'Chỉnh vai, hông, cổ chân thẳng hàng',
          'Siết bụng nhẹ, giữ hông ngang thân',
        ],
        minimal: ['Giữ thân thẳng'],
      ),
      'pushup_not_deep_enough': FormIssueCue(
        cue: [
          'Hạ ngực chậm trong tầm thoải mái',
          'Gập khuỷu tay thêm có kiểm soát',
        ],
        minimal: ['Hạ ngực chậm'],
      ),
    },
  ),
  'reverse-lunge': ExerciseFormCues(
    startTip: [
      'Bước lùi chậm, giữ gối trước theo hướng mũi chân',
      'Hạ người trong tầm thoải mái, giữ chân trước bám sàn',
    ],
    issues: {
      'lunge_not_deep_enough': FormIssueCue(
        cue: [
          'Gập hai gối trong tầm thoải mái',
          'Hạ gối sau chậm về phía sàn',
        ],
        minimal: ['Hạ người chậm'],
      ),
    },
  ),
  'dumbbell-shoulder-press': ExerciseFormCues(
    startTip: [
      'Siết bụng nhẹ, giữ lưng ổn định khi đẩy tạ',
      'Giữ cổ tay thẳng, hạ tạ chậm',
    ],
    issues: {
      'press_not_locked_out': FormIssueCue(
        cue: [
          'Duỗi tay lên trong tầm thoải mái',
          'Đẩy tạ cao có kiểm soát',
        ],
        minimal: ['Duỗi tay lên'],
      ),
    },
  ),
  'standing-calf-raise': ExerciseFormCues(
    startTip: [
      'Nhón gót chậm, chạm tay vào tường để giữ thăng bằng',
      'Giữ cổ chân ổn định khi hạ gót',
    ],
    issues: {
      'heels_not_high_enough': FormIssueCue(
        cue: [
          'Nhón gót cao trong tầm thoải mái',
          'Nâng gót chậm, giữ cổ chân ổn định',
        ],
        minimal: ['Nhón gót chậm'],
      ),
    },
  ),
  'wall-sit': ExerciseFormCues(
    startTip: [
      'Tựa lưng vào tường, giữ gối theo hướng mũi chân',
      'Chỉnh độ gập gối chậm trong tầm thoải mái',
    ],
    issues: {
      'knee_not_at_90': FormIssueCue(
        cue: [
          'Chỉnh gối gần vuông góc, thật chậm',
          'Chỉnh độ gập gối trong tầm thoải mái',
        ],
        minimal: ['Gối gần vuông góc'],
      ),
    },
  ),
  'bird-dog': ExerciseFormCues(
    startTip: [
      'Vươn tay chân đối bên chậm, giữ lưng ổn định',
      'Giữ hông hướng xuống sàn, chân ngang thân',
    ],
    issues: {
      'leg_not_extended': FormIssueCue(
        cue: [
          'Vươn chân ra sau ngang thân',
          'Duỗi chân chậm, giữ hông hướng xuống sàn',
        ],
        minimal: ['Vươn chân ra sau'],
      ),
    },
  ),
  'side-lying-leg-raise': ExerciseFormCues(
    startTip: [
      'Giữ hông và vai xếp chồng, mũi chân hướng trước',
      'Nâng chân chậm trong tầm kiểm soát',
    ],
    issues: {
      'leg_not_high_enough': FormIssueCue(
        cue: [
          'Nâng chân trên trong tầm thoải mái',
          'Nâng chân cao hơn, giữ hông ổn định',
        ],
        minimal: ['Nâng chân chậm'],
      ),
    },
  ),
  'wall-push-up': ExerciseFormCues(
    startTip: [
      'Đặt tay ngang ngực, giữ thân thẳng khi nghiêng vào tường',
      'Đưa ngực gần tường chậm, khuỷu tay chếch xuống',
    ],
    issues: {
      'body_not_straight': FormIssueCue(
        cue: [
          'Chỉnh vai, hông, cổ chân thẳng hàng',
          'Giữ bụng chắc, đưa hông thẳng theo thân',
        ],
        minimal: ['Giữ thân thẳng'],
      ),
      'pushup_not_deep_enough': FormIssueCue(
        cue: [
          'Đưa ngực gần tường trong tầm thoải mái',
          'Gập khuỷu tay chậm, đưa ngực gần tường',
        ],
        minimal: ['Ngực gần tường'],
      ),
    },
  ),
  'march-in-place': ExerciseFormCues(
    startTip: [
      'Nâng gối vừa tầm, giữ thân thẳng và ổn định',
      'Đặt chân xuống nhẹ, giữ nhịp đều',
    ],
    issues: {
      'torso_leaning': FormIssueCue(
        cue: [
          'Đưa vai về trên hông',
          'Giữ thân thẳng khi nâng gối',
        ],
        minimal: ['Giữ thân thẳng'],
      ),
    },
  ),
  'step-jack': ExerciseFormCues(
    startTip: [
      'Bước ngang vừa tầm, luôn giữ một chân trên sàn',
      'Đưa tay lên chậm trong tầm thoải mái',
    ],
    issues: {
      'arms_not_straight': FormIssueCue(
        cue: [
          'Duỗi tay nhẹ khi đưa lên',
          'Mở khuỷu tay trong tầm thoải mái',
        ],
        minimal: ['Duỗi tay nhẹ'],
      ),
    },
  ),
  'dumbbell-bent-over-row': ExerciseFormCues(
    startTip: [
      'Gập từ hông, giữ lưng tự nhiên và thân ổn định',
      'Kéo tạ chậm về eo, khuỷu tay sát thân',
    ],
    issues: {
      'row_not_high_enough': FormIssueCue(
        cue: [
          'Kéo tạ về eo có kiểm soát',
          'Đưa khuỷu tay ra sau sát thân',
        ],
        minimal: ['Kéo tạ về eo'],
      ),
    },
  ),
  'seated-resistance-band-row': ExerciseFormCues(
    startTip: [
      'Giữ dây chắc quanh bàn chân, lưng thẳng tự nhiên',
      'Kéo dây chậm về eo, giữ thân ổn định',
    ],
    issues: {
      'row_not_high_enough': FormIssueCue(
        cue: [
          'Kéo hai đầu dây về eo',
          'Đưa khuỷu tay ra sau có kiểm soát',
        ],
        minimal: ['Kéo dây về eo'],
      ),
    },
  ),
  'dumbbell-biceps-curl': ExerciseFormCues(
    startTip: [
      'Giữ khuỷu tay sát thân và cổ tay thẳng',
      'Cuốn tạ chậm, giữ thân ổn định',
    ],
    issues: {
      'curl_not_full_range': FormIssueCue(
        cue: [
          'Gập khuỷu tay thêm có kiểm soát',
          'Cuốn tạ gần vai, giữ khuỷu sát thân',
        ],
        minimal: ['Cuốn tạ gần vai'],
      ),
    },
  ),
  'dumbbell-floor-press': ExerciseFormCues(
    startTip: [
      'Giữ cổ tay thẳng khi đẩy tạ lên trên ngực',
      'Hạ tạ chậm, để cánh tay chạm sàn nhẹ',
    ],
    issues: {
      'press_not_locked_out': FormIssueCue(
        cue: [
          'Duỗi tay lên trên ngực nhẹ nhàng',
          'Đẩy tạ lên trong tầm kiểm soát',
        ],
        minimal: ['Duỗi tay lên'],
      ),
    },
  ),
};
