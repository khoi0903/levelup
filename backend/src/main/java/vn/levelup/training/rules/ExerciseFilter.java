package vn.levelup.training.rules;

import java.util.Collection;
import java.util.List;
import java.util.Set;
import vn.levelup.training.model.Exercise;

/**
 * Lọc bài tập an toàn và tập được với dụng cụ người dùng có.
 * - Bỏ bài có chống chỉ định trùng vùng đang đau.
 * - Tập ở phòng gym: coi như có đủ dụng cụ.
 * - Thảm (mat) không bắt buộc: không có thảm vẫn tập trên sàn được.
 */
public final class ExerciseFilter {

    /** Nhóm bài giãn cơ / vận động nhẹ: chỉ dùng khi người dùng tự chọn hoặc tập nhẹ, không xếp vào kế hoạch. */
    public static final String MOBILITY = "mobility";

    private ExerciseFilter() {}

    public static boolean isMobility(Exercise e) {
        return MOBILITY.equals(e.primaryMuscle());
    }

    public static List<Exercise> forUser(Collection<Exercise> all, String location,
                                         Set<String> userEquipment, Set<String> activeInjuries) {
        boolean gym = "gym".equals(location);
        return all.stream()
            .filter(e -> e.contraindicationsOrEmpty().stream().noneMatch(activeInjuries::contains))
            .filter(e -> gym || e.equipmentOrEmpty().stream()
                .filter(item -> !"mat".equals(item))
                .allMatch(userEquipment::contains))
            .toList();
    }
}
