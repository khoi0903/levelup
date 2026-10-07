package vn.levelup.coach.rules;

import java.text.Normalizer;
import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.regex.Pattern;

import tools.jackson.databind.json.JsonMapper;
import vn.levelup.training.model.Exercise;
import vn.levelup.training.model.TrainingPlan;

/**
 * Luật của coach không đọc hay ghi database, để unit test:
 * kiểm tra JSON Claude trả về, luật từ khóa khi không có AI, kiểm tra thẻ hành động, gộp trí nhớ.
 */
public final class CoachRules {

    public static final Set<String> BODY_AREAS =
        Set.of("lower_back", "knee", "shoulder", "neck", "wrist", "ankle", "hip", "other");
    public static final Set<String> CHANGES = Set.of("light", "quick5", "swap_exercise", "rest");
    public static final int MEMORY_CAP = 20;
    static final int MAX_REPLY = 2000;
    static final int MAX_FACT = 120;
    static final int MAX_FACTS_PER_REPLY = 3;
    static final int MAX_NOTE = 200;

    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final Pattern HEX24 = Pattern.compile("[0-9a-f]{24}");
    private static final DateTimeFormatter DAY_MONTH = DateTimeFormatter.ofPattern("dd/MM");

    private CoachRules() {}

    public record Injury(String bodyArea, String note) {}

    public record Action(String type, String sessionId, String change, String fromExerciseId,
                         String toExerciseId, String reason) {}

    /** Đề xuất của coach (từ Claude hoặc từ luật), chưa ghi gì vào database. */
    public record Proposal(String reply, Action action, List<String> memory, Injury injury) {
        public Proposal withAction(Action a) {
            return new Proposal(reply, a, memory, injury);
        }
    }

    /** Một mẩu trí nhớ dài hạn (users.coachMemory): key dùng để chống trùng. */
    public record Fact(String key, String value, Instant updatedAt) {
        public static Fact of(String value, Instant now) {
            return new Fact(normalizeKey(value), value, now);
        }
    }

    /** Thông tin người dùng mà luật cần. */
    public record UserCtx(String name, String style, String location, Set<String> equipment, Set<String> injuries) {}

    public enum Intent { PAIN, SICK, TIRED, BUSY, OTHER }

    // ------------------------------------------------------------------
    // JSON từ Claude
    // ------------------------------------------------------------------

    /**
     * Đọc JSON Claude trả về: {reply, action?, memory?, injury?}. Sai cấu trúc thì empty để hỏi lại hoặc dùng luật.
     * Ở đây chỉ kiểm tra hình dạng; buổi tập và bài tập có hợp lệ không thì {@link #validateAction} kiểm tra.
     */
    public static Optional<Proposal> parseAi(String raw) {
        Map<String, Object> root = readObject(raw);
        if (root == null || !(root.get("reply") instanceof String reply) || reply.isBlank()
                || reply.length() > MAX_REPLY) {
            return Optional.empty();
        }
        Action action = null;
        Object a = root.get("action");
        if (a != null) {
            if (!(a instanceof Map<?, ?> m)) {
                return Optional.empty();
            }
            String change = str(m.get("change"));
            String sessionId = str(m.get("sessionId"));
            String from = str(m.get("fromExerciseId"));
            String to = str(m.get("toExerciseId"));
            if (!"adjust_session".equals(str(m.get("type"))) || !CHANGES.contains(change) || !isHex(sessionId)) {
                return Optional.empty();
            }
            if ("swap_exercise".equals(change) && (!isHex(from) || !isHex(to))) {
                return Optional.empty();
            }
            String reason = str(m.get("reason"));
            action = new Action("adjust_session", sessionId, change,
                "swap_exercise".equals(change) ? from : null, "swap_exercise".equals(change) ? to : null,
                clip(reason == null || reason.isBlank() ? "Coach đề xuất điều chỉnh" : reason.trim(), 300));
        }
        List<String> memory = new ArrayList<>();
        Object mem = root.get("memory");
        if (mem != null) {
            if (!(mem instanceof List<?> list)) {
                return Optional.empty();
            }
            for (Object f : list) {
                if (!(f instanceof String s)) {
                    return Optional.empty();
                }
                String fact = cleanFact(s);
                if (fact != null && memory.size() < MAX_FACTS_PER_REPLY) {
                    memory.add(fact);
                }
            }
        }
        Injury injury = null;
        Object inj = root.get("injury");
        if (inj != null) {
            if (!(inj instanceof Map<?, ?> m) || !BODY_AREAS.contains(str(m.get("bodyArea")))) {
                return Optional.empty();
            }
            String note = str(m.get("note"));
            injury = new Injury(str(m.get("bodyArea")), note == null ? null : clip(note.trim(), MAX_NOTE));
        }
        return Optional.of(new Proposal(reply.trim(), action, memory, injury));
    }

