package vn.levelup.coach.rules;

import java.util.List;
import java.util.Map;

/**
 * Lời nhắn của coach: system prompt gửi Claude và câu mẫu khi không có AI.
 * Câu mẫu theo giọng của docs/content/coach-messages.json (strict, supportive, funny), {ten} là tên người dùng.
 */
public final class CoachPrompts {

    private CoachPrompts() {}

    /** Nhắc Claude khi lần đầu trả sai định dạng (docs/04-backend-flow.html: sai thì hỏi lại 1 lần). */
    public static final String FIX_JSON =
        "Câu trả lời vừa rồi không đúng định dạng. Trả lời lại CHỈ bằng một object JSON hợp lệ đúng schema đã cho, "
            + "không thêm chữ nào ngoài JSON.";

    static final Map<String, String> STYLE = Map.of(
        "strict", "Nghiêm khắc, ngắn gọn, đi thẳng vào việc cần làm. Không dùng emoji. Không trách móc.",
        "supportive", "Ấm áp, động viên, thấu hiểu, xưng \"mình\" và gọi \"bạn\". Có thể dùng 1 emoji nhẹ nhàng.",
        "funny", "Vui vẻ, dí dỏm nhẹ nhàng, ví von đời thường. Có thể dùng 1 emoji. Không chế giễu người dùng.");

    /** System prompt cho chat: vai trò, phong cách, dữ liệu người dùng, schema JSON bắt buộc. */
    public static String chatSystem(String style, String userData) {
        return """
            Bạn là coach thể hình của app LevelUp, nói tiếng Việt với người dùng Việt Nam.
            Phong cách: %s
            Trả lời ngắn (tối đa 4 câu), cụ thể, an toàn. Không chẩn đoán bệnh; đau kéo dài hoặc đau nhiều thì khuyên đi khám.
            Bạn KHÔNG tự sửa kế hoạch: chỉ đề xuất trong trường "action", người dùng bấm đồng ý thì hệ thống mới áp dụng.

            Dữ liệu người dùng:
            %s

            Luôn trả lời CHỈ bằng một object JSON (không markdown, không chữ ngoài JSON) theo schema:
            {
              "reply": "câu trả lời cho người dùng",
              "action": {                          // tùy chọn, chỉ khi cần đổi một buổi đang planned
                "type": "adjust_session",
                "sessionId": "id buổi trong kế hoạch ở trên",
                "change": "light" | "quick5" | "swap_exercise" | "rest",
                "fromExerciseId": "id bài trong buổi (chỉ khi swap_exercise)",
                "toExerciseId": "id bài trong danh sách bài an toàn (chỉ khi swap_exercise)",
                "reason": "lý do ngắn"
              },
              "memory": ["sự thật ngắn đáng nhớ lâu dài về người dùng, tối đa 3, mỗi câu dưới 100 ký tự"],
              "injury": {"bodyArea": "lower_back|knee|shoulder|neck|wrist|ankle|hip|other", "note": "mô tả ngắn"}
            }
            Bỏ hẳn các trường tùy chọn khi không dùng. Người dùng báo đau ở đâu thì điền "injury"
            và đề xuất buổi an toàn hơn (swap_exercise sang bài an toàn, hoặc light, hoặc rest).
            Mệt: light. Bận: quick5. Ốm: rest. Chỉ dùng id có trong dữ liệu ở trên.
            """.formatted(STYLE.getOrDefault(style, STYLE.get("supportive")), userData);
    }

    // ------------------------------------------------------------------
    // Câu mẫu khi không có AI
    // ------------------------------------------------------------------

