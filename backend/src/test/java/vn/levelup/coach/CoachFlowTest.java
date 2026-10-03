package vn.levelup.coach;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Clock;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

import jakarta.servlet.Filter;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.RequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import com.jayway.jsonpath.DocumentContext;
import com.jayway.jsonpath.JsonPath;

import vn.levelup.common.LocalDates;
import vn.levelup.exercises.Exercise;
import vn.levelup.exercises.ExerciseRepository;

/**
 * Chat với coach trên MongoDB dev (localhost:27018, cần seed bài tập). Không bao giờ gọi Claude thật:
 * AiClient là mock, trả JSON giả hoặc ném AiUnavailableException để chạy luật dự phòng.
 */
@SpringBootTest
@ActiveProfiles("dev")
class CoachFlowTest {

    @Autowired WebApplicationContext context;
    @Autowired MongoTemplate mongo;
    @Autowired ExerciseRepository exercises;
    @MockitoBean AiClient ai;

    MockMvc mvc;
    String token;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(context)
            .addFilters(context.getBean("springSecurityFilterChain", Filter.class)).build();
        token = "Bearer dev-it-" + UUID.randomUUID();
    }

    @AfterEach
    void cleanUp() {
        Document user = userDoc();
        if (user == null) {
            return;
        }
        Query mine = Query.query(Criteria.where("userId").is(user.getObjectId("_id")));
        for (String c : new String[] {"workout_logs", "training_plans", "weekly_streaks", "personal_records",
                                      "daily_stats", "coach_messages", "weekly_reviews"}) {
            mongo.remove(mine, c);
        }
        mongo.remove(Query.query(Criteria.where("_id").is(user.getObjectId("_id"))), "users");
    }

    private Document userDoc() {
        return mongo.findOne(Query.query(Criteria.where("authUid").is(token.substring("Bearer dev-".length()))),
            Document.class, "users");
    }

    private DocumentContext call(RequestBuilder req, int expected) throws Exception {
        String body = mvc.perform(req).andExpect(status().is(expected)).andReturn().getResponse()
            .getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        return JsonPath.parse(body.isEmpty() ? "{}" : body);
    }

    private DocumentContext chat(String text, int expected) throws Exception {
        return call(post("/coach/messages").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content("{\"text\":\"" + text + "\"}"), expected);
    }

    private void onboard() throws Exception {
        String body = """
            {"displayName":"Minh","goal":"lose_fat","gender":"male","birthYear":1995,"heightCm":170,
             "weightKg":70,"experience":"beginner","location":"home","equipment":[],"injuries":[],
             "availability":[{"weekday":1,"slot":"evening"},{"weekday":2,"slot":"evening"},
               {"weekday":3,"slot":"evening"},{"weekday":4,"slot":"evening"},{"weekday":5,"slot":"evening"},
               {"weekday":6,"slot":"evening"},{"weekday":7,"slot":"evening"}],
             "sessionMinutes":15,"coachStyle":"supportive","timezone":"Asia/Ho_Chi_Minh"}""";
        call(post("/onboarding").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content(body), 200);
    }

    /** Buổi planned sớm nhất (onboarding xếp buổi từ hôm nay trở đi). */
    private Map<String, Object> nextSession() throws Exception {
        DocumentContext plan = call(get("/plans/current").header("Authorization", token), 200);
        List<Map<String, Object>> sessions = plan.read("$.sessions[?(@.status == 'planned')]");
        return sessions.get(0);
    }

    @SuppressWarnings("unchecked")
    private static List<String> itemIds(Map<String, Object> session) {
        return ((List<Map<String, Object>>) session.get("items")).stream()
            .map(i -> (String) i.get("exerciseId")).toList();
    }

    @Test
    void ai_de_xuat_doi_bai_hop_le_roi_ap_dung() throws Exception {
        onboard();
        Map<String, Object> session = nextSession();
        String sessionId = (String) session.get("id");
        List<String> inSession = itemIds(session);
        String from = inSession.get(0);
        String to = exercises.findByIsActiveTrue().stream()
            .filter(e -> SafeSessions.isSafe(e, "home", Set.of(), Set.of()))
            .map(Exercise::id).filter(id -> !inSession.contains(id)).findFirst().orElseThrow();

        String json = """
            {"reply":"Đổi bài nhé Minh","action":{"type":"adjust_session","sessionId":"%s",
             "change":"swap_exercise","fromExerciseId":"%s","toExerciseId":"%s","reason":"Đổi cho đỡ chán"},
             "memory":["Thích đổi bài mới"]}""".formatted(sessionId, from, to);
        when(ai.available()).thenReturn(true);
        // Lần đầu trả sai định dạng: backend hỏi lại 1 lần
        when(ai.complete(anyString(), anyList(), anyInt())).thenReturn("không phải JSON", json);

        DocumentContext r = chat("đổi bài giúp mình", 200);
        verify(ai, times(2)).complete(anyString(), anyList(), anyInt());
        assertEquals("ai", r.read("$.source"));
        assertEquals("Đổi bài nhé Minh", r.read("$.reply.content"));
        assertEquals("proposed", r.read("$.reply.card.status"));
        assertEquals(to, r.read("$.reply.card.toExerciseId"));
        assertNotNull(r.read("$.reply.card.toExerciseName"));
        assertTrue(r.<List<String>>read("$.reply.card.preview.items[*].exerciseId").contains(to));
        assertEquals(29, r.<Integer>read("$.remainingToday"));
        String messageId = r.read("$.reply.id");

        // Chưa áp dụng: kế hoạch chưa đổi
        assertEquals(inSession, itemIds(nextSession()));

        DocumentContext plan = call(post("/coach/messages/" + messageId + "/actions/apply")
            .header("Authorization", token), 200);
        List<String> after = plan.read("$.sessions[?(@.id == '" + sessionId + "')].items[*].exerciseId");
        assertTrue(after.contains(to));
        assertFalse(after.contains(from));
        assertEquals(List.of("coach_swap"), plan.read("$.sessions[?(@.id == '" + sessionId + "')].adjustedReason"));

        // Áp dụng lần hai bị từ chối
        DocumentContext again = call(post("/coach/messages/" + messageId + "/actions/apply")
            .header("Authorization", token), 409);
        assertEquals("ACTION_NOT_PROPOSED", again.read("$.code"));

        // Lịch sử: mới nhất trước, thẻ đã applied; trí nhớ đã lưu
        DocumentContext history = call(get("/coach/messages?limit=20").header("Authorization", token), 200);
        assertEquals(2, history.<Integer>read("$.messages.length()"));
        assertEquals("coach", history.read("$.messages[0].role"));
        assertEquals("applied", history.read("$.messages[0].card.status"));
        assertEquals("user", history.read("$.messages[1].role"));
        List<Document> memory = userDoc().getList("coachMemory", Document.class);
        assertEquals("Thích đổi bài mới", memory.get(0).getString("value"));

        // Trang cũ hơn: hết
        String before = history.read("$.messages[0].createdAt");
        DocumentContext older = call(get("/coach/messages").param("before", before).param("limit", "1")
            .header("Authorization", token), 200);
        assertEquals("user", older.read("$.messages[0].role"));
    }

    @Test
    void bai_dich_khong_ton_tai_bi_tu_choi() throws Exception {
        onboard();
        Map<String, Object> session = nextSession();
        String json = """
            {"reply":"Đổi bài nhé","action":{"type":"adjust_session","sessionId":"%s",
             "change":"swap_exercise","fromExerciseId":"%s","toExerciseId":"%s","reason":"x"}}"""
            .formatted(session.get("id"), itemIds(session).get(0), "0".repeat(24));
        when(ai.available()).thenReturn(true);
        when(ai.complete(anyString(), anyList(), anyInt())).thenReturn(json);

        DocumentContext r = chat("đổi bài giúp mình", 200);
        assertEquals("Đổi bài nhé", r.read("$.reply.content"));
        assertNull(r.read("$.reply.card"));

        // Thẻ trong database trỏ tới bài không tồn tại: áp dụng bị chặn khi kiểm tra lại
        String messageId = r.read("$.reply.id");
        String planId = call(get("/plans/current").header("Authorization", token), 200).read("$.id");
        mongo.updateFirst(Query.query(Criteria.where("_id").is(new ObjectId(messageId))),
            Update.update("card", new Document("type", "adjust_session").append("status", "proposed")
                .append("planId", new ObjectId(planId))
                .append("sessionId", new ObjectId((String) session.get("id")))
                .append("change", "swap_exercise")
                .append("fromExerciseId", new ObjectId(itemIds(session).get(0)))
                .append("toExerciseId", new ObjectId("0".repeat(24)))
                .append("adjustedReason", "coach_swap")), "coach_messages");
        DocumentContext rejected = call(post("/coach/messages/" + messageId + "/actions/apply")
            .header("Authorization", token), 409);
        assertEquals("ACTION_INVALID", rejected.read("$.code"));
        assertEquals(itemIds(session), itemIds(nextSession()));
    }

    @Test
    void ai_loi_thi_dung_luat_dau_vai_va_ap_dung() throws Exception {
        onboard();
        when(ai.available()).thenReturn(true);
        when(ai.complete(anyString(), anyList(), anyInt()))
            .thenThrow(new AiClient.AiUnavailableException("Coach đang bận, thử lại nhé", null));

        DocumentContext r = chat("hôm nay đau vai", 200);
        assertEquals("rules", r.read("$.source"));
        assertEquals("shoulder", r.read("$.reply.card.injury.bodyArea"));
        assertEquals("proposed", r.read("$.reply.card.status"));
        String sessionId = r.read("$.reply.card.sessionId");
        assertNotNull(sessionId);
        // Chưa áp dụng: chưa ghi chấn thương
        assertTrue(userDoc().getList("injuries", Document.class, List.of()).isEmpty());

        DocumentContext plan = call(post("/coach/messages/" + r.read("$.reply.id") + "/actions/apply")
            .header("Authorization", token), 200);
        List<String> after = plan.read("$.sessions[?(@.id == '" + sessionId + "')].items[*].exerciseId");
        Map<String, Exercise> byId = exercises.findAll().stream().collect(Collectors.toMap(Exercise::id, e -> e));
        assertTrue(after.stream().noneMatch(id -> byId.get(id).contraindicationsOrEmpty().contains("shoulder")));
        assertEquals(List.of("pain_shoulder"), plan.read("$.sessions[?(@.id == '" + sessionId + "')].adjustedReason"));

        Document user = userDoc();
        Document injury = user.getList("injuries", Document.class).get(0);
        assertEquals("shoulder", injury.getString("bodyArea"));
        assertTrue(injury.getBoolean("active"));
        assertEquals("injury_shoulder", user.getList("coachMemory", Document.class).get(0).getString("key"));
    }

    @Test
    void het_luot_trong_ngay_tra_429() throws Exception {
        onboard();
        when(ai.available()).thenReturn(false);
        ObjectId userId = userDoc().getObjectId("_id");
        String today = LocalDates.today("Asia/Ho_Chi_Minh", Clock.systemUTC()).toString();
        mongo.upsert(Query.query(Criteria.where("userId").is(userId).and("localDate").is(today)),
            new Update().set("usage.coachMessages", 29), "daily_stats");

        DocumentContext last = chat("chào coach", 200);
        assertEquals(0, last.<Integer>read("$.remainingToday"));
        assertEquals("rules", last.read("$.source"));
        DocumentContext limited = chat("chào coach", 429);
        assertEquals("COACH_LIMIT", limited.read("$.code"));
        assertEquals(2, mongo.count(Query.query(Criteria.where("userId").is(userId)), "coach_messages"));
    }

    @Test
    void tin_rong_hoac_qua_dai_bi_tu_choi() throws Exception {
        onboard();
        assertEquals("VALIDATION_ERROR", chat("", 400).read("$.code"));
        assertEquals("VALIDATION_ERROR", chat("a".repeat(1001), 400).read("$.code"));
        assertEquals("MESSAGE_NOT_FOUND", call(post("/coach/messages/" + "0".repeat(24) + "/actions/apply")
            .header("Authorization", token), 404).read("$.code"));
    }
}
