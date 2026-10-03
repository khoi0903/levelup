package vn.levelup.motivation;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

import org.bson.types.ObjectId;

import vn.levelup.exercises.Exercise;
import vn.levelup.plans.SessionRules;
import vn.levelup.plans.TrainingPlan;

/**
 * Bảng "Lý do → API làm gì" của F3, không đọc hay ghi database, để unit test.
 * Chỉ sửa các buổi còn planned từ hôm nay tới hết tuần của kế hoạch.
 */
public final class SkipPlanner {

    static final int BUSY_MINUTES = 10;
    static final int SUGGESTED_PRE_WORKOUT_MINUTES = 60;
    private static final Comparator<TrainingPlan.Session> BY_TIME = Comparator
        .comparing(TrainingPlan.Session::scheduledDate)
        .thenComparing(s -> s.scheduledTime() == null ? "" : s.scheduledTime());

    private SkipPlanner() {}

    /**
     * @param action  giá trị skip_reports.action
     * @param changed các buổi đã sửa (bản đầy đủ), theo thứ tự trong kế hoạch
     */
    public record Outcome(String action, List<TrainingPlan.Session> changed, Map<String, Object> suggestion) {}

    /**
     * @param catalog bài đang dùng trong kế hoạch, theo id (để biết chống chỉ định, nhóm cơ)
     * @param safe    bài an toàn với người dùng (đã tính cả vùng đau mới), dùng để thay bài
     */
    public static Outcome plan(String reason, List<TrainingPlan.Session> sessions, LocalDate today,
                               LocalDate weekStart, ObjectId plannedSessionId, String bodyArea,
                               Map<String, Exercise> catalog, List<Exercise> safe) {
        List<TrainingPlan.Session> remaining = sessions.stream()
            .filter(s -> "planned".equals(s.status()) && !LocalDate.parse(s.scheduledDate()).isBefore(today))
            .sorted(BY_TIME)
            .toList();
        return switch (reason) {
            case "busy" -> busy(sessions, remaining, weekStart, plannedSessionId);
            case "tired" -> changed("reduced_intensity", remaining.stream().map(SkipPlanner::lighter).toList());
            case "pain" -> swapped(remaining.stream()
                .map(s -> withoutArea(s, bodyArea, catalog, safe)).toList(), remaining);
            case "bored" -> swapped(remaining.stream().map(s -> rotated(s, catalog, safe)).toList(), remaining);
            case "forgot" -> new Outcome("changed_reminder", List.of(),
                Map.of("preWorkoutMinutes", SUGGESTED_PRE_WORKOUT_MINUTES));
            default -> new Outcome("none", List.of(), null);
        };
    }

    /** Rút buổi tối nay (hoặc buổi kế tiếp) còn 10 phút, dời buổi sau đó sang ngày trống tiếp theo trong tuần. */
    static Outcome busy(List<TrainingPlan.Session> all, List<TrainingPlan.Session> remaining, LocalDate weekStart,
                        ObjectId plannedSessionId) {
        if (remaining.isEmpty()) {
            return new Outcome("none", List.of(), null);
        }
        TrainingPlan.Session target = remaining.stream().filter(s -> s.id().equals(plannedSessionId))
            .findFirst().orElse(remaining.getFirst());
        List<TrainingPlan.Item> items = SessionRules.fit(target.items() == null ? List.of() : target.items(),
            BUSY_MINUTES * 60, null);
        int minutes = target.durationMin() == null ? BUSY_MINUTES : Math.min(target.durationMin(), BUSY_MINUTES);
        List<TrainingPlan.Session> changed = new ArrayList<>();
        changed.add(copy(target, target.scheduledDate(), minutes, target.variant(), target.status(), items,
            "skip_busy"));

        remaining.stream().filter(s -> s != target && BY_TIME.compare(s, target) >= 0).findFirst()
            .ifPresent(next -> {
                Set<String> taken = all.stream().map(TrainingPlan.Session::scheduledDate).collect(Collectors.toSet());
                LocalDate weekEnd = weekStart.plusDays(6);
                for (LocalDate d = LocalDate.parse(next.scheduledDate()).plusDays(1); !d.isAfter(weekEnd);
                     d = d.plusDays(1)) {
                    if (!taken.contains(d.toString())) {
                        changed.add(copy(next, d.toString(), next.durationMin(), next.variant(), next.status(),
                            next.items(), "skip_busy"));
                        break;
                    }
                }
            });
        return new Outcome("shortened", changed, null);
    }

    /** Bản nhẹ: bớt 1 hiệp mỗi bài (tối thiểu 1). */
    static TrainingPlan.Session lighter(TrainingPlan.Session s) {
        List<TrainingPlan.Item> items = s.items() == null ? List.of() : s.items().stream()
            .map(i -> new TrainingPlan.Item(i.exerciseId(),
                i.targetSets() == null ? null : Math.max(1, i.targetSets() - 1),
                i.targetReps(), i.targetDurationSec(), i.restSec()))
            .toList();
        return copy(s, s.scheduledDate(), s.durationMin(), "light", s.status(), items, "skip_tired");
    }

