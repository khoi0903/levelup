class ExerciseCamera {
  final int? version;
  final String? cameraPosition;
  final Map<String, dynamic>? config;

  const ExerciseCamera({this.version, this.cameraPosition, this.config});

  factory ExerciseCamera.fromJson(Map<String, dynamic> json) {
    return ExerciseCamera(
      version: (json['version'] as num?)?.toInt(),
      cameraPosition: json['cameraPosition'] as String?,
      config: json['config'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (version != null) 'version': version,
    if (cameraPosition != null) 'cameraPosition': cameraPosition,
    if (config != null) 'config': config,
  };
}

class ExerciseResponse {
  final String id;
  final String slug;
  final String nameVi;
  final String? instructions;
  final List<String> cues;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? primaryMuscle;
  final int? difficulty;
  final String? tracking;
  final List<String> equipment;
  final ExerciseCamera? camera;

  const ExerciseResponse({
    required this.id,
    required this.slug,
    required this.nameVi,
    this.instructions,
    this.cues = const [],
    this.videoUrl,
    this.thumbnailUrl,
    this.primaryMuscle,
    this.difficulty,
    this.tracking,
    this.equipment = const [],
    this.camera,
  });

  factory ExerciseResponse.fromJson(Map<String, dynamic> json) {
    return ExerciseResponse(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      nameVi: json['nameVi']?.toString() ?? '',
      instructions: json['instructions'] as String?,
      cues:
          (json['cues'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      videoUrl: json['videoUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      primaryMuscle: json['primaryMuscle'] as String?,
      difficulty: (json['difficulty'] as num?)?.toInt(),
      tracking: json['tracking'] as String?,
      equipment:
          (json['equipment'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      camera: json['camera'] != null
          ? ExerciseCamera.fromJson(json['camera'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'nameVi': nameVi,
    if (instructions != null) 'instructions': instructions,
    'cues': cues,
    if (videoUrl != null) 'videoUrl': videoUrl,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    if (primaryMuscle != null) 'primaryMuscle': primaryMuscle,
    if (difficulty != null) 'difficulty': difficulty,
    if (tracking != null) 'tracking': tracking,
    'equipment': equipment,
    if (camera != null) 'camera': camera!.toJson(),
  };
}
