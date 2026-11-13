package vn.levelup.engagement.rules;

import java.util.List;
import java.util.Map;
import java.util.Optional;

import tools.jackson.databind.json.JsonMapper;
import vn.levelup.coach.rules.CoachPrompts;

/**
 * Lời tổng kết tuần: prompt gửi Claude (JSON {win, improve, nextWeekSummary}), kiểm tra JSON,
 * câu mẫu khi không có AI. Giọng theo docs/content/coach-messages.json (weekly_win).
 */
public final class ReviewTexts {

    static final int MAX_LEN = 400;
    private static final JsonMapper JSON = JsonMapper.builder().build();

    private ReviewTexts() {}

    public record Texts(String win, String improve, String nextWeekSummary) {}

    /** Số liệu của tuần đưa cho Claude và câu mẫu. */
    public record Facts(String name, String style, int done, int target, int totalMinutes, Double avgRpe,
                        String recommendation, List<String> prLabels, Double weightChangeKg,
                        int mealDaysLogged, Integer avgKcal, int nextSessions, int nextMinutes) {}

    public static String system(String style) {
        String tone = switch (style == null ? "supportive" : style) {
            case "strict" -> "Nghiêm khắc, ngắn gọn, không emoji, không trách móc.";
            case "funny" -> "Vui vẻ, dí dỏm nhẹ nhàng, có thể dùng 1 emoji, không chế giễu.";
            default -> "Ấm áp, động viên, xưng \"mình\" gọi \"bạn\", có thể dùng 1 emoji.";
        };
        return """
            Bạn là coach thể hình của app LevelUp, viết tổng kết tuần bằng tiếng Việt.
            Phong cách: %s
            Trả lời CHỈ bằng một object JSON (không markdown, không chữ ngoài JSON):
            {"win": "1 chiến thắng cụ thể của tuần, 1 câu",
             "improve": "1 điều cải thiện cho tuần sau, 1 câu, nhẹ nhàng, khả thi",
             "nextWeekSummary": "tóm tắt kế hoạch tuần sau đúng theo đề xuất hệ thống đã quyết, 1–2 câu"}
            Không bịa số liệu ngoài dữ liệu được cung cấp. Không đổi đề xuất tăng/giữ/giảm của hệ thống.
            Tuần 0 buổi: không khen "nghỉ ngơi" hay điều không xảy ra, không mỉa mai; gợi ý bắt đầu lại bằng 1 buổi ngắn.
            """.formatted(tone);
    }

    public static String userData(Facts f) {
        StringBuilder b = new StringBuilder();
        b.append("Tên: ").append(f.name()).append('\n');
        b.append("Số buổi hoàn thành: ").append(f.done()).append('/').append(f.target()).append('\n');
        b.append("Tổng số phút tập: ").append(f.totalMinutes()).append('\n');
        b.append("RPE trung bình: ").append(f.avgRpe() == null ? "không có" : String.format("%.1f", f.avgRpe())).append('\n');
        b.append("Kỷ lục mới: ").append(f.prLabels().isEmpty() ? "không có" : String.join("; ", f.prLabels())).append('\n');
        if (f.weightChangeKg() != null) {
            b.append("Thay đổi cân nặng trong tuần: ").append(String.format("%+.1f kg", f.weightChangeKg())).append('\n');
        }
        b.append("Số ngày ghi bữa ăn: ").append(f.mealDaysLogged())
            .append(f.avgKcal() == null ? "" : ", trung bình " + f.avgKcal() + " kcal/ngày").append('\n');
        b.append("Đề xuất của hệ thống: ").append(switch (f.recommendation()) {
            case "increase" -> "tăng nhẹ (thêm 1 hiệp mỗi bài, thêm 5 phút)";
            case "decrease" -> "giảm nhẹ (bớt 1 hiệp mỗi bài, bớt 5 phút)";
            default -> "giữ nguyên";
        }).append('\n');
        b.append("Kế hoạch tuần sau: ").append(f.nextSessions()).append(" buổi, khoảng ").append(f.nextMinutes())
            .append(" phút mỗi buổi\n");
        return b.toString();
    }

