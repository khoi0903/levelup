// Bản sao cho màn debug của mongo/cv-configs.json và tên bài trong
// mongo/seed/exercises.json (app chưa khai báo asset cho thư mục mongo/).
// Test exercise_configs_test.dart kiểm tra bản sao này khớp với file gốc;
// sửa cv-configs.json thì chép lại nội dung vào đây.
library;

import 'dart:convert';

import '../domain/cv_config.dart';

/// Một bài có cấu hình camera, lấy theo `activeVersion`.
class DebugExerciseConfig {
  const DebugExerciseConfig({
    required this.slug,
    required this.nameVi,
    required this.cameraPosition,
    required this.config,
  });

  final String slug;
  final String nameVi;

  /// `side` hoặc `front`.
  final String cameraPosition;
  final CvConfig config;
}

/// Các bài theo thứ tự trong cv-configs.json.
List<DebugExerciseConfig> debugExerciseConfigs() {
  final all = jsonDecode(debugCvConfigsJson) as Map<String, dynamic>;
  return [
    for (final MapEntry(key: slug, value: raw) in all.entries)
      _active(slug, raw as Map<String, dynamic>),
  ];
}

DebugExerciseConfig _active(String slug, Map<String, dynamic> exercise) {
  final entry = (exercise['configs'] as List)
      .cast<Map<String, dynamic>>()
      .singleWhere((entry) => entry['version'] == exercise['activeVersion']);
  return DebugExerciseConfig(
    slug: slug,
    nameVi: debugExerciseNamesVi[slug] ?? slug,
    cameraPosition: entry['cameraPosition'] as String,
    config: CvConfig.fromJson(entry['config'] as Map<String, dynamic>),
  );
}

/// `nameVi` của các bài có cấu hình camera.
const debugExerciseNamesVi = <String, String>{
  'jumping-jack': 'Bật nhảy tại chỗ',
  'bodyweight-squat': 'Squat không tạ',
  'goblet-squat': 'Squat ôm tạ',
  'plank': 'Plank',
  'glute-bridge': 'Nâng hông',
  'dead-bug': 'Duỗi tay chân đối bên',
  'push-up': 'Hít đất',
  'reverse-lunge': 'Lunge bước lùi',
  'dumbbell-shoulder-press': 'Đẩy vai tạ đơn',
  'standing-calf-raise': 'Nhón gót đứng',
  'wall-sit': 'Ngồi tựa tường',
  'bird-dog': 'Vươn tay chân đối bên',
  'side-lying-leg-raise': 'Nằm nghiêng nâng chân',
  'wall-push-up': 'Hít đất vào tường',
  'march-in-place': 'Đi bộ tại chỗ',
  'step-jack': 'Bước ngang kết hợp đưa tay',
  'dumbbell-bent-over-row': 'Kéo tạ đơn gập người',
  'seated-resistance-band-row': 'Ngồi kéo dây kháng lực',
  'dumbbell-biceps-curl': 'Cuốn tay trước với tạ đơn',
  'dumbbell-floor-press': 'Đẩy ngực tạ đơn trên sàn',
};

