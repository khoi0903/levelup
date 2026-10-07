package vn.levelup.engagement.rules;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.bson.types.ObjectId;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.model.TrainingPlan;


/** Luật của tổng kết tuần (F6) không đọc hay ghi database, để unit test. */
public final class ReviewRules {

    static final int MAX_SETS = 5;
    static final int MIN_MINUTES = 5;
    static final int MAX_MINUTES = 90;
    static final int STEP_MINUTES = 5;
    static final int DEFAULT_SETS = 2;
    public static final int DEFAULT_MINUTES = 15;

    private ReviewRules() {}

    /**
     * docs/04-backend-flow.html F6: đạt 100% và RPE trung bình 7 trở xuống thì tăng,
     * 60–99% giữ, dưới 60% giảm. Đủ buổi nhưng RPE trên 7 (đã rất nặng) thì giữ.
     */
    public static String recommendation(int done, int target, Double avgRpe) {
        int t = Math.max(1, target);
        if (done >= t) {
            return avgRpe == null || avgRpe <= 7 ? "increase" : "keep";
        }
        return done * 100 >= 60 * t ? "keep" : "decrease";
    }

    /** Tỷ lệ hoàn thành 0–100. */
    public static int completionPct(int done, int target) {
        return (int) Math.min(100, Math.round(done * 100.0 / Math.max(1, target)));
    }

    /**
     * Buổi tập tuần sau: chép các buổi tuần này sang cùng thứ của tuần sau, trạng thái planned, bản thường.
     * increase: thêm 1 hiệp (tối đa 5) và 5 phút; decrease: bớt 1 hiệp (tối thiểu 1) và 5 phút; keep: giữ.
     * Buổi đã bị rút gọn (light, quick5) lấy lại số hiệp và thời lượng của buổi thường trước khi điều chỉnh.
     */
    public static List<TrainingPlan.Session> nextWeek(List<TrainingPlan.Session> thisWeek, LocalDate nextWeekStart,
                                                      String recommendation) {
        int baseSets = thisWeek.stream().filter(ReviewRules::isNormal)
            .flatMap(s -> s.items() == null ? java.util.stream.Stream.empty() : s.items().stream())
            .map(TrainingPlan.Item::targetSets).filter(x -> x != null).max(Integer::compare).orElse(DEFAULT_SETS);
        int baseMinutes = thisWeek.stream().filter(ReviewRules::isNormal)
            .map(TrainingPlan.Session::durationMin).filter(x -> x != null).max(Integer::compare)
            .orElse(DEFAULT_MINUTES);
        int setDelta = switch (recommendation) {
            case "increase" -> 1;
            case "decrease" -> -1;
            default -> 0;
        };

        Set<String> usedDates = new HashSet<>();
        List<TrainingPlan.Session> result = new ArrayList<>();
        for (TrainingPlan.Session s : thisWeek.stream()
                .sorted(Comparator.comparing(TrainingPlan.Session::scheduledDate)).toList()) {
            LocalDate old = LocalDate.parse(s.scheduledDate());
            LocalDate date = nextWeekStart.plusDays(old.toEpochDay() - LocalDates.weekStart(old).toEpochDay());
            if (!usedDates.add(date.toString()) || s.items() == null || s.items().isEmpty()) {
                continue;
            }
            boolean normal = isNormal(s);
            int minutes = normal && s.durationMin() != null ? s.durationMin() : baseMinutes;
            List<TrainingPlan.Item> items = s.items().stream().map(i -> {
                int sets = normal && i.targetSets() != null ? i.targetSets() : baseSets;
                return new TrainingPlan.Item(i.exerciseId(), clamp(sets + setDelta, 1, MAX_SETS),
                    i.targetReps(), i.targetDurationSec(), i.restSec());
            }).toList();
            result.add(new TrainingPlan.Session(new ObjectId(), date.toString(), s.scheduledTime(), s.title(),
                clamp(minutes + setDelta * STEP_MINUTES, MIN_MINUTES, MAX_MINUTES), "normal", "planned", items));
        }
        return result;
    }

    private static boolean isNormal(TrainingPlan.Session s) {
        return s.variant() == null || "normal".equals(s.variant()) || "advanced".equals(s.variant());
    }

    /**
     * Người dùng chỉnh kế hoạch nháp: số buổi mỗi tuần (1–7) và số phút mỗi buổi (5–90).
     * Bớt buổi thì bỏ buổi cuối tuần; thêm buổi thì xếp vào ngày trống, chép bài của các buổi sẵn có.
     */
    public static List<TrainingPlan.Session> adjust(List<TrainingPlan.Session> draft, LocalDate weekStart,
                                                    Integer sessionsPerWeek, Integer sessionMinutes) {
        List<TrainingPlan.Session> sessions = new ArrayList<>(draft.stream()
            .sorted(Comparator.comparing(TrainingPlan.Session::scheduledDate)).toList());
        if (sessionsPerWeek != null) {
            int n = clamp(sessionsPerWeek, 1, 7);
            while (sessions.size() > n) {
                sessions.remove(sessions.size() - 1);
            }
            if (sessions.size() < n && !sessions.isEmpty()) {
                List<TrainingPlan.Session> templates = List.copyOf(sessions);
                Set<String> used = new HashSet<>();
                sessions.forEach(s -> used.add(s.scheduledDate()));
                for (LocalDate d : spreadDays(weekStart, used, n - sessions.size())) {
                    TrainingPlan.Session t = templates.get(sessions.size() % templates.size());
                    sessions.add(new TrainingPlan.Session(new ObjectId(), d.toString(), t.scheduledTime(), t.title(),
                        t.durationMin(), "normal", "planned", t.items()));
                }
                sessions.sort(Comparator.comparing(TrainingPlan.Session::scheduledDate));
            }
        }
        if (sessionMinutes != null) {
            int minutes = clamp(sessionMinutes, MIN_MINUTES, MAX_MINUTES);
            sessions = sessions.stream().map(s -> new TrainingPlan.Session(s.id(), s.scheduledDate(),
                s.scheduledTime(), s.title(), minutes, s.variant(), s.status(), s.items(), s.adjustedReason()))
                .toList();
        }
        return sessions;
    }

    /** Ngày trống trong tuần, ưu tiên ngày cách xa các buổi đã có (để không tập dồn). */
    static List<LocalDate> spreadDays(LocalDate weekStart, Set<String> used, int count) {
        Set<String> taken = new HashSet<>(used);
        List<LocalDate> picked = new ArrayList<>();
        for (int k = 0; k < count; k++) {
            LocalDate best = null;
            int bestGap = -1;
            for (int d = 0; d < 7; d++) {
                LocalDate day = weekStart.plusDays(d);
                if (taken.contains(day.toString())) {
                    continue;
                }
                int gap = taken.stream().mapToInt(t -> (int) Math.abs(LocalDate.parse(t).toEpochDay() - day.toEpochDay()))
                    .min().orElse(7);
                if (gap > bestGap) {
                    bestGap = gap;
                    best = day;
                }
            }
            if (best == null) {
                break;
            }
            taken.add(best.toString());
            picked.add(best);
        }
        return picked;
    }

    static int clamp(int v, int min, int max) {
        return Math.max(min, Math.min(max, v));
    }
}
