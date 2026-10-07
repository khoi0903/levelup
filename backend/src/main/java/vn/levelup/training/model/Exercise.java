package vn.levelup.training.model;

import java.util.List;
import java.util.Map;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

/** Collection "exercises". Tên trường khớp validator trong mongo/init.js. */
@Document("exercises")
public record Exercise(
    @Id String id,
    String slug,
    String nameVi,
    String nameEn,
    String instructions,
    List<String> cues,
    String videoUrl,
    String thumbnailUrl,
    String primaryMuscle,
    Integer difficulty,
    String tracking,          // reps | reps_weight | duration
    Double met,
    List<String> equipment,   // rỗng = không cần dụng cụ
    List<String> contraindications,
    Cv cv,
    Boolean isActive
) {
    public record Cv(Boolean supported, Integer activeVersion, List<CvConfig> configs) {}

    public record CvConfig(Integer version, String cameraPosition, Map<String, Object> config) {}

    public List<String> equipmentOrEmpty() {
        return equipment == null ? List.of() : equipment;
    }

    public List<String> contraindicationsOrEmpty() {
        return contraindications == null ? List.of() : contraindications;
    }

    public int difficultyOrDefault() {
        return difficulty == null ? 3 : difficulty;
    }
}
