package vn.levelup.coach.service;

import java.time.Clock;
import java.util.List;

import org.bson.types.ObjectId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Service;

import vn.levelup.coach.ai.AiClient;
import vn.levelup.coach.dto.VoiceLineDtos;
import vn.levelup.coach.rules.VoiceLineRules;
import vn.levelup.identity.model.User;
import vn.levelup.identity.service.PlanAccess;
import vn.levelup.shared.util.LocalDates;

/**
 * Câu giọng coach nói trong lúc tập. Pro: AI soạn theo tình huống (bài, số lần, lỗi tư thế); còn lại hoặc AI lỗi,
 * hết lượt: câu mẫu theo phong cách coach. Không bao giờ lỗi vì AI: luôn trả được một câu.
 */
@Service
public class VoiceLineService {

    private static final Logger log = LoggerFactory.getLogger(VoiceLineService.class);
    static final int MAX_TOKENS = 120;

    static final String SYSTEM = """
        Bạn là huấn luyện viên thể hình nói tiếng Việt, đang nói qua loa điện thoại khi người dùng tập.
        Trả về đúng một câu ngắn (tối đa 25 từ), tự nhiên để đọc to, không emoji, không markdown, không ngoặc kép.
        Không chê bai, không nói về y khoa. Xưng "mình", gọi người dùng là "bạn".""";

    private final AiClient ai;
    private final PlanAccess plans;
    private final MongoTemplate mongo;
    private final Clock clock;

    public VoiceLineService(AiClient ai, PlanAccess plans, MongoTemplate mongo, Clock clock) {
        this.ai = ai;
        this.plans = plans;
        this.mongo = mongo;
        this.clock = clock;
    }

    public VoiceLineDtos.View line(User user, VoiceLineDtos.Request r) {
        String style = user.profile() == null ? null : user.profile().coachStyle();
        VoiceLineDtos.View fallback = new VoiceLineDtos.View(VoiceLineRules.template(r.situation(), style), false);
        if (!plans.isPro(user, clock.instant()) || !ai.available()) {
            return fallback;
        }
        String localDate = LocalDates.today(user.timezone(), clock).toString();
        if (!reserve(new ObjectId(user.id()), localDate)) {
            return fallback;
        }
        try {
            String raw = ai.complete(SYSTEM, List.of(AiClient.Message.user(prompt(r, style))), MAX_TOKENS);
            String text = VoiceLineRules.clean(raw, r.situation());
            return text == null ? fallback : new VoiceLineDtos.View(text, true);
        } catch (AiClient.AiUnavailableException e) {
            log.info("[voice-line] AI lỗi, dùng câu mẫu: {}", e.getMessage());
            return fallback;
        }
    }

    static String prompt(VoiceLineDtos.Request r, String style) {
        StringBuilder b = new StringBuilder();
        b.append("Phong cách coach: ").append(style == null ? "supportive" : style).append('\n');
        b.append("Bài đang tập: ").append(r.exerciseName()).append('\n');
        if (r.repsDone() != null) {
            b.append("Đã làm: ").append(r.repsDone()).append(" lần");
            if (r.targetReps() != null) {
                b.append(" / mục tiêu ").append(r.targetReps());
            }
            b.append('\n');
        }
        if (r.formIssues() != null && !r.formIssues().isEmpty()) {
            b.append("Lỗi tư thế gần đây: ").append(String.join(", ", r.formIssues())).append('\n');
        }
        b.append("idle_prompt".equals(r.situation())
            ? "Đã khoảng 20 giây không làm được lần nào. Hỏi nhẹ nhàng xem bạn có muốn đổi bài không, "
                + "nhắc rằng có thể vẫy một tay trên đầu để bỏ qua, hoặc cứ tập tiếp."
            : "Người dùng vừa bỏ bài này. Động viên ngắn gọn và chuyển sang bài tiếp theo.");
        return b.toString();
    }

    /** Giữ một lượt AI trong ngày (daily_stats.usage.voiceLines), hết lượt thì false. */
    private boolean reserve(ObjectId userId, String localDate) {
        Query q = Query.query(Criteria.where("userId").is(userId).and("localDate").is(localDate)
            .orOperator(Criteria.where("usage.voiceLines").lt(VoiceLineRules.DAILY_AI_LINES),
                Criteria.where("usage.voiceLines").exists(false)));
        for (int i = 0; i < 2; i++) {
            try {
                mongo.upsert(q, new Update().inc("usage.voiceLines", 1), "daily_stats");
                return true;
            } catch (DuplicateKeyException e) {
                // document của ngày đã có và đã hết lượt, hoặc vừa bị request khác tạo
            }
        }
        return false;
    }
}
