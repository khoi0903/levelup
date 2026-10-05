package vn.levelup.coach;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.format.TextStyle;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.function.Consumer;
import java.util.stream.Collectors;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.FindAndModifyOptions;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.mongodb.client.result.UpdateResult;

import vn.levelup.coach.CoachRules.Action;
import vn.levelup.coach.CoachRules.Fact;
import vn.levelup.coach.CoachRules.Injury;
import vn.levelup.coach.CoachRules.Proposal;
import vn.levelup.coach.CoachRules.UserCtx;
import vn.levelup.common.LocalDates;
import vn.levelup.exercises.Exercise;
import vn.levelup.exercises.ExerciseRepository;
import vn.levelup.plans.PlanView;
import vn.levelup.plans.TrainingPlan;
import vn.levelup.users.User;

/**
 * Chat với coach (docs/04-backend-flow.html, mục Chat với coach). AI chỉ đề xuất:
 * backend kiểm tra đề xuất, lưu thành thẻ hành động, người dùng bấm áp dụng mới sửa kế hoạch.
 * Không có ANTHROPIC_API_KEY hoặc Claude lỗi thì trả lời bằng luật từ khóa.
 */
@Service
public class CoachService {

    private static final Logger log = LoggerFactory.getLogger(CoachService.class);

    static final int HISTORY = 20;
    static final int MAX_TOKENS = 800;

    private final MongoTemplate mongo;
    private final ExerciseRepository exercises;
    private final AiClient ai;
    private final Clock clock;
    private final int dailyLimit;
    private final String model;

    public CoachService(MongoTemplate mongo, ExerciseRepository exercises, AiClient ai, Clock clock,
                        @Value("${levelup.coach.daily-limit:30}") int dailyLimit,
                        @Value("${levelup.ai.model:claude}") String model) {
        this.mongo = mongo;
        this.exercises = exercises;
        this.ai = ai;
        this.clock = clock;
        this.dailyLimit = dailyLimit;
        this.model = model;
    }

    // ------------------------------------------------------------------
    // POST /coach/messages
    // ------------------------------------------------------------------

    public CoachViews.SendResponse send(User user, String text) {
        return send(user, text, t -> { });
    }

