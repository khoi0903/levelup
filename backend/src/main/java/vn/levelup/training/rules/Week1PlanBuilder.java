package vn.levelup.training.rules;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.bson.types.ObjectId;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.model.Exercise;
import vn.levelup.training.model.TrainingPlan;


/**
 * Kế hoạch tuần 1 bằng luật cố định (chưa dùng AI): 3 buổi ngắn 10–15 phút
 * vào những ngày người dùng rảnh, bài dễ trước. Tuần đầu cố ý nhẹ hơn sức người dùng.
 */
public final class Week1PlanBuilder {

    static final int MAX_SESSIONS = 3;
    static final int SETS = 2;
    static final int REPS = 10;
    static final int DURATION_SEC = 30;
    static final int REST_SEC = 45;

    private static final String[] TITLES = {"Toàn thân cơ bản", "Cardio nhẹ + core", "Toàn thân + giãn cơ"};
    private static final List<Set<String>> FOCUS = List.of(
        Set.of("legs", "glutes", "chest", "back", "full_body"),
        Set.of("cardio", "core"),
        Set.of("full_body", "legs", "shoulders", "arms", "core"));
    private static final Map<String, String> SLOT_TIME = Map.of(
        "early_morning", "06:00", "noon", "12:00", "evening", "18:30", "late_evening", "20:30");

    private Week1PlanBuilder() {}

    public record Draft(LocalDate weekStart, List<TrainingPlan.Session> sessions) {}

    /**
     * @param availability ngày rảnh (1 = Thứ Hai ... 7 = Chủ nhật) kèm khung giờ
     * @param safeExercises bài đã lọc theo dụng cụ và chấn thương
     */
    public static Draft build(LocalDate today, Map<Integer, String> availability, int sessionMinutes,
                              List<Exercise> safeExercises) {
        Map<Integer, String> days = availability.isEmpty()
            ? new LinkedHashMap<>(Map.of(1, "evening", 3, "evening", 5, "evening"))
            : availability;

        LocalDate weekStart = LocalDates.weekStart(today);
        List<LocalDate> dates = pickDates(weekStart, today, days);
        if (dates.isEmpty()) {                       // hết ngày rảnh trong tuần này: lập cho tuần sau
            weekStart = weekStart.plusWeeks(1);
            dates = pickDates(weekStart, today, days);
        }

        int minutes = Math.max(10, Math.min(15, sessionMinutes));
        int exercisesPerSession = Math.max(4, Math.min(6, minutes / 2 - 1));
        List<Exercise> easyFirst = safeExercises.stream()
            .sorted(Comparator.comparingInt(Exercise::difficultyOrDefault))
            .toList();

        List<TrainingPlan.Session> sessions = new ArrayList<>();
        for (int i = 0; i < dates.size(); i++) {
            LocalDate date = dates.get(i);
            String time = SLOT_TIME.get(days.get(date.getDayOfWeek().getValue()));
            sessions.add(new TrainingPlan.Session(
                new ObjectId(), date.toString(), time, TITLES[i % TITLES.length], minutes,
                "normal", "planned", pickItems(easyFirst, FOCUS.get(i % FOCUS.size()), exercisesPerSession)));
        }
        return new Draft(weekStart, sessions);
    }

    /**
     * Bài cho một buổi đã có tên/thời lượng (dùng khi sửa buổi bị rỗng): nhóm cơ theo tên buổi chuẩn,
     * số bài theo thời lượng như khi lập tuần đầu. Không còn bài an toàn thì trả rỗng.
     */
    public static List<TrainingPlan.Item> itemsFor(String title, Integer durationMin, List<Exercise> safeExercises) {
        int index = java.util.Arrays.asList(TITLES).indexOf(title);
        Set<String> focus = FOCUS.get(index < 0 ? 0 : index);
        int minutes = Math.max(10, Math.min(15, durationMin == null ? 15 : durationMin));
        int count = Math.max(4, Math.min(6, minutes / 2 - 1));
        List<Exercise> easyFirst = safeExercises.stream()
            .sorted(Comparator.comparingInt(Exercise::difficultyOrDefault))
            .toList();
        return pickItems(easyFirst, focus, count);
    }

    /** Giờ tập theo khung giờ rảnh (early_morning, noon, evening, late_evening); khung lạ thì buổi tối. */
    public static String timeFor(String slot) {
        return SLOT_TIME.getOrDefault(slot, SLOT_TIME.get("evening"));
    }

    /** Tên buổi chuẩn theo thứ tự trong tuần (xoay vòng). */
    public static String titleFor(int index) {
        return TITLES[Math.floorMod(index, TITLES.length)];
    }

    /** Tối đa 3 ngày rảnh từ hôm nay trở đi, trải đều trong tuần (đầu, giữa, cuối). */
    static List<LocalDate> pickDates(LocalDate weekStart, LocalDate today, Map<Integer, String> days) {
        List<LocalDate> candidates = days.keySet().stream()
            .filter(d -> d >= 1 && d <= 7)
            .sorted()
            .map(d -> weekStart.plusDays(d - 1L))
            .filter(date -> !date.isBefore(today))
            .toList();
        if (candidates.size() <= MAX_SESSIONS) {
            return candidates;
        }
        int last = candidates.size() - 1;
        return List.of(candidates.get(0), candidates.get(last / 2), candidates.get(last));
    }

    /** Ưu tiên bài đúng nhóm cơ của buổi, thiếu thì lấy thêm bài dễ khác. */
    static List<TrainingPlan.Item> pickItems(List<Exercise> easyFirst, Set<String> focus, int count) {
        List<Exercise> chosen = new ArrayList<>(easyFirst.stream()
            .filter(e -> focus.contains(e.primaryMuscle()))
            .limit(count)
            .toList());
        for (Exercise e : easyFirst) {
            if (chosen.size() >= count) {
                break;
            }
            if (!chosen.contains(e)) {
                chosen.add(e);
            }
        }
        return chosen.stream().map(Week1PlanBuilder::toItem).toList();
    }

    private static TrainingPlan.Item toItem(Exercise e) {
        boolean timed = "duration".equals(e.tracking());
        return new TrainingPlan.Item(new ObjectId(e.id()), SETS,
            timed ? null : REPS, timed ? DURATION_SEC : null, REST_SEC);
    }
}