    /** Lấy object JSON đầu tiên trong chuỗi (bỏ ```json và chữ thừa quanh nó). */
    @SuppressWarnings("unchecked")
    static Map<String, Object> readObject(String raw) {
        if (raw == null) {
            return null;
        }
        int start = raw.indexOf('{');
        int end = raw.lastIndexOf('}');
        if (start < 0 || end <= start) {
            return null;
        }
        try {
            Object v = JSON.readValue(raw.substring(start, end + 1), Object.class);
            return v instanceof Map<?, ?> m ? (Map<String, Object>) m : null;
        } catch (RuntimeException e) {
            return null;
        }
    }

    /** JSON của một câu trả lời cũ, để lịch sử gửi cho Claude cùng định dạng nó phải trả. */
    public static String replyJson(String reply) {
        return JSON.writeValueAsString(Map.of("reply", reply));
    }

    // ------------------------------------------------------------------
    // Luật từ khóa khi không có AI
    // ------------------------------------------------------------------

    public static Intent intent(String text) {
        String t = lower(text);
        if (has(t, "đau", "chấn thương", "nhức", "trẹo", "bong gân", "gối")) {
            return Intent.PAIN;
        }
        if (has(t, "ốm", "sốt", "cảm cúm", "bị cúm", "bệnh")) {
            return Intent.SICK;
        }
        if (has(t, "mệt", "kiệt sức", "uể oải", "đuối", "thiếu ngủ", "mất ngủ")) {
            return Intent.TIRED;
        }
        if (has(t, "bận", "không có thời gian", "ko có thời gian", "k có thời gian", "không có time",
                "hết thời gian", "ít thời gian", "không kịp")) {
            return Intent.BUSY;
        }
        return Intent.OTHER;
    }

    /** Vùng đau trong câu, khớp enum bodyArea. Kiểm tra cụm dài trước ("cổ tay" trước "cổ"). */
    public static String bodyArea(String text) {
        String t = lower(text);
        if (word(t, "cổ tay")) {
            return "wrist";
        }
        if (word(t, "cổ chân") || word(t, "mắt cá")) {
            return "ankle";
        }
        if (word(t, "gối")) {
            return "knee";
        }
        if (word(t, "vai")) {
            return "shoulder";
        }
        if (word(t, "lưng")) {
            return "lower_back";
        }
        if (word(t, "hông") || word(t, "háng")) {
            return "hip";
        }
        if (word(t, "cổ") || word(t, "gáy")) {
            return "neck";
        }
        return "other";
    }

    /** Tên vùng đau bằng tiếng Việt cho câu trả lời và trí nhớ. */
    public static String areaVi(String bodyArea) {
        return switch (bodyArea) {
            case "lower_back" -> "lưng";
            case "knee" -> "gối";
            case "shoulder" -> "vai";
            case "neck" -> "cổ";
            case "wrist" -> "cổ tay";
            case "ankle" -> "cổ chân";
            case "hip" -> "hông";
            default -> "cơ thể";
        };
    }