/// Nội dung y nguyên của mongo/cv-configs.json.
const debugCvConfigsJson = r'''
{
  "bodyweight-squat": {
    "activeVersion": 1,
    "configs": [
      {
        "version": 1,
        "cameraPosition": "side",
        "config": {
          "joints": ["hip", "knee", "ankle"],
          "downBelow": 95,
          "upAbove": 160,
          "minConfidence": 0.6,
          "minRepMs": 600,
          "formRules": [{ "code": "shallow_depth", "maxDepthAngle": 100 }]
        }
      }
    ]
  },
  "goblet-squat": {
    "activeVersion": 1,
    "configs": [
      {
        "version": 1,
        "cameraPosition": "side",
        "config": {
          "joints": ["hip", "knee", "ankle"],
          "downBelow": 110,
          "upAbove": 160,
          "minConfidence": 0.6,
          "minRepMs": 700,
          "formRules": [
            { "type": "min_depth", "code": "shallow_depth", "angle": 100, "severity": [105, 110] }
          ],
          "placement": "floor_side",
          "setupTipVi": "Đặt điện thoại dựng đứng trên sàn hoặc ghế thấp, cách 2–3 m, nhìn nghiêng người bạn. Cả người từ vai tới bàn chân phải nằm trong khung; giữ tạ trước ngực, không che hông."
        }
      }
    ]
  },
  "reverse-lunge": {
    "activeVersion": 1,
    "configs": [
      {
        "version": 1,
        "cameraPosition": "side",
        "config": {
          "joints": ["hip", "knee", "ankle"],
          "side": "min",
          "downBelow": 115,
          "upAbove": 160,
          "minConfidence": 0.6,
          "minRepMs": 800,
          "formRules": [
            { "type": "min_depth", "code": "lunge_not_deep_enough", "angle": 100, "severity": [108, 115] }
          ],
          "placement": "floor_side",
          "setupTipVi": "Đặt điện thoại trên sàn cách 2,5–3 m, nhìn nghiêng. Lùi chân ra sau theo hướng song song với camera để cả hai chân luôn trong khung."
        }
      }
    ]
  },
  "glute-bridge": {
    "activeVersion": 1,
    "configs": [
      {
        "version": 1,
        "cameraPosition": "side",
        "config": {
          "joints": ["shoulder", "hip", "knee"],
          "direction": "extend",
          "downBelow": 150,
          "upAbove": 162,
          "minConfidence": 0.5,
          "minRepMs": 600,
          "formRules": [
            { "type": "max_extreme", "code": "bridge_hips_not_high_enough", "angle": 170, "severity": [166, 164] }
          ],
          "placement": "floor_side",
          "setupTipVi": "Đặt điện thoại nằm ngang trên sàn, cách 1,5–2 m, nhìn nghiêng người đang nằm. Camera cần thấy rõ vai, hông và gối."
        }
      }
    ]
  },
  "push-up": {
    "activeVersion": 1,
    "configs": [
      {
        "version": 1,
        "cameraPosition": "side",
        "config": {
          "joints": ["shoulder", "elbow", "wrist"],
          "downBelow": 110,
          "upAbove": 150,
          "minConfidence": 0.5,
          "minRepMs": 500,
          "orientation": { "joints": ["shoulder", "ankle"], "axis": "horizontal", "maxTiltDeg": 40 },
          "formRules": [
            { "type": "min_depth", "code": "pushup_not_deep_enough", "angle": 90, "severity": [100, 105] },
            { "type": "band", "code": "body_not_straight", "joints": ["shoulder", "hip", "ankle"], "min": 160, "max": 180, "severity": [10, 20] }
          ],
          "placement": "floor_side",
          "setupTipVi": "Đặt điện thoại nằm ngang trên sàn, cách 1,5–2 m, nhìn nghiêng. Cả người từ đầu tới bàn chân phải trong khung để kiểm tra thân thẳng."
        }
      }
    ]
  },
  "wall-push-up": {
    "activeVersion": 1,
    "configs": [
      {
        "version": 1,
        "cameraPosition": "side",
        "config": {
          "joints": ["shoulder", "elbow", "wrist"],
          "downBelow": 115,
          "upAbove": 150,
          "minConfidence": 0.5,
          "minRepMs": 500,
          "formRules": [
            { "type": "min_depth", "code": "pushup_not_deep_enough", "angle": 95, "severity": [105, 110] },
            { "type": "band", "code": "body_not_straight", "joints": ["shoulder", "hip", "ankle"], "min": 160, "max": 180, "severity": [10, 20] }
          ],
          "placement": "table_side",
          "setupTipVi": "Đặt điện thoại dựng đứng trên ghế hoặc bàn ngang hông, cách 2 m, nhìn nghiêng người và bức tường. Cả tay chống tường và bàn chân đều phải trong khung."
        }
      }
    ]
  },
  "jumping-jack": {
    "activeVersion": 1,
    "configs": [
      {
        "version": 1,
        "cameraPosition": "front",
        "config": {
          "joints": ["hip", "shoulder", "elbow"],
          "direction": "extend",
          "side": "both",
          "downBelow": 50,
          "upAbove": 110,
          "minConfidence": 0.5,
          "minRepMs": 200,
          "formRules": [
            { "type": "max_extreme", "code": "arms_not_overhead", "angle": 140, "severity": [125, 115] }
          ],
          "placement": "floor_front",
          "setupTipVi": "Dựng điện thoại đứng trên sàn hoặc ghế, cách 2,5–3 m, quay mặt về camera. Hai tay giơ lên vẫn phải nằm trong khung."
        }
      }
    ]
  },
  "dumbbell-shoulder-press": {
    "activeVersion": 1,
    "configs": [
      {
        "version": 1,
        "cameraPosition": "front",
        "config": {
          "joints": ["shoulder", "elbow", "wrist"],
          "direction": "extend",
          "side": "both",
          "downBelow": 110,
          "upAbove": 150,
          "minConfidence": 0.5,
          "minRepMs": 600,
          "formRules": [
            { "type": "max_extreme", "code": "press_not_locked_out", "angle": 165, "severity": [158, 153] }
          ],
          "placement": "table_front",
          "setupTipVi": "Đặt điện thoại dựng đứng ngang ngực, cách 2 m, quay mặt về camera. Tạ ở ngang vai khi bắt đầu; tay đẩy thẳng lên vẫn phải trong khung."
        }
      }
    ]
  },
  "dumbbell-biceps-curl": {
    "activeVersion": 1,
    "configs": [
      {
        "version": 1,
        "cameraPosition": "side",
        "config": {
          "joints": ["shoulder", "elbow", "wrist"],
          "downBelow": 70,
          "upAbove": 145,
          "minConfidence": 0.5,
          "minRepMs": 600,
          "formRules": [
            { "type": "min_depth", "code": "curl_not_full_range", "angle": 55, "severity": [62, 67] }
          ],
          "placement": "table_side",
          "setupTipVi": "Đặt điện thoại dựng đứng ngang hông, cách 2 m, nhìn nghiêng. Cuốn hai tay cùng lúc; nếu cuốn luân phiên, camera chỉ đếm tay ở gần."
        }
      }
    ]
  },
  "dumbbell-bent-over-row": {
    "activeVersion": 1,
    "configs": [
      {
        "version": 1,
        "cameraPosition": "side",
        "config": {
          "joints": ["shoulder", "elbow", "wrist"],
          "downBelow": 110,
          "upAbove": 150,
          "minConfidence": 0.5,
          "minRepMs": 600,
          "formRules": [
            { "type": "min_depth", "code": "row_not_high_enough", "angle": 95, "severity": [100, 105] }
          ],
          "placement": "floor_side",
          "setupTipVi": "Đặt điện thoại trên sàn hoặc ghế thấp, cách 2 m, nhìn nghiêng. Gập người về trước, tay cầm tạ ở phía gần camera."
        }
      }
    ]
  },
  "seated-resistance-band-row": {
    "activeVersion": 1,
    "configs": [
      {
        "version": 1,
        "cameraPosition": "side",
        "config": {
          "joints": ["shoulder", "elbow", "wrist"],
          "downBelow": 110,
          "upAbove": 150,
          "minConfidence": 0.5,
          "minRepMs": 600,
          "formRules": [
            { "type": "min_depth", "code": "row_not_high_enough", "angle": 95, "severity": [100, 105] }
          ],
          "placement": "floor_side",
          "setupTipVi": "Đặt điện thoại nằm ngang trên sàn, cách 1,5–2 m, nhìn nghiêng người đang ngồi. Kéo khuỷu tay ra sau sát thân, không để chân che tay."
        }
      }
    ]
  },
  "standing-calf-raise": {
    "activeVersion": 1,
    "configs": [
      {
        "version": 1,
        "cameraPosition": "side",
        "config": {
          "joints": ["knee", "ankle", "footIndex"],
          "direction": "extend",
          "downBelow": 125,
          "upAbove": 135,
          "minConfidence": 0.5,
          "minRepMs": 400,
          "formRules": [
            { "type": "max_extreme", "code": "heels_not_high_enough", "angle": 145, "severity": [140, 137] }
          ],
          "placement": "floor_side",
          "setupTipVi": "Đặt điện thoại trên sàn cách 1,5 m, nhìn nghiêng, đủ thấy rõ gối và bàn chân. Đi chân trần hoặc giày gọn, sàn đủ sáng."
        }
      }
    ]
  },
  "side-lying-leg-raise": {
    "activeVersion": 1,
    "configs": [
      {
        "version": 1,
        "cameraPosition": "front",
        "config": {
          "joints": ["shoulder", "hip", "knee"],
          "side": "min",
          "downBelow": 158,
          "upAbove": 168,
          "minConfidence": 0.5,
          "minRepMs": 600,
          "formRules": [
            { "type": "min_depth", "code": "leg_not_high_enough", "angle": 145, "severity": [150, 155] }
          ],
          "placement": "floor_front",
          "setupTipVi": "Đặt điện thoại nằm ngang trên sàn, cách 2 m, đối diện bụng bạn khi nằm nghiêng. Cả người từ vai tới bàn chân nằm ngang trong khung."
        }
      }
    ]
  },
  "plank": {
    "activeVersion": 1,
    "configs": [
      {
        "version": 1,
        "cameraPosition": "side",
        "config": {
          "mode": "hold",
          "joints": ["shoulder", "hip", "ankle"],
          "holdMin": 150,
          "holdMax": 180,
          "minConfidence": 0.5,
          "orientation": { "joints": ["shoulder", "ankle"], "axis": "horizontal", "maxTiltDeg": 35 },
          "formRules": [
            { "type": "band", "code": "body_not_straight", "min": 165, "max": 180, "minFraction": 0.1, "severity": [0.25, 0.5] }
          ],
          "placement": "floor_side",
          "setupTipVi": "Đặt điện thoại nằm ngang trên sàn, cách 1,5–2 m, nhìn nghiêng. Cả người từ vai tới cổ chân phải trong khung; đồng hồ chỉ chạy khi thân thẳng."
        }
      }
    ]
  },
  "wall-sit": {
    "activeVersion": 1,
    "configs": [
      {
        "version": 1,
        "cameraPosition": "side",
        "config": {
          "mode": "hold",
          "joints": ["hip", "knee", "ankle"],
          "holdMin": 65,
          "holdMax": 120,
          "minConfidence": 0.5,
          "formRules": [
            { "type": "band", "code": "knee_not_at_90", "min": 80, "max": 100, "minFraction": 0.1, "severity": [0.25, 0.5] }
          ],
          "placement": "floor_side",
          "setupTipVi": "Đặt điện thoại dựng đứng trên sàn, cách 2 m, nhìn nghiêng người và bức tường. Đồng hồ chỉ chạy khi gối gập gần 90°."
        }
      }
    ]
  },
  "dead-bug": {
    "activeVersion": 1,
    "configs": [
      {
        "version": 1,
        "cameraPosition": "side",
        "config": {
          "mode": "alternating",
          "joints": [
            "hip",
            "knee",
            "ankle"
          ],
          "direction": "extend",
          "side": "auto",
          "downBelow": 110,
          "upAbove": 155,
          "minConfidence": 0.5,
          "minRepMs": 600,
          "formRules": [
            {
              "type": "max_extreme",
              "code": "leg_not_extended",
              "angle": 165,
              "severity": [
                160,
                155
              ]
            }
          ],
          "placement": "floor_side",
          "setupTipVi": "Đặt điện thoại thấp trên sàn cách 2–3 m, nhìn ngang hơi chéo để thấy cả hai gối và cổ chân. Nằm ngửa, duỗi chân đối bên tay rồi thu về; mỗi bên là một lần. Tránh để chân gần che chân xa.",
          "orientation": {
            "joints": [
              "shoulder",
              "hip"
            ],
            "axis": "horizontal",
            "maxTiltDeg": 40
          }
        }
      }
    ]
  },
  "bird-dog": {
    "activeVersion": 1,
    "configs": [
      {
        "version": 1,
        "cameraPosition": "side",
        "config": {
          "mode": "alternating",
          "joints": [
            "shoulder",
            "hip",
            "knee"
          ],
          "direction": "extend",
          "side": "auto",
          "downBelow": 115,
          "upAbove": 155,
          "minConfidence": 0.5,
          "minRepMs": 600,
          "formRules": [
            {
              "type": "max_extreme",
              "code": "leg_not_extended",
              "angle": 165,
              "severity": [
                160,
                155
              ]
            }
          ],
          "placement": "floor_side",
          "setupTipVi": "Đặt điện thoại trên sàn cách 2–3 m, nhìn ngang hơi chéo tư thế quỳ bốn điểm để thấy cả hai bên. Duỗi tay và chân đối bên rồi thu về; giữ hông ổn định, không xoay thân.",
          "orientation": {
            "joints": [
              "shoulder",
              "hip"
            ],
            "axis": "horizontal",
            "maxTiltDeg": 40
          }
        }
      }
    ]
  },
  "march-in-place": {
    "activeVersion": 1,
    "configs": [
      {
        "version": 1,
        "cameraPosition": "side",
        "config": {
          "mode": "active",
          "joints": [
            "hip",
            "knee",
            "ankle"
          ],
          "direction": "flex",
          "side": "min",
          "downBelow": 115,
          "upAbove": 155,
          "minConfidence": 0.5,
          "minRepMs": 200,
          "formRules": [
            {
              "type": "band",
              "code": "torso_leaning",
              "joints": [
                "shoulder",
                "hip",
                "knee"
              ],
              "min": 65,
              "max": 180,
              "minFraction": 0.1,
              "severity": [
                0.25,
                0.5
              ]
            }
          ],
          "placement": "floor_side",
          "setupTipVi": "Đặt điện thoại dựng đứng trên sàn cách 2–3 m, nhìn ngang hơi chéo để thấy cả hai chân. Nâng gối xen kẽ rõ ràng; đồng hồ chạy sau chu kỳ đầu và dừng sau khoảng 2 giây không có chu kỳ mới.",
          "orientation": {
            "joints": [
              "shoulder",
              "hip"
            ],
            "axis": "vertical",
            "maxTiltDeg": 40
          }
        }
      }
    ]
  },
  "step-jack": {
    "activeVersion": 1,
    "configs": [
      {
        "version": 1,
        "cameraPosition": "front",
        "config": {
          "mode": "active",
          "joints": [
            "hip",
            "shoulder",
            "elbow"
          ],
          "direction": "extend",
          "side": "both",
          "downBelow": 45,
          "upAbove": 100,
          "minConfidence": 0.5,
          "minRepMs": 200,
          "formRules": [
            {
              "type": "band",
              "code": "arms_not_straight",
              "joints": [
                "shoulder",
                "elbow",
                "wrist"
              ],
              "min": 150,
              "max": 180,
              "minFraction": 0.1,
              "severity": [
                0.25,
                0.5
              ]
            }
          ],
          "placement": "floor_front",
          "setupTipVi": "Đặt điện thoại trên sàn cách 2–3 m, nhìn chính diện toàn thân. Bước ngang xen kẽ, đưa tay lên rồi hạ tay rõ ràng; đồng hồ dừng sau khoảng 2 giây không có chu kỳ mới.",
          "orientation": {
            "joints": [
              "hip",
              "shoulder"
            ],
            "axis": "vertical",
            "maxTiltDeg": 40
          }
        }
      }
    ]
  },
  "dumbbell-floor-press": {
    "activeVersion": 1,
    "configs": [
      {
        "version": 1,
        "cameraPosition": "side",
        "config": {
          "mode": "reps",
          "joints": [
            "shoulder",
            "elbow",
            "wrist"
          ],
          "direction": "extend",
          "side": "auto",
          "downBelow": 110,
          "upAbove": 150,
          "minConfidence": 0.5,
          "minRepMs": 600,
          "formRules": [
            {
              "type": "max_extreme",
              "code": "press_not_locked_out",
              "angle": 165,
              "severity": [
                160,
                155
              ]
            }
          ],
          "placement": "floor_side",
          "setupTipVi": "Đặt điện thoại thấp sát sàn, cách 1,5–2 m, nhìn ngang người nằm ngửa. Camera cần thấy rõ vai, khuỷu và cổ tay phía gần; hạ tạ có kiểm soát rồi đẩy lên, tránh để tạ che khuỷu.",
          "orientation": {
            "joints": [
              "shoulder",
              "hip"
            ],
            "axis": "horizontal",
            "maxTiltDeg": 40
          }
        }
      }
    ]
  }
}
''';
