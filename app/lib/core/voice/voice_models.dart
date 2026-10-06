enum VoiceLineKey {
  startCountdown('start_countdown'),
  go('go'),
  rep('rep'),
  almostDone('almost_done'),
  lastRep('last_rep'),
  setDone('set_done'),
  restStart('rest_start'),
  restEnding('rest_ending'),
  holdRemaining('hold_remaining'),
  holdLast('hold_last'),
  formGeneric('form_generic'),
  lostPerson('lost_person'),
  exerciseNext('exercise_next'),
  workoutDone('workout_done'),
  personalRecord('personal_record');

  final String key;
  const VoiceLineKey(this.key);

  static VoiceLineKey? fromString(String key) {
    for (final v in values) {
      if (v.key == key) return v;
    }
    return null;
  }
}

enum VoiceSpeed {
  slow(0.85, 'Chậm'),
  normal(1.0, 'Vừa'),
  fast(1.15, 'Nhanh');

  final double multiplier;
  final String labelVi;
  const VoiceSpeed(this.multiplier, this.labelVi);

  static VoiceSpeed fromString(String? val) {
    return switch (val) {
      'slow' => VoiceSpeed.slow,
      'fast' => VoiceSpeed.fast,
      _ => VoiceSpeed.normal,
    };
  }
}

class VoiceStyle {
  final String id;
  final String nameVi;
  final String descriptionVi;
  final double rate;
  final double pitch;
  final int countEvery;
  final Map<String, List<String>> lines;

  const VoiceStyle({
    required this.id,
    required this.nameVi,
    required this.descriptionVi,
    this.rate = 0.5,
    this.pitch = 1.0,
    this.countEvery = 1,
    this.lines = const {},
  });

  factory VoiceStyle.fromJson(String id, Map<String, dynamic> json) {
    final rawLines = json['lines'] as Map<String, dynamic>? ?? {};
    final parsedLines = <String, List<String>>{};
    rawLines.forEach((k, v) {
      if (v is List) {
        parsedLines[k] = v.map((e) => e.toString()).toList();
      }
    });

    return VoiceStyle(
      id: id,
      nameVi: json['nameVi'] as String? ?? id,
      descriptionVi: json['descriptionVi'] as String? ?? '',
      rate: (json['rate'] as num?)?.toDouble() ?? 0.5,
      pitch: (json['pitch'] as num?)?.toDouble() ?? 1.0,
      countEvery: (json['countEvery'] as num?)?.toInt() ?? 1,
      lines: parsedLines,
    );
  }
}

class VoiceSettings {
  final bool enabled;

  /// 'coach' (mặc định) hoặc một trong 7 phong cách:
  /// supportive, strict, funny, calm, hype, genz, minimal
  final String selectedStyleId;
  final VoiceSpeed speed;

  /// Tắt tiếng tạm thời khi đang tập (qua nút loa ở màn hình tập)
  final bool mutedTemporarily;

  /// Đọc mẹo kỹ thuật khi bắt đầu bài tập mới (mặc định bật)
  final bool readStartTip;

  const VoiceSettings({
    this.enabled = true,
    this.selectedStyleId = 'coach',
    this.speed = VoiceSpeed.normal,
    this.mutedTemporarily = false,
    this.readStartTip = true,
  });

  bool get effectiveActive => enabled && !mutedTemporarily;

  VoiceSettings copyWith({
    bool? enabled,
    String? selectedStyleId,
    VoiceSpeed? speed,
    bool? mutedTemporarily,
    bool? readStartTip,
  }) {
    return VoiceSettings(
      enabled: enabled ?? this.enabled,
      selectedStyleId: selectedStyleId ?? this.selectedStyleId,
      speed: speed ?? this.speed,
      mutedTemporarily: mutedTemporarily ?? this.mutedTemporarily,
      readStartTip: readStartTip ?? this.readStartTip,
    );
  }
}

class FormIssueCue {
  final List<String> cue;
  final List<String> minimal;

  const FormIssueCue({
    this.cue = const [],
    this.minimal = const [],
  });

  factory FormIssueCue.fromJson(Map<String, dynamic> json) {
    final rawCue = json['cue'];
    final rawMinimal = json['minimal'];
    return FormIssueCue(
      cue: rawCue is List ? rawCue.map((e) => e.toString()).toList() : const [],
      minimal: rawMinimal is List ? rawMinimal.map((e) => e.toString()).toList() : const [],
    );
  }
}

class ExerciseFormCues {
  final List<String> startTip;
  final Map<String, FormIssueCue> issues;

  const ExerciseFormCues({
    this.startTip = const [],
    this.issues = const {},
  });

  factory ExerciseFormCues.fromJson(Map<String, dynamic> json) {
    final rawStartTip = json['startTip'];
    final rawIssues = json['issues'];
    final parsedIssues = <String, FormIssueCue>{};
    if (rawIssues is Map) {
      rawIssues.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          parsedIssues[k.toString()] = FormIssueCue.fromJson(v);
        } else if (v is Map) {
          parsedIssues[k.toString()] = FormIssueCue.fromJson(Map<String, dynamic>.from(v));
        }
      });
    }
    return ExerciseFormCues(
      startTip: rawStartTip is List ? rawStartTip.map((e) => e.toString()).toList() : const [],
      issues: parsedIssues,
    );
  }
}