    /**
     * Câu trả lời và đề xuất bằng luật cố định: đau → ghi nhận chấn thương + buổi an toàn hơn,
     * ốm → nghỉ, mệt → nhẹ, bận → bản 5 phút, còn lại → câu mẫu.
     * @param next buổi planned sắp tới trong kế hoạch đang áp dụng, null nếu không có
     */
    public static Proposal fallback(String text, UserCtx user, TrainingPlan.Session next,
                                    List<Exercise> active) {
        Intent intent = intent(text);
        String pick = text == null ? "" : text;
        if (intent == Intent.PAIN) {
            String area = bodyArea(text);
            Injury injury = new Injury(area, clip(text.trim(), MAX_NOTE));
            Action action = next == null ? null : injuryAction(next, user, area, active);
            String reply = CoachPrompts.fallbackReply(intent, user.style(), user.name(), next != null, pick)
                .replace("{vung}", areaVi(area));
            return new Proposal(reply, action, List.of(), injury);
        }
        String change = switch (intent) {
            case SICK -> "rest";
            case TIRED -> "light";
            case BUSY -> "quick5";
            default -> null;
        };
        Action action = change == null || next == null ? null
            : new Action("adjust_session", next.id().toHexString(), change, null, null, reasonText(intent));
        String reply = CoachPrompts.fallbackReply(intent, user.style(), user.name(), next != null, pick);
        return new Proposal(reply, action, List.of(), null);
    }

    /**
     * Đề xuất buổi an toàn hơn khi có vùng đau mới: có bài vi phạm thì đổi bài đầu tiên
     * (các bài vi phạm còn lại backend tự thay khi áp dụng), không có thì giảm nhẹ buổi.
     */
    public static Action injuryAction(TrainingPlan.Session next, UserCtx user, String area, List<Exercise> active) {
        Set<String> injuries = new HashSet<>(user.injuries());
        injuries.add(area);
        List<Exercise> safe = SafeSessions.safeList(active, user.location(), user.equipment(), injuries);
        Map<String, Exercise> byId = new LinkedHashMap<>();
        active.forEach(e -> byId.put(e.id(), e));
        String reason = "Tránh động tác gây áp lực lên " + areaVi(area);
        for (String unsafeId : SafeSessions.unsafeExerciseIds(next, safe)) {
            Set<String> exclude = new HashSet<>();
            next.items().forEach(i -> exclude.add(i.exerciseId().toHexString()));
            Optional<Exercise> to = SafeSessions.substitute(byId.get(unsafeId), safe, exclude);
            if (to.isPresent()) {
                return new Action("adjust_session", next.id().toHexString(), "swap_exercise", unsafeId,
                    to.get().id(), reason);
            }
        }
        return new Action("adjust_session", next.id().toHexString(), "light", null, null, reason);
    }

    private static String reasonText(Intent intent) {
        return switch (intent) {
            case SICK -> "Nghỉ để hồi phục";
            case TIRED -> "Giảm cường độ vì đang mệt";
            case BUSY -> "Bản 5 phút cho ngày bận";
            default -> "Coach đề xuất điều chỉnh";
        };
    }

    /** Mẩu trí nhớ về vùng đau; key cố định theo vùng nên báo lại nhiều lần không bị trùng. */
    public static Fact injuryFact(Injury injury, LocalDate today, Instant now) {
        return new Fact("injury_" + injury.bodyArea(),
            "Đau " + areaVi(injury.bodyArea()) + " (báo ngày " + today.format(DAY_MONTH) + ")", now);
    }

    /** Mã lý do lưu ở sessions.adjustedReason. */
    public static String adjustedReason(String change, Injury injury) {
        if (injury != null) {
            return "pain_" + injury.bodyArea();
        }
        return switch (change) {
            case "light" -> "coach_light";
            case "quick5" -> "coach_quick5";
            case "swap_exercise" -> "coach_swap";
            default -> "coach_rest";
        };
    }

    // ------------------------------------------------------------------
    // Kiểm tra thẻ hành động (AI đề xuất, backend kiểm tra)
    // ------------------------------------------------------------------

