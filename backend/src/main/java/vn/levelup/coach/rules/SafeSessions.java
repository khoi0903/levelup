package vn.levelup.coach.rules;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

import org.bson.types.ObjectId;
import vn.levelup.training.model.Exercise;
import vn.levelup.training.model.TrainingPlan;
import vn.levelup.training.rules.ExerciseFilter;


/**
 * Luật thuần đổi buổi tập cho an toàn (không đọc hay ghi database):
 * thay bài vi phạm chấn thương bằng bài an toàn gần giống nhất, áp dụng thay đổi coach đề xuất.
 * Coach và tổng kết tuần dùng chung.
 */
public final class SafeSessions {

    private SafeSessions() {}

    /** Bài còn dùng, không chống chỉ định với vùng đang đau và tập được với dụng cụ người dùng có. */
    public static boolean isSafe(Exercise e, String location, Set<String> equipment, Set<String> injuries) {
        return e != null && !Boolean.FALSE.equals(e.isActive())
            && !ExerciseFilter.forUser(List.of(e), location, equipment, injuries).isEmpty();
    }

    /** Danh sách bài an toàn với người dùng. */
    public static List<Exercise> safeList(Collection<Exercise> active, String location, Set<String> equipment,
                                          Set<String> injuries) {
        return ExerciseFilter.forUser(active.stream().filter(e -> !Boolean.FALSE.equals(e.isActive())).toList(),
            location, equipment, injuries);
    }

    /**
     * Bài thay thế: ưu tiên cùng nhóm cơ, cùng kiểu đếm, độ khó gần nhất; hòa thì theo id để kết quả cố định.
     * @param unsafe bài cần thay, có thể null (bài không còn trong thư viện)
     */
    public static Optional<Exercise> substitute(Exercise unsafe, List<Exercise> safe, Set<String> exclude) {
        String muscle = unsafe == null ? null : unsafe.primaryMuscle();
        String tracking = unsafe == null ? null : unsafe.tracking();
        int difficulty = unsafe == null ? 1 : unsafe.difficultyOrDefault();
        return safe.stream()
            .filter(e -> !exclude.contains(e.id()))
            .filter(e -> unsafe == null || !e.id().equals(unsafe.id()))
            .min(Comparator
                .comparingInt((Exercise e) -> muscle != null && muscle.equals(e.primaryMuscle()) ? 0 : 1)
                .thenComparingInt(e -> tracking != null && tracking.equals(e.tracking()) ? 0 : 1)
                .thenComparingInt(e -> Math.abs(e.difficultyOrDefault() - difficulty))
                .thenComparing(Exercise::id));
    }

    /** Động tác mới giữ số hiệp và thời gian nghỉ, đổi số lần hoặc số giây theo kiểu đếm của bài mới. */
    public static TrainingPlan.Item replaceItem(TrainingPlan.Item old, Exercise to) {
        boolean timed = "duration".equals(to.tracking());
        Integer reps = timed ? null : old.targetReps() != null ? old.targetReps() : 10;
        Integer duration = timed ? old.targetDurationSec() != null ? old.targetDurationSec() : 30 : null;
        return new TrainingPlan.Item(new ObjectId(to.id()), old.targetSets(), reps, duration, old.restSec());
    }

    /**
     * Thay mọi động tác không an toàn. Không tìm được bài thay thì bỏ động tác đó.
     * @param byId mọi bài trong thư viện theo id
     * @param safe bài an toàn với người dùng
     */
    public static List<TrainingPlan.Item> makeSafe(List<TrainingPlan.Item> items, Map<String, Exercise> byId,
                                                   List<Exercise> safe) {
        if (items == null) {
            return List.of();
        }
        Set<String> safeIds = safe.stream().map(Exercise::id).collect(Collectors.toSet());
        Set<String> used = items.stream().map(i -> i.exerciseId().toHexString())
            .filter(safeIds::contains).collect(Collectors.toCollection(HashSet::new));
        List<TrainingPlan.Item> result = new ArrayList<>();
        for (TrainingPlan.Item item : items) {
            String id = item.exerciseId().toHexString();
            if (safeIds.contains(id)) {
                result.add(item);
                continue;
            }
            substitute(byId.get(id), safe, used).ifPresent(to -> {
                used.add(to.id());
                result.add(replaceItem(item, to));
            });
        }
        return result;
    }

    /** Động tác không an toàn trong buổi, theo thứ tự trong buổi. */
    public static List<String> unsafeExerciseIds(TrainingPlan.Session session, List<Exercise> safe) {
        Set<String> safeIds = safe.stream().map(Exercise::id).collect(Collectors.toSet());
        return session.items() == null ? List.of() : session.items().stream()
            .map(i -> i.exerciseId().toHexString())
            .filter(id -> !safeIds.contains(id))
            .toList();
    }

    /**
     * Buổi tập sau khi áp dụng thay đổi coach đề xuất, rồi thay mọi bài không an toàn còn lại.
     * light: bớt 1 hiệp mỗi bài; quick5: 3 bài đầu, 1 hiệp, 5 phút; swap_exercise: đổi một bài; rest: nghỉ.
     * Không còn bài nào tập được thì buổi thành nghỉ.
     */
    public static TrainingPlan.Session applyChange(TrainingPlan.Session s, String change, String fromExerciseId,
                                                   Exercise to, String reasonCode, Map<String, Exercise> byId,
                                                   List<Exercise> safe) {
        List<TrainingPlan.Item> items = s.items() == null ? List.of() : s.items();
        String variant = s.variant() == null ? "normal" : s.variant();
        Integer duration = s.durationMin();
        String status = s.status();
        switch (change) {
            case "light" -> {
                items = items.stream().map(i -> new TrainingPlan.Item(i.exerciseId(),
                    i.targetSets() == null ? null : Math.max(1, i.targetSets() - 1),
                    i.targetReps(), i.targetDurationSec(), i.restSec())).toList();
                variant = "light";
            }
            case "quick5" -> {
                items = items.stream().limit(3).map(i -> new TrainingPlan.Item(i.exerciseId(), 1,
                    i.targetReps(), i.targetDurationSec(), i.restSec())).toList();
                variant = "quick5";
                duration = 5;
            }
            case "swap_exercise" -> items = items.stream()
                .map(i -> i.exerciseId().toHexString().equals(fromExerciseId) && to != null ? replaceItem(i, to) : i)
                .toList();
            case "rest" -> status = "rest";
            default -> throw new IllegalArgumentException("change không hợp lệ: " + change);
        }
        if (!"rest".equals(status)) {
            items = makeSafe(items, byId, safe);
            if (items.isEmpty()) {
                status = "rest";
            }
        }
        return new TrainingPlan.Session(s.id(), s.scheduledDate(), s.scheduledTime(), s.title(), duration,
            variant, status, items, reasonCode);
    }
}
