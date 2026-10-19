package vn.levelup.coach.rules;

import java.util.regex.Pattern;

/** Câu mẫu và kiểm tra câu AI soạn cho giọng coach trong lúc tập. Logic thuần, không Spring/DB. */
public final class VoiceLineRules {

    /** Tối đa số câu AI mỗi ngày cho một người (giới hạn chi phí). */
    public static final int DAILY_AI_LINES = 40;
    static final int MAX_CHARS = 140;
    private static final Pattern NOT_SPEAKABLE = Pattern.compile("[*_#`~<>\\[\\]{}|\\\\]|\\p{So}|[\\x{1F000}-\\x{1FAFF}\\x{2600}-\\x{27BF}\\x{FE0F}]");

    private VoiceLineRules() {}

    /** Câu mẫu theo tình huống và phong cách coach (strict | supportive | funny). */
    public static String template(String situation, String coachStyle) {
        boolean idle = "idle_prompt".equals(situation);
        return switch (coachStyle == null ? "supportive" : coachStyle) {
            case "strict" -> idle ? "Dừng lâu rồi đó. Cố thêm một lần, hoặc vẫy tay để bỏ qua bài này."
                : "Bỏ bài này, sang bài tiếp theo. Giữ nhịp nhé.";
            case "funny" -> idle ? "Bài này làm khó bạn hả? Vẫy tay một cái là mình đổi bài liền."
                : "Ok, bài này cho nghỉ hưu sớm. Qua bài mới nào!";
            default -> idle ? "Cần đổi bài không? Vẫy tay trên đầu nếu muốn bỏ qua, hoặc cứ tập tiếp nhé."
                : "Không sao, mình sang bài tiếp theo nhé. Bạn vẫn đang làm rất tốt.";
        };
    }

    /**
     * Làm sạch câu AI trả về để đọc bằng giọng: một dòng, bỏ ký tự markdown/emoji, tối đa 140 ký tự.
     * Câu hỏi đổi bài phải nhắc cách vẫy tay (thiếu thì thêm). null khi không dùng được.
     */
    public static String clean(String raw, String situation) {
        if (raw == null) {
            return null;
        }
        String text = NOT_SPEAKABLE.matcher(raw.replaceAll("\\s+", " ")).replaceAll("").trim();
        if (text.startsWith("\"") && text.endsWith("\"") && text.length() > 1) {
            text = text.substring(1, text.length() - 1).trim();
        }
        if (text.isEmpty() || text.length() > MAX_CHARS) {
            return null;
        }
        if ("idle_prompt".equals(situation) && !text.toLowerCase().contains("vẫy tay")) {
            text = text + " Vẫy tay nếu muốn bỏ qua.";
        }
        return text;
    }
}