    /** JSON hợp lệ: đủ 3 trường chuỗi, không rỗng, không quá dài. */
    public static Optional<Texts> parse(String raw) {
        if (raw == null) {
            return Optional.empty();
        }
        int start = raw.indexOf('{');
        int end = raw.lastIndexOf('}');
        if (start < 0 || end <= start) {
            return Optional.empty();
        }
        try {
            Object v = JSON.readValue(raw.substring(start, end + 1), Object.class);
            if (!(v instanceof Map<?, ?> m)) {
                return Optional.empty();
            }
            String win = text(m.get("win"));
            String improve = text(m.get("improve"));
            String summary = text(m.get("nextWeekSummary"));
            return win == null || improve == null || summary == null ? Optional.empty()
                : Optional.of(new Texts(win, improve, summary));
        } catch (RuntimeException e) {
            return Optional.empty();
        }
    }

    private static String text(Object o) {
        return o instanceof String s && !s.isBlank() && s.length() <= MAX_LEN ? s.trim() : null;
    }

    /**
     * Chọn lời tổng kết: tuần 0 buổi thì luôn dùng câu "chiến thắng" mẫu (AI hay khen "nghỉ ngơi trọn vẹn",
     * đọc như mỉa mai), phần còn lại giữ của AI.
     */
    public static Texts choose(Facts f, Optional<Texts> fromAi) {
        Texts rules = fallback(f);
        return fromAi.map(t -> f.done() == 0 ? new Texts(rules.win(), t.improve(), t.nextWeekSummary()) : t)
            .orElse(rules);
    }

    /** Câu mẫu khi không có AI. */
    public static Texts fallback(Facts f) {
        String style = f.style() == null ? "supportive" : f.style();
        String win;
        if (!f.prLabels().isEmpty()) {
            win = pick(style, Map.of(
                "strict", "Kỷ lục mới tuần này: {pr}. Giữ đà này.",
                "supportive", "Tuần này bạn có kỷ lục mới: {pr} ✨ Mình rất vui cho bạn!",
                "funny", "Bảng kỷ lục vừa có dòng mới: {pr} 🏆")).replace("{pr}", f.prLabels().get(0));
        } else if (f.done() > 0) {
            win = pick(style, Map.of(
                "strict", "{ten}, tuần này bạn hoàn thành {so_buoi} buổi.",
                "supportive", "{ten}, tuần này bạn đã có {so_buoi} buổi 💛",
                "funny", "Nhật ký tuần vừa điểm danh {so_buoi} buổi 📖"));
        } else {
            win = pick(style, Map.of(
                "strict", "{ten}, bạn vẫn giữ kế hoạch. Tuần mới là cơ hội bắt đầu lại.",
                "supportive", "{ten}, bạn vẫn ở đây và đọc tổng kết này, đó đã là một bước 💛",
                "funny", "Tuần này hơi im ắng, nhưng bạn vẫn có mặt ở đây 😄"));
        }
        String improve = switch (f.recommendation()) {
            case "increase" -> pick(style, Map.of(
                "strict", "Bạn đã sẵn sàng cho mức cao hơn: thêm 1 hiệp mỗi bài.",
                "supportive", "Bạn làm rất tốt, tuần sau mình thử thêm một chút nhé 🌱",
                "funny", "Level hiện tại đã quá dễ, mở khóa level kế tiếp thôi 🔓"));
            case "decrease" -> pick(style, Map.of(
                "strict", "Tuần sau giảm nhẹ để hoàn thành đủ buổi. Đều đặn quan trọng hơn cường độ.",
                "supportive", "Tuần sau mình làm nhẹ hơn một chút để bạn dễ giữ nhịp nhé 💛",
                "funny", "Tuần sau chơi bản rút gọn, ít mà chắc 🎒"));
            default -> pick(style, Map.of(
                "strict", "Giữ nguyên mức tập và hoàn thành đủ số buổi tuần sau.",
                "supportive", "Tuần sau mình giữ nhịp này nhé, bạn đang đi đúng hướng 🌱",
                "funny", "Công thức đang ổn, tuần sau giữ nguyên nồi lẩu 🍲"));
        };
        String summary = "Tuần sau: " + f.nextSessions() + " buổi, khoảng " + f.nextMinutes() + " phút mỗi buổi"
            + switch (f.recommendation()) {
                case "increase" -> ", thêm 1 hiệp mỗi bài.";
                case "decrease" -> ", bớt 1 hiệp mỗi bài.";
                default -> ", giữ nguyên số hiệp.";
            };
        return new Texts(CoachPrompts.fill(win.replace("{so_buoi}", String.valueOf(f.done())), f.name()),
            CoachPrompts.fill(improve, f.name()), summary);
    }

    private static String pick(String style, Map<String, String> byStyle) {
        return byStyle.getOrDefault(style, byStyle.get("supportive"));
    }
}