    private static final Map<String, Map<String, List<String>>> REPLIES = Map.of(
        "PAIN", Map.of(
            "strict", List.of(
                "{ten}, ghi nhận đau {vung}. Mình đã chuẩn bị buổi tránh vùng này. Đau kéo dài thì đi khám.",
                "Đau {vung} thì không cố. Xem buổi đã đổi bài an toàn, bấm dùng nếu phù hợp, {ten}."),
            "supportive", List.of(
                "{ten}, mình nghe bạn đau {vung} rồi 💛 Mình đã chuẩn bị buổi tránh vùng này, bạn xem nhé. Nếu đau kéo dài thì đi khám nha.",
                "Cảm ơn bạn đã báo đau {vung} 🌱 Buổi tới mình đổi sang bài nhẹ nhàng hơn cho vùng này, bạn xem thử nhé."),
            "funny", List.of(
                "{ten}, {vung} đang xin nghỉ phép 🩹 Mình đổi buổi tới sang bài không làm phiền nó, bạn xem nhé. Đau lâu thì gặp bác sĩ nha.",
                "Cho {vung} ngồi ghế dự bị một thời gian 😄 Buổi tới đã có bài an toàn hơn, bạn xem thử nhé.")),
        "PAIN_NO_SESSION", Map.of(
            "strict", List.of("{ten}, ghi nhận đau {vung}. Các buổi sau sẽ tránh vùng này. Đau kéo dài thì đi khám."),
            "supportive", List.of("{ten}, mình ghi nhận bạn đau {vung} 💛 Các buổi sau sẽ tránh vùng này. Nghỉ ngơi và đi khám nếu đau kéo dài nha."),
            "funny", List.of("{vung} cần nghỉ phép rồi 🩹 Các buổi sau mình sẽ né vùng này, {ten}. Đau lâu thì gặp bác sĩ nha.")),
        "SICK", Map.of(
            "strict", List.of("{ten}, ốm thì nghỉ. Buổi tới chuyển thành ngày nghỉ, khỏe lại rồi tập tiếp."),
            "supportive", List.of("{ten}, sức khỏe là trên hết 💛 Mình đề xuất nghỉ buổi tới, bạn nghỉ ngơi cho khỏe nhé."),
            "funny", List.of("Cơ thể đang bảo trì 🛠️ Buổi tới cho nghỉ nhé {ten}, khỏe lại mình chiến tiếp.")),
        "TIRED", Map.of(
            "strict", List.of(
                "{ten}, hôm nay bạn thấy mệt. Chọn buổi nhẹ hơn: bớt một hiệp mỗi bài.",
                "Không cần cố đủ cường độ hôm nay. Dùng bản nhẹ, {ten}."),
            "supportive", List.of(
                "{ten}, mình nghe bạn nói hôm nay mệt 💛 Mình đã chuẩn bị bản nhẹ hơn, bạn xem nhé.",
                "Bạn có thể đổi nhịp hôm nay 🌱 Mình đề xuất bản nhẹ hơn cho buổi tới nhé."),
            "funny", List.of(
                "{ten}, pin thấp thì lịch cũng có nút chỉnh 🔋 Mình đề xuất bản nhẹ cho buổi tới nhé.",
                "Hôm nay kế hoạch có thể co giãn 😄 Bản nhẹ đã sẵn sàng, {ten}.")),
        "BUSY", Map.of(
            "strict", List.of(
                "{ten}, bận thì làm bản 5 phút. Không cần tập bù.",
                "Không có thời gian không có nghĩa là bỏ. Dùng bản 5 phút, {ten}."),
            "supportive", List.of(
                "{ten}, ngày bận cũng không sao 💛 Mình đã chuẩn bị bản 5 phút, bạn xem nhé.",
                "5 phút cho bản thân thôi 🌱 Mình rút buổi tới còn bản 5 phút nhé, {ten}."),
            "funny", List.of(
                "Buổi tập cũng có bản mini 😄 Bản 5 phút đã sẵn sàng, {ten}.",
                "{ten}, hôm nay thử chế độ gọn nhẹ nhé 🎒 Bản 5 phút đây.")),
        "NO_SESSION", Map.of(
            "strict", List.of("{ten}, hiện không còn buổi nào cần đổi. Giữ nhịp và nghỉ ngơi đủ."),
            "supportive", List.of("{ten}, hiện chưa có buổi nào sắp tới để điều chỉnh 💛 Bạn nghỉ ngơi đủ nhé."),
            "funny", List.of("Lịch tuần này đang trống chỗ để chỉnh 📅 Nghỉ ngơi đủ nhé, {ten}.")),
        "OTHER", Map.of(
            "strict", List.of(
                "{ten}, mình đã ghi nhận. Tập trung vào buổi tiếp theo trong kế hoạch.",
                "Rõ rồi, {ten}. Mở kế hoạch tuần và hoàn thành buổi kế tiếp.",
                "{ten}, tiến bộ đến từ việc lặp lại. Bắt đầu buổi tiếp theo khi bạn sẵn sàng."),
            "supportive", List.of(
                "{ten}, cảm ơn bạn đã chia sẻ 💛 Mình luôn ở đây cùng bạn, cứ tập theo nhịp của mình nhé.",
                "Mình nghe rồi 🌱 Mỗi buổi nhỏ đều đáng ghi nhận, bạn mở kế hoạch tuần khi sẵn sàng nhé, {ten}.",
                "{ten}, mình đồng hành cùng bạn ✨ Nếu thấy mệt, bận hay đau ở đâu, cứ nói để mình chỉnh buổi tập nhé."),
            "funny", List.of(
                "{ten}, coach đã nhận tin 📨 Kế hoạch tuần vẫn đang chờ bạn lên sóng nhé.",
                "Ghi chú vào sổ coach rồi 📒 Mệt, bận hay đau đâu cứ báo, mình chỉnh lịch liền, {ten}.",
                "Không cần siêu nhân, chỉ cần có mặt 🦸 Buổi tiếp theo đang chờ bạn đó, {ten}.")));

    /** Câu mẫu theo ý định và phong cách; chọn theo nội dung tin để cố định (test lặp lại được). */
    public static String fallbackReply(CoachRules.Intent intent, String style, String name, boolean hasSession,
                                       String seed) {
        String key = switch (intent) {
            case PAIN -> hasSession ? "PAIN" : "PAIN_NO_SESSION";
            case OTHER -> "OTHER";
            default -> hasSession ? intent.name() : "NO_SESSION";
        };
        Map<String, List<String>> byStyle = REPLIES.get(key);
        List<String> options = byStyle.getOrDefault(style, byStyle.get("supportive"));
        String text = options.get(Math.floorMod(seed.hashCode(), options.size()));
        return fill(text, name);
    }

    /** Thay {ten}; thiếu tên thì bỏ cả dấu phẩy đi kèm cho câu tự nhiên. */
    public static String fill(String template, String name) {
        if (name == null || name.isBlank()) {
            return template.replace(", {ten}", "").replace("{ten}, ", "").replace("{ten}", "bạn");
        }
        return template.replace("{ten}", name.trim());
    }
}