    /**
     * Lỗi nếu không được áp dụng, empty nếu hợp lệ.
     * @param plan kế hoạch active của chính người gọi (đã lọc theo userId)
     * @param byId mọi bài trong thư viện
     * @param injuries vùng đang đau, gồm cả vùng vừa báo trong thẻ
     */
    public static Optional<String> validateAction(Action a, TrainingPlan plan, Map<String, Exercise> byId,
                                                  String location, Set<String> equipment, Set<String> injuries) {
        if (a == null || !"adjust_session".equals(a.type()) || !CHANGES.contains(a.change())) {
            return Optional.of("INVALID_CHANGE");
        }
        if (plan == null || !"active".equals(plan.status()) || plan.sessions() == null) {
            return Optional.of("NO_ACTIVE_PLAN");
        }
        TrainingPlan.Session session = plan.sessions().stream()
            .filter(s -> s.id().toHexString().equals(a.sessionId())).findFirst().orElse(null);
        if (session == null) {
            return Optional.of("SESSION_NOT_FOUND");
        }
        if (!"planned".equals(session.status())) {
            return Optional.of("SESSION_NOT_PLANNED");
        }
        if ("swap_exercise".equals(a.change())) {
            boolean inSession = session.items() != null && session.items().stream()
                .anyMatch(i -> i.exerciseId().toHexString().equals(a.fromExerciseId()));
            if (!inSession) {
                return Optional.of("EXERCISE_NOT_IN_SESSION");
            }
            if (a.fromExerciseId().equals(a.toExerciseId())) {
                return Optional.of("SAME_EXERCISE");
            }
            Exercise to = a.toExerciseId() == null ? null : byId.get(a.toExerciseId());
            if (to == null || Boolean.FALSE.equals(to.isActive())) {
                return Optional.of("UNKNOWN_EXERCISE");
            }
            if (!SafeSessions.isSafe(to, location, equipment, injuries)) {
                return Optional.of("EXERCISE_UNSAFE");
            }
        }
        return Optional.empty();
    }

    // ------------------------------------------------------------------
    // Trí nhớ dài hạn
    // ------------------------------------------------------------------

    /**
     * Gộp mẩu trí nhớ mới: trùng key thì thay bằng bản mới và đưa xuống cuối,
     * giữ tối đa {@link #MEMORY_CAP} mẩu mới nhất.
     */
    public static List<Fact> mergeMemory(List<Fact> existing, List<Fact> incoming) {
        LinkedHashMap<String, Fact> merged = new LinkedHashMap<>();
        for (Fact f : existing) {
            if (f.key() != null && !f.key().isBlank()) {
                merged.put(f.key(), f);
            }
        }
        for (Fact f : incoming) {
            if (f.key() == null || f.key().isBlank()) {
                continue;
            }
            merged.remove(f.key());
            merged.put(f.key(), f);
        }
        List<Fact> all = new ArrayList<>(merged.values());
        return all.size() <= MEMORY_CAP ? all : all.subList(all.size() - MEMORY_CAP, all.size());
    }

    /** Mẩu trí nhớ hợp lệ: 3–120 ký tự, một dòng. */
    static String cleanFact(String s) {
        String fact = s.replaceAll("\\p{Cntrl}", " ").replaceAll("\\s+", " ").trim();
        return fact.length() < 3 || fact.length() > MAX_FACT ? null : fact;
    }

    /** Key chống trùng: bỏ dấu, chữ thường, chỉ chữ và số. */
    public static String normalizeKey(String value) {
        String s = Normalizer.normalize(value.toLowerCase(Locale.ROOT).replace('đ', 'd'), Normalizer.Form.NFD)
            .replaceAll("\\p{M}", "")
            .replaceAll("[^a-z0-9]+", " ")
            .trim();
        return s.length() > 60 ? s.substring(0, 60).trim() : s;
    }

    // ------------------------------------------------------------------

    public static boolean isHex(String s) {
        return s != null && HEX24.matcher(s).matches();
    }

    private static String str(Object o) {
        return o instanceof String s ? s : null;
    }

    static String clip(String s, int max) {
        return s.length() <= max ? s : s.substring(0, max);
    }

    private static String lower(String text) {
        return text == null ? "" : Normalizer.normalize(text, Normalizer.Form.NFC).toLowerCase(Locale.ROOT);
    }

    private static boolean has(String t, String... words) {
        for (String w : words) {
            if (word(t, w)) {
                return true;
            }
        }
        return false;
    }

    /** Có từ hoặc cụm từ đứng riêng (không phải một phần của từ khác). */
    private static boolean word(String t, String w) {
        return Pattern.compile("(?U)(^|[^\\p{L}\\p{N}])" + Pattern.quote(w) + "($|[^\\p{L}\\p{N}])").matcher(t).find();
    }
}
