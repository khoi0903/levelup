package vn.levelup.training.rules;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Gom số hiệp theo nhóm cơ cho GET /me/muscles/week. Không đọc hay ghi database. */
public final class MuscleRules {

    /** Bảy nhóm cơ app hiển thị, đúng thứ tự trả về. */
    public static final List<String> GROUPS = List.of("chest", "back", "shoulders", "arms", "abs", "glutes", "legs");

    private MuscleRules() {}

    /** exercises.primaryMuscle → nhóm cơ hiển thị; cardio, mobility và giá trị lạ trả null (bỏ qua). */
    public static String group(String primaryMuscle) {
        if (primaryMuscle == null) {
            return null;
        }
        return switch (primaryMuscle) {
            case "chest", "back", "shoulders", "arms", "glutes", "legs" -> primaryMuscle;
            case "core" -> "abs";
            default -> null;
        };
    }

    /** Đếm số hiệp mỗi nhóm; luôn đủ 7 khoá, nhóm chưa tập là 0. Mỗi phần tử là primaryMuscle của một hiệp. */
    public static Map<String, Integer> countSets(List<String> primaryMuscleOfEachSet) {
        Map<String, Integer> counts = new LinkedHashMap<>();
        GROUPS.forEach(g -> counts.put(g, 0));
        for (String muscle : primaryMuscleOfEachSet) {
            String g = group(muscle);
            if (g != null) {
                counts.merge(g, 1, Integer::sum);
            }
        }
        return counts;
    }
}
