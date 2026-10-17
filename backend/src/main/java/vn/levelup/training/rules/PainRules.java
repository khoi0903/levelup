package vn.levelup.training.rules;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Set;

/**
 * Theo dõi vùng đau báo sau buổi tập, không đọc hay ghi database.
 * Mỏi cơ (soreness) là bình thường: không đổi lịch, không hỏi lại.
 * Đau nhói/khớp (sharp): vùng đó vào trạng thái "đang theo dõi" (vẫn là injury active để lọc bài),
 * từ hôm sau hỏi thăm mỗi ngày một lần cho tới khi hết đau hoặc chuyển thành chấn thương.
 */
public final class PainRules {

    /** Vẫn đau sau chừng này ngày kể từ hôm báo thì khuyên đi khám và giữ thành chấn thương. */
    public static final int MAX_WATCH_DAYS = 3;

    public static final Set<String> ANSWERS = Set.of("gone", "better", "same", "worse");

    private PainRules() {}

    /** Vùng đang theo dõi: ngày báo, câu trả lời gần nhất và ngày trả lời (có thể null). */
    public record Watch(String bodyArea, LocalDate reportedOn, String lastAnswer, LocalDate lastAnswerOn) {}

    /** resolved: hết đau, bỏ theo dõi. monitoring: theo dõi tiếp. injury: thành chấn thương, khuyên đi khám. */
    public enum Status { RESOLVED, MONITORING, INJURY }

    public record Decision(Status status, String message) {}

    /** Có ghi vùng đau vào theo dõi không: chỉ khi báo đau nhói. App cũ không gửi painType thì không theo dõi. */
    public static boolean startsWatch(String painType, List<String> painAreas) {
        return "sharp".equals(painType) && painAreas != null && !painAreas.isEmpty();
    }

    /** Mỏi cơ thì không giảm buổi sau theo vùng đau (RPE vẫn tính). */
    public static List<String> areasForAdjust(String painType, List<String> painAreas) {
        return "soreness".equals(painType) ? List.of() : painAreas;
    }

    /** Cần hỏi thăm hôm nay: báo từ hôm trước trở về trước và hôm nay chưa trả lời. */
    public static boolean isDue(Watch w, LocalDate today) {
        return w.reportedOn() != null && w.reportedOn().isBefore(today)
            && (w.lastAnswerOn() == null || w.lastAnswerOn().isBefore(today));
    }

    /** Số ngày kể từ hôm báo đau (hôm sau = 1). */
    public static long daysSince(Watch w, LocalDate today) {
        return w.reportedOn() == null ? 0 : ChronoUnit.DAYS.between(w.reportedOn(), today);
    }

    /**
     * gone → hết theo dõi, tập bình thường. better → theo dõi tiếp, vẫn tránh vùng này.
     * same → theo dõi tiếp; đã {@value #MAX_WATCH_DAYS} ngày trở lên thì thành chấn thương.
     * worse → thành chấn thương ngay.
     */
    public static Decision answer(Watch w, String answer, LocalDate today, String areaVi) {
        String area = areaVi == null ? "chỗ đau" : areaVi;
        return switch (answer) {
            case "gone" -> new Decision(Status.RESOLVED,
                "Tốt quá! Hết đau " + area + " rồi thì hôm nay tập bình thường nhé.");
            case "better" -> new Decision(Status.MONITORING,
                "Đỡ hơn là tốt rồi. Hôm nay mình vẫn tránh bài tác động vào " + area + ", mai hỏi lại bạn nhé.");
            case "same" -> daysSince(w, today) >= MAX_WATCH_DAYS
                ? new Decision(Status.INJURY, "Đau " + area + " đã " + daysSince(w, today)
                    + " ngày chưa đỡ. Bạn nên đi khám; mình sẽ tránh vùng này cho tới khi bạn báo đã khỏi.")
                : new Decision(Status.MONITORING,
                    "Vẫn còn đau thì hôm nay mình đổi sang bài không tác động vào " + area + ". Mai hỏi lại nhé.");
            case "worse" -> new Decision(Status.INJURY, "Đau " + area
                + " nặng hơn thì nên nghỉ vùng này và đi khám. Mình sẽ tránh vùng này cho tới khi bạn báo đã khỏi.");
            default -> throw new IllegalArgumentException("answer: " + answer);
        };
    }
}