    /** Thay bài có chống chỉ định trùng vùng đau; không bao giờ để buổi rỗng (không còn bài an toàn thì nghỉ). */
    static TrainingPlan.Session withoutArea(TrainingPlan.Session s, String area, Map<String, Exercise> catalog,
                                            List<Exercise> safe) {
        List<TrainingPlan.Item> items = s.items() == null ? List.of() : s.items();
        Set<String> used = items.stream().map(i -> i.exerciseId().toHexString()).collect(Collectors.toSet());
        List<TrainingPlan.Item> result = new ArrayList<>();
        boolean touched = false;
        for (TrainingPlan.Item item : items) {
            Exercise current = catalog.get(item.exerciseId().toHexString());
            if (current == null || !current.contraindicationsOrEmpty().contains(area)) {
                result.add(item);
                continue;
            }
            touched = true;
            Exercise replacement = pick(safe, used, current.primaryMuscle(), null);
            if (replacement == null) {
                replacement = pick(safe, used, null, null);
            }
            if (replacement != null) {
                used.add(replacement.id());
                result.add(replace(item, replacement));
            }
        }
        if (!touched) {
            return s;
        }
        String reason = "pain_" + area;
        if (result.isEmpty()) {
            Exercise any = pick(safe, Set.of(), null, null);
            if (any == null) {
                return copy(s, s.scheduledDate(), s.durationMin(), s.variant(), "rest", items, reason);
            }
            result.add(replace(items.getFirst(), any));
        }
        return copy(s, s.scheduledDate(), s.durationMin(), s.variant(), s.status(), result, reason);
    }

    /** Đổi mỗi bài sang bài khác cùng nhóm cơ (theo vòng, để lần sau lại đổi tiếp). */
    static TrainingPlan.Session rotated(TrainingPlan.Session s, Map<String, Exercise> catalog, List<Exercise> safe) {
        List<TrainingPlan.Item> items = s.items() == null ? List.of() : s.items();
        Set<String> used = items.stream().map(i -> i.exerciseId().toHexString()).collect(Collectors.toSet());
        List<TrainingPlan.Item> result = new ArrayList<>();
        boolean touched = false;
        for (TrainingPlan.Item item : items) {
            Exercise current = catalog.get(item.exerciseId().toHexString());
            Exercise next = current == null ? null : pick(safe, used, current.primaryMuscle(), current.id());
            if (next == null) {
                result.add(item);
                continue;
            }
            touched = true;
            used.add(next.id());
            result.add(replace(item, next));
        }
        return touched ? copy(s, s.scheduledDate(), s.durationMin(), s.variant(), s.status(), result, "skip_bored")
            : s;
    }

    /**
     * Bài an toàn chưa dùng trong buổi, đúng nhóm cơ nếu có; sắp theo id, lấy bài đầu tiên sau {@code after}
     * (theo vòng) để kết quả cố định.
     */
    static Exercise pick(List<Exercise> safe, Set<String> used, String muscle, String after) {
        List<Exercise> candidates = safe.stream()
            .filter(e -> !used.contains(e.id()))
            .filter(e -> muscle == null || muscle.equals(e.primaryMuscle()))
            .sorted(Comparator.comparing(Exercise::id))
            .toList();
        if (candidates.isEmpty()) {
            return null;
        }
        if (after != null) {
            for (Exercise e : candidates) {
                if (e.id().compareTo(after) > 0) {
                    return e;
                }
            }
        }
        return candidates.getFirst();
    }

    private static TrainingPlan.Item replace(TrainingPlan.Item old, Exercise e) {
        boolean timed = "duration".equals(e.tracking());
        Integer reps = old.targetReps() != null ? old.targetReps() : 10;
        Integer duration = old.targetDurationSec() != null ? old.targetDurationSec() : 30;
        return new TrainingPlan.Item(new ObjectId(e.id()), old.targetSets(), timed ? null : reps,
            timed ? duration : null, old.restSec());
    }

    private static Outcome changed(String action, List<TrainingPlan.Session> sessions) {
        return sessions.isEmpty() ? new Outcome("none", List.of(), null) : new Outcome(action, sessions, null);
    }

    private static Outcome swapped(List<TrainingPlan.Session> result, List<TrainingPlan.Session> before) {
        Map<ObjectId, TrainingPlan.Session> original = new LinkedHashMap<>();
        before.forEach(s -> original.put(s.id(), s));
        List<TrainingPlan.Session> changed = result.stream()
            .filter(s -> !Objects.equals(s, original.get(s.id())))
            .toList();
        return changed.isEmpty() ? new Outcome("none", List.of(), null)
            : new Outcome("swapped_exercises", changed, null);
    }

    private static TrainingPlan.Session copy(TrainingPlan.Session s, String date, Integer durationMin,
                                             String variant, String status, List<TrainingPlan.Item> items,
                                             String reason) {
        return new TrainingPlan.Session(s.id(), date, s.scheduledTime(), s.title(), durationMin, variant, status,
            items, reason);
    }

    /** Vùng đau đang có trong users.injuries (active). */
    public static Set<String> withArea(Set<String> activeInjuries, String area) {
        Set<String> all = new HashSet<>(activeInjuries);
        if (area != null) {
            all.add(area);
        }
        return all;
    }
}