    /**
     * Như send, nhưng onReplyText nhận dần chữ câu trả lời khi AI đang viết (POST /coach/messages/stream).
     * Bản cuối (đã kiểm tra đề xuất, đã lưu) vẫn là giá trị trả về; chữ đã phát có thể khác nếu AI lỗi.
     */
    public CoachViews.SendResponse send(User user, String text, Consumer<String> onReplyText) {
        ObjectId userId = new ObjectId(user.id());
        LocalDate today = LocalDates.today(user.timezone(), clock);
        int used = consumeQuota(userId, today.toString());
        Instant now = clock.instant();
        String message = text.trim();

        Document userDoc = mongo.findById(userId, Document.class, "users");
        List<Fact> memory = readMemory(userDoc);
        TrainingPlan plan = currentPlan(userId, today);
        Map<String, Exercise> byId = allExercises();
        List<Exercise> active = byId.values().stream().filter(e -> !Boolean.FALSE.equals(e.isActive())).toList();
        UserCtx ctx = userCtx(user);
        TrainingPlan.Session next = nextPlanned(plan, today);

        Proposal p = null;
        String source = "rules";
        if (ai.available()) {
            List<Exercise> safe = SafeSessions.safeList(active, ctx.location(), ctx.equipment(), ctx.injuries());
            String system = CoachPrompts.chatSystem(ctx.style(), userData(user, ctx, memory, plan, byId, safe, today));
            Optional<Proposal> fromAi = askAi(system, conversation(recentMessages(userId), message), onReplyText);
            if (fromAi.isPresent()) {
                p = fromAi.get();
                source = "ai";
            }
        }
        if (p == null) {
            p = CoachRules.fallback(message, ctx, next, active);
        }

        Set<String> injuries = withInjury(ctx.injuries(), p.injury());
        if (p.action() != null) {
            Optional<String> error = CoachRules.validateAction(p.action(), plan, byId, ctx.location(),
                ctx.equipment(), injuries);
            if (error.isPresent()) {
                log.info("Bỏ đề xuất của coach cho user {}: {}", userId, error.get());
                p = p.withAction(null);
            }
        }
        if (p.action() == null && p.injury() != null && next != null) {
            // Báo đau mà AI không đề xuất buổi an toàn hơn: backend tự đề xuất
            p = p.withAction(CoachRules.injuryAction(next, ctx, p.injury().bodyArea(), active));
        }
        Injury newInjury = p.injury() != null && !ctx.injuries().contains(p.injury().bodyArea()) ? p.injury() : null;

        // Trí nhớ dài hạn: mẩu ngắn đã kiểm tra, chống trùng, tối đa 20
        List<Fact> incoming = new ArrayList<>(p.memory().stream().map(f -> Fact.of(f, now)).toList());
        if (p.injury() != null) {
            incoming.add(CoachRules.injuryFact(p.injury(), today, now));
        }
        if (!incoming.isEmpty()) {
            List<Fact> merged = CoachRules.mergeMemory(memory, incoming);
            mongo.updateFirst(Query.query(Criteria.where("_id").is(userId)),
                Update.update("coachMemory", merged.stream().map(CoachService::factDocument).toList()), "users");
        }

        // Thẻ hành động: chỉ lưu đề xuất, chưa sửa kế hoạch
        Document card = null;
        PlanView.SessionView preview = null;
        if (p.action() != null) {
            Action a = p.action();
            card = new Document("type", "adjust_session").append("status", "proposed")
                .append("planId", new ObjectId(plan.id()))
                .append("sessionId", new ObjectId(a.sessionId()))
                .append("change", a.change())
                .append("reason", a.reason())
                .append("adjustedReason", CoachRules.adjustedReason(a.change(), p.injury()));
            if (a.fromExerciseId() != null) {
                card.append("fromExerciseId", new ObjectId(a.fromExerciseId()))
                    .append("toExerciseId", new ObjectId(a.toExerciseId()));
            }
            TrainingPlan.Session session = findSession(plan, a.sessionId());
            List<Exercise> safe = SafeSessions.safeList(active, ctx.location(), ctx.equipment(), injuries);
            TrainingPlan.Session changed = SafeSessions.applyChange(session, a.change(), a.fromExerciseId(),
                a.toExerciseId() == null ? null : byId.get(a.toExerciseId()), card.getString("adjustedReason"),
                byId, safe);
            preview = sessionView(changed, byId);
        } else if (newInjury != null) {
            card = new Document("type", "add_injury").append("status", "proposed")
                .append("reason", "Ghi nhận vùng đau để các buổi sau tránh");
        }
        if (card != null && newInjury != null) {
            Document injury = new Document("bodyArea", newInjury.bodyArea());
            if (newInjury.note() != null) {
                injury.append("note", newInjury.note());
            }
            card.append("injury", injury);
        }

        Document userMsg = new Document("_id", new ObjectId()).append("userId", userId).append("role", "user")
            .append("content", message).append("trigger", "user").append("createdAt", Date.from(now));
        // Tin coach sau tin người dùng 1 ms để thứ tự lịch sử luôn đúng
        Document coachMsg = new Document("_id", new ObjectId()).append("userId", userId).append("role", "coach")
            .append("content", p.reply()).append("trigger", "user")
            .append("model", "ai".equals(source) ? model : "rules")
            .append("createdAt", Date.from(now.plusMillis(1)));
        if (card != null) {
            coachMsg.append("card", card);
            if (card.get("sessionId") != null) {
                coachMsg.append("relatedSessionId", card.get("sessionId"));
            }
        }
        mongo.insert(List.of(userMsg, coachMsg), "coach_messages");

        CoachViews.MessageView reply = messageView(coachMsg, byId);
        if (preview != null) {
            CoachViews.CardView c = reply.card();
            reply = new CoachViews.MessageView(reply.id(), reply.role(), reply.content(), reply.createdAt(),
                new CoachViews.CardView(c.type(), c.status(), c.planId(), c.sessionId(), c.change(),
                    c.fromExerciseId(), c.fromExerciseName(), c.toExerciseId(), c.toExerciseName(), c.reason(),
                    c.injury(), preview));
        }
        return new CoachViews.SendResponse(messageView(userMsg, byId), reply, Math.max(0, dailyLimit - used), source);
    }

    /** Tăng lượt chat hôm nay chỉ khi còn lượt; hết lượt thì 429 COACH_LIMIT. */
    private int consumeQuota(ObjectId userId, String localDate) {
        if (dailyLimit <= 0) {
            throw limitReached();
        }
        Query belowLimit = Query.query(Criteria.where("userId").is(userId).and("localDate").is(localDate)
            .orOperator(Criteria.where("usage.coachMessages").lt(dailyLimit),
                Criteria.where("usage.coachMessages").exists(false)));
        try {
            // Hết lượt thì query không khớp, upsert đụng unique index (userId, localDate)
            Document day = mongo.findAndModify(belowLimit,
                new Update().inc("usage.coachMessages", 1).setOnInsert("userId", userId)
                    .setOnInsert("localDate", localDate),
                FindAndModifyOptions.options().upsert(true).returnNew(true), Document.class, "daily_stats");
            return ((Number) ((Document) day.get("usage")).get("coachMessages")).intValue();
        } catch (DuplicateKeyException e) {
            throw limitReached();
        }
    }

    private static ResponseStatusException limitReached() {
        return new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS, "COACH_LIMIT");
    }

    /** Hỏi Claude; JSON sai thì hỏi lại 1 lần, vẫn sai hoặc AI lỗi thì empty để dùng luật cố định. */
    private Optional<Proposal> askAi(String system, List<AiClient.Message> messages, Consumer<String> onReplyText) {
        try {
            // Lần đầu stream: tách dần chuỗi "reply" để app hiện chữ ngay; lần sửa JSON thì không stream
            ReplyExtractor reply = new ReplyExtractor();
            String raw = ai.stream(system, messages, MAX_TOKENS, chunk -> {
                String text = reply.feed(chunk);
                if (!text.isEmpty()) {
                    onReplyText.accept(text);
                }
            });
            Optional<Proposal> parsed = CoachRules.parseAi(raw);
            if (parsed.isPresent()) {
                return parsed;
            }
            List<AiClient.Message> retry = new ArrayList<>(messages);
            retry.add(AiClient.Message.assistant(raw == null || raw.isBlank() ? "{}" : raw));
            retry.add(AiClient.Message.user(CoachPrompts.FIX_JSON));
            parsed = CoachRules.parseAi(ai.complete(system, retry, MAX_TOKENS));
            if (parsed.isEmpty()) {
                log.warn("Claude trả JSON sai 2 lần, dùng luật cố định");
            }
            return parsed;
        } catch (AiClient.AiUnavailableException e) {
            return Optional.empty();
        } catch (RuntimeException e) {
            log.warn("Gọi coach AI lỗi, dùng luật cố định: {}", e.toString());
            return Optional.empty();
        }
    }

    /** Lịch sử cho Claude: user/assistant xen kẽ, bắt đầu và kết thúc bằng user. */
    static List<AiClient.Message> conversation(List<Document> history, String text) {
        List<AiClient.Message> out = new ArrayList<>();
        for (Document d : history) {
            String role = d.getString("role");
            String content = d.getString("content");
            if (content == null || content.isBlank() || !("user".equals(role) || "coach".equals(role))) {
                continue;
            }
            String r = "user".equals(role) ? "user" : "assistant";
            if (out.isEmpty() && "assistant".equals(r)) {
                continue;
            }
            String t = "user".equals(r) ? content : CoachRules.replyJson(content);
            appendMerged(out, r, t);
        }
        appendMerged(out, "user", text);
        return out;
    }

    private static void appendMerged(List<AiClient.Message> out, String role, String text) {
        if (!out.isEmpty() && out.get(out.size() - 1).role().equals(role)) {
            AiClient.Message last = out.remove(out.size() - 1);
            out.add(new AiClient.Message(role, last.text() + "\n" + text));
        } else {
            out.add(new AiClient.Message(role, text));
        }
    }

    private List<Document> recentMessages(ObjectId userId) {
        List<Document> docs = new ArrayList<>(mongo.find(Query.query(Criteria.where("userId").is(userId))
                .with(Sort.by(Sort.Direction.DESC, "createdAt", "_id")).limit(HISTORY),
            Document.class, "coach_messages"));
        Collections.reverse(docs);
        return docs;
    }

    /** Dữ liệu người dùng cho system prompt: hồ sơ, chấn thương, trí nhớ, kế hoạch tuần, bài an toàn để đổi. */
    private static String userData(User user, UserCtx ctx, List<Fact> memory, TrainingPlan plan,
                                   Map<String, Exercise> byId, List<Exercise> safe, LocalDate today) {
        StringBuilder b = new StringBuilder();
        User.Profile p = user.profile();
        b.append("Tên: ").append(ctx.name()).append('\n');
        b.append("Hôm nay: ").append(today).append(" (")
            .append(today.getDayOfWeek().getDisplayName(TextStyle.FULL, Locale.forLanguageTag("vi"))).append(")\n");
        if (p != null) {
            b.append("Mục tiêu: ").append(p.goal()).append("; kinh nghiệm: ").append(p.experience())
                .append("; nơi tập: ").append(p.location()).append("; dụng cụ: ")
                .append(p.equipment() == null || p.equipment().isEmpty() ? "không có" : String.join(", ", p.equipment()))
                .append("; thời lượng mong muốn: ").append(p.sessionMinutes()).append(" phút\n");
            if (p.motivationText() != null && !p.motivationText().isBlank()) {
                b.append("Lý do bắt đầu tập: ").append(p.motivationText()).append('\n');
            }
        }
        b.append("Vùng đang đau: ").append(ctx.injuries().isEmpty() ? "không có" : String.join(", ", ctx.injuries()))
            .append('\n');
        if (!memory.isEmpty()) {
            b.append("Điều coach đã biết về người dùng:\n");
            memory.forEach(f -> b.append("- ").append(f.value()).append('\n'));
        }
        if (plan == null) {
            b.append("Kế hoạch: chưa có kế hoạch đang áp dụng (không đề xuất action).\n");
        } else {
            b.append("Kế hoạch tuần ").append(plan.weekStart()).append(":\n");
            for (TrainingPlan.Session s : plan.sessions()) {
                b.append("- sessionId ").append(s.id().toHexString()).append(" | ").append(s.scheduledDate())
                    .append(s.scheduledTime() == null ? "" : " " + s.scheduledTime()).append(" | ").append(s.title())
                    .append(" | ").append(s.durationMin()).append(" phút | ").append(s.status())
                    .append(" | ").append(s.variant()).append('\n');
                if (s.items() != null) {
                    for (TrainingPlan.Item i : s.items()) {
                        String id = i.exerciseId().toHexString();
                        Exercise e = byId.get(id);
                        b.append("    • ").append(id).append(" | ").append(e == null ? "?" : e.nameVi()).append(" | ")
                            .append(i.targetSets()).append(" hiệp x ")
                            .append(i.targetReps() != null ? i.targetReps() + " lần" : i.targetDurationSec() + " giây")
                            .append('\n');
                    }
                }
            }
        }
        b.append("Bài an toàn có thể đổi sang (id | tên | nhóm cơ):\n");
        safe.forEach(e -> b.append("- ").append(e.id()).append(" | ").append(e.nameVi()).append(" | ")
            .append(e.primaryMuscle()).append('\n'));
        return b.toString();
    }

    // ------------------------------------------------------------------
    // POST /coach/messages/{id}/actions/apply
    // ------------------------------------------------------------------

    /**
     * Áp dụng thẻ hành động đang proposed: kiểm tra lại (kế hoạch, chấn thương có thể đã đổi),
     * sửa đúng buổi đó bằng sessions.$ (không ghi đè cả kế hoạch), ghi chấn thương nếu có, đánh dấu applied.
     * Trả kế hoạch sau khi sửa; thẻ chỉ ghi chấn thương mà không có kế hoạch đang áp dụng thì trả null.
     */
    @Transactional
    public PlanView apply(User user, String messageId) {
        ObjectId userId = new ObjectId(user.id());
        if (!CoachRules.isHex(messageId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "MESSAGE_NOT_FOUND");
        }
        Query mine = Query.query(Criteria.where("_id").is(new ObjectId(messageId)).and("userId").is(userId)
            .and("role").is("coach"));
        Document msg = mongo.findOne(mine, Document.class, "coach_messages");
        if (msg == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "MESSAGE_NOT_FOUND");
        }
        if (!(msg.get("card") instanceof Document card)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "NO_ACTION");
        }
        // Đánh dấu trước, có điều kiện: hai request áp dụng cùng lúc thì chỉ một cái chạy
        Instant now = clock.instant();
        UpdateResult marked = mongo.updateFirst(
            Query.query(Criteria.where("_id").is(msg.getObjectId("_id")).and("userId").is(userId)
                .and("card.status").is("proposed")),
            new Update().set("card.status", "applied").set("card.appliedAt", Date.from(now)), "coach_messages");
        if (marked.getModifiedCount() == 0) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "ACTION_NOT_PROPOSED");
        }

        UserCtx ctx = userCtx(user);
        Injury injury = card.get("injury") instanceof Document d
            ? new Injury(d.getString("bodyArea"), d.getString("note")) : null;
        Set<String> injuries = withInjury(ctx.injuries(), injury);
        Map<String, Exercise> byId = allExercises();
        LocalDate today = LocalDates.today(user.timezone(), clock);

        TrainingPlan plan;
        if ("adjust_session".equals(card.getString("type"))) {
            plan = mongo.findOne(Query.query(Criteria.where("_id").is(card.getObjectId("planId"))
                .and("userId").is(userId).and("status").is("active")), TrainingPlan.class);
            Action a = new Action("adjust_session", card.getObjectId("sessionId").toHexString(),
                card.getString("change"), hex(card.get("fromExerciseId")), hex(card.get("toExerciseId")),
                card.getString("reason"));
            Optional<String> error = CoachRules.validateAction(a, plan, byId, ctx.location(), ctx.equipment(), injuries);
            if (error.isPresent()) {
                log.info("Không áp dụng được thẻ {}: {}", messageId, error.get());
                throw new ResponseStatusException(HttpStatus.CONFLICT, "ACTION_INVALID");
            }
            List<Exercise> active = byId.values().stream().filter(e -> !Boolean.FALSE.equals(e.isActive())).toList();
            List<Exercise> safe = SafeSessions.safeList(active, ctx.location(), ctx.equipment(), injuries);
            TrainingPlan.Session changed = SafeSessions.applyChange(findSession(plan, a.sessionId()), a.change(),
                a.fromExerciseId(), a.toExerciseId() == null ? null : byId.get(a.toExerciseId()),
                card.getString("adjustedReason"), byId, safe);

            ObjectId sessionId = new ObjectId(a.sessionId());
            Query planned = Query.query(Criteria.where("_id").is(new ObjectId(plan.id())).and("userId").is(userId)
                .and("status").is("active")
                .and("sessions").elemMatch(Criteria.where("_id").is(sessionId).and("status").is("planned")));
            Update update = new Update()
                .set("sessions.$.status", changed.status())
                .set("sessions.$.variant", changed.variant())
                .set("sessions.$.durationMin", changed.durationMin())
                .set("sessions.$.items", changed.items().stream().map(CoachService::itemDocument).toList());
            if (changed.adjustedReason() != null) {
                update.set("sessions.$.adjustedReason", changed.adjustedReason());
            }
            if (mongo.updateFirst(planned, update, TrainingPlan.class).getMatchedCount() == 0) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "ACTION_INVALID");
            }
        } else {
            plan = null;
        }

        if (injury != null && !ctx.injuries().contains(injury.bodyArea())) {
            Document doc = new Document("bodyArea", injury.bodyArea()).append("active", true)
                .append("reportedAt", Date.from(now));
            if (injury.note() != null) {
                doc.append("note", injury.note());
            }
            mongo.updateFirst(Query.query(Criteria.where("_id").is(userId)), new Update().push("injuries", doc), "users");
        }

        TrainingPlan updated = plan != null
            ? mongo.findById(new ObjectId(plan.id()), TrainingPlan.class)
            : currentPlan(userId, today);
        return updated == null ? null : PlanView.of(updated, names(byId));
    }

    // ------------------------------------------------------------------
    // GET /coach/messages
    // ------------------------------------------------------------------

    public CoachViews.HistoryResponse history(User user, Instant before, int limit) {
        ObjectId userId = new ObjectId(user.id());
        int size = Math.max(1, Math.min(50, limit));
        Criteria c = Criteria.where("userId").is(userId);
        if (before != null) {
            c = c.and("createdAt").lt(Date.from(before));
        }
        List<Document> docs = mongo.find(Query.query(c).with(Sort.by(Sort.Direction.DESC, "createdAt", "_id"))
            .limit(size), Document.class, "coach_messages");
        Map<String, Exercise> byId = docs.stream().anyMatch(d -> d.get("card") != null) ? allExercises() : Map.of();
        List<CoachViews.MessageView> views = docs.stream().map(d -> messageView(d, byId)).toList();
        Instant next = docs.size() == size ? docs.get(docs.size() - 1).getDate("createdAt").toInstant() : null;
        return new CoachViews.HistoryResponse(views, next);
    }

    // ------------------------------------------------------------------

    private static CoachViews.MessageView messageView(Document d, Map<String, Exercise> byId) {
        CoachViews.CardView card = null;
        if (d.get("card") instanceof Document c) {
            String from = hex(c.get("fromExerciseId"));
            String to = hex(c.get("toExerciseId"));
            CoachViews.InjuryView injury = c.get("injury") instanceof Document i
                ? new CoachViews.InjuryView(i.getString("bodyArea"), i.getString("note")) : null;
            card = new CoachViews.CardView(c.getString("type"), c.getString("status"), hex(c.get("planId")),
                hex(c.get("sessionId")), c.getString("change"), from, name(byId, from), to, name(byId, to),
                c.getString("reason"), injury, null);
        }
        return new CoachViews.MessageView(d.getObjectId("_id").toHexString(), d.getString("role"),
            d.getString("content"), d.getDate("createdAt").toInstant(), card);
    }

    private static String name(Map<String, Exercise> byId, String id) {
        Exercise e = id == null ? null : byId.get(id);
        return e == null ? null : e.nameVi();
    }

    private static String hex(Object id) {
        return id instanceof ObjectId o ? o.toHexString() : null;
    }

    private static PlanView.SessionView sessionView(TrainingPlan.Session s, Map<String, Exercise> byId) {
        List<PlanView.ItemView> items = s.items() == null ? List.of() : s.items().stream()
            .map(i -> new PlanView.ItemView(i.exerciseId().toHexString(), name(byId, i.exerciseId().toHexString()),
                i.targetSets(), i.targetReps(), i.targetDurationSec(), i.restSec()))
            .toList();
        return new PlanView.SessionView(s.id().toHexString(), s.scheduledDate(), s.scheduledTime(), s.title(),
            s.durationMin(), s.variant(), s.status(), items, s.adjustedReason());
    }

    static Document itemDocument(TrainingPlan.Item i) {
        Document d = new Document("exerciseId", i.exerciseId());
        if (i.targetSets() != null) {
            d.append("targetSets", i.targetSets());
        }
        if (i.targetReps() != null) {
            d.append("targetReps", i.targetReps());
        }
        if (i.targetDurationSec() != null) {
            d.append("targetDurationSec", i.targetDurationSec());
        }
        if (i.restSec() != null) {
            d.append("restSec", i.restSec());
        }
        return d;
    }

    private static Document factDocument(Fact f) {
        return new Document("key", f.key()).append("value", f.value()).append("updatedAt", Date.from(f.updatedAt()));
    }

    private static List<Fact> readMemory(Document userDoc) {
        if (userDoc == null) {
            return List.of();
        }
        return userDoc.getList("coachMemory", Document.class, List.of()).stream()
            .filter(d -> d.getString("key") != null && d.getString("value") != null)
            .map(d -> new Fact(d.getString("key"), d.getString("value"),
                d.getDate("updatedAt") == null ? Instant.EPOCH : d.getDate("updatedAt").toInstant()))
            .toList();
    }

    private Map<String, Exercise> allExercises() {
        Map<String, Exercise> byId = new HashMap<>();
        exercises.findAll().forEach(e -> byId.put(e.id(), e));
        return byId;
    }

    private static Map<String, String> names(Map<String, Exercise> byId) {
        return byId.values().stream().collect(Collectors.toMap(Exercise::id, Exercise::nameVi));
    }

    static UserCtx userCtx(User user) {
        User.Profile p = user.profile();
        String name = user.displayName() == null ? "" : user.displayName().trim();
        String style = p == null || p.coachStyle() == null ? "supportive" : p.coachStyle();
        Set<String> equipment = p == null || p.equipment() == null ? Set.of() : Set.copyOf(p.equipment());
        Set<String> injuries = user.injuries() == null ? Set.of() : user.injuries().stream()
            .filter(i -> !Boolean.FALSE.equals(i.active()) && i.bodyArea() != null)
            .map(User.Injury::bodyArea).collect(Collectors.toSet());
        return new UserCtx(name, style, p == null ? null : p.location(), equipment, injuries);
    }

    private static Set<String> withInjury(Set<String> injuries, Injury injury) {
        if (injury == null) {
            return injuries;
        }
        Set<String> all = new HashSet<>(injuries);
        all.add(injury.bodyArea());
        return all;
    }

    /** Kế hoạch đang áp dụng: tuần này, nếu chưa có thì kế hoạch active gần nhất (như GET /plans/current). */
    private TrainingPlan currentPlan(ObjectId userId, LocalDate today) {
        String thisWeek = LocalDates.weekStart(today).toString();
        TrainingPlan plan = mongo.findOne(Query.query(Criteria.where("userId").is(userId).and("status").is("active")
            .and("weekStart").is(thisWeek)), TrainingPlan.class);
        if (plan == null) {
            plan = mongo.findOne(Query.query(Criteria.where("userId").is(userId).and("status").is("active"))
                .with(Sort.by(Sort.Direction.DESC, "weekStart")), TrainingPlan.class);
        }
        return plan;
    }

    /** Buổi planned sắp tới: từ hôm nay trở đi, sớm nhất trước. */
    static TrainingPlan.Session nextPlanned(TrainingPlan plan, LocalDate today) {
        if (plan == null || plan.sessions() == null) {
            return null;
        }
        String day = today.toString();
        return plan.sessions().stream()
            .filter(s -> "planned".equals(s.status()) && s.scheduledDate() != null
                && s.scheduledDate().compareTo(day) >= 0)
            .min((a, b) -> (a.scheduledDate() + a.scheduledTime()).compareTo(b.scheduledDate() + b.scheduledTime()))
            .orElse(null);
    }

    private static TrainingPlan.Session findSession(TrainingPlan plan, String sessionId) {
        return plan.sessions().stream().filter(s -> s.id().toHexString().equals(sessionId)).findFirst().orElseThrow();
    }
}
