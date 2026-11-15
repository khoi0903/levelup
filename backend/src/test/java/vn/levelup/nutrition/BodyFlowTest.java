package vn.levelup.nutrition;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.List;

import org.bson.Document;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import com.jayway.jsonpath.DocumentContext;
import vn.levelup.FlowTestBase;
import vn.levelup.coach.ai.AiClient;
import vn.levelup.nutrition.rules.BodyRules;
import vn.levelup.nutrition.rules.NutritionCalculator;

/**
 * Hồ sơ cơ thể (bodyFatPct, focusMuscles, chiều cao, cân nặng), GET /me/body, GET /me/muscles/week,
 * POST /meals/parse và GET /foods/popular. Chạy trên MongoDB dev (localhost:27018, đã seed bài tập và món ăn).
 * AiClient là mock: test không bao giờ gọi AI thật.
 */
@SpringBootTest
@ActiveProfiles("dev")
class BodyFlowTest extends FlowTestBase {

    static final ZoneId VN = ZoneId.of("Asia/Ho_Chi_Minh");
    static final String PHO_JSON = """
        {"dishes":[{"name":"Beef pho","nameVi":"Phở bò","ingredients":["bánh phở","thịt bò"],
          "portionGrams":1100,"confidence":0.8}]}""";

    @MockitoBean AiClient ai;

    /** Chạy trước cleanUpUser của lớp cha (lúc đó người dùng còn tồn tại). */
    @AfterEach
    void cleanUpNutrition() {
        Document user = mongo.findOne(Query.query(Criteria.where("authUid").is(uid)), Document.class, "users");
        if (user == null) {
            return;
        }
        Query mine = Query.query(Criteria.where("userId").is(user.getObjectId("_id")));
        for (String c : new String[] {"meal_logs", "food_recognitions", "body_measurements"}) {
            mongo.remove(mine, c);
        }
    }

    private DocumentContext getJson(String path, int expected) throws Exception {
        return call(get(path).header("Authorization", token), expected);
    }

    private DocumentContext postJson(String path, String body, int expected) throws Exception {
        return call(post(path).header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content(body), expected);
    }

    private DocumentContext patchMe(String body, int expected) throws Exception {
        return call(patch("/me").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content(body), expected);
    }

    private String today() {
        return LocalDate.now(VN).toString();
    }

    private int photoScans() {
        Document day = mongo.findOne(Query.query(Criteria.where("userId").is(userId())
            .and("localDate").is(today())), Document.class, "daily_stats");
        if (day == null || !(day.get("usage") instanceof Document usage)) {
            return 0;
        }
        return usage.get("photoScans") instanceof Number n ? n.intValue() : 0;
    }

    @Test
    void onboarding_kem_ti_le_mo_va_nhom_co() throws Exception {
        postJson("/onboarding", """
            {"displayName":"Thử","goal":"build_muscle","gender":"female","birthYear":2000,"heightCm":160,
             "weightKg":52,"experience":"beginner","location":"home","equipment":[],"injuries":[],
             "availability":[{"weekday":1,"slot":"evening"},{"weekday":3,"slot":"evening"}],
             "sessionMinutes":15,"coachStyle":"supportive","timezone":"Asia/Ho_Chi_Minh",
             "bodyFatPct":24,"focusMuscles":["glutes","abs","glutes"]}""", 200);

        DocumentContext me = getJson("/me", 200);
        assertEquals(24, me.<Integer>read("$.profile.bodyFatPct"));
        assertEquals(List.of("glutes", "abs"), me.<List<String>>read("$.profile.focusMuscles"));

        DocumentContext body = getJson("/me/body", 200);
        assertEquals("female", body.read("$.gender"));
        assertEquals(LocalDate.now(VN).getYear() - 2000, body.<Integer>read("$.age"));
        assertEquals(20.3, body.<Double>read("$.bmi"));                      // 52 / 1.6²
        assertEquals("normal", body.read("$.bmiCategory"));
        assertEquals(24, body.<Integer>read("$.bodyFatPct"));
        assertFalse(body.<Boolean>read("$.bodyFatEstimated"));
        assertEquals(List.of("glutes", "abs"), body.<List<String>>read("$.focusMuscles"));
    }

    @Test
    void chi_so_co_the_va_sua_trong_cai_dat() throws Exception {
        onboard();                                                            // nam 1995, 170 cm, 70 kg, giảm mỡ
        int age = LocalDate.now(VN).getYear() - 1995;

        // 1. Chưa có số đo, chưa chọn tỉ lệ mỡ: ước tính
        DocumentContext body = getJson("/me/body", 200);
        assertEquals(170.0, body.<Double>read("$.heightCm"));
        assertEquals(70.0, body.<Double>read("$.weightKg"));
        assertEquals(24.2, body.<Double>read("$.bmi"));
        assertEquals("overweight", body.read("$.bmiCategory"));
        assertEquals(BodyRules.estimateBodyFatPct(24.2, age, "male"), body.<Integer>read("$.bodyFatPct"));
        assertTrue(body.<Boolean>read("$.bodyFatEstimated"));
        double bmr = NutritionCalculator.bmr("male", age, 170, 70);
        assertEquals((int) Math.round(bmr), body.<Integer>read("$.bmr"));
        assertEquals((int) Math.round(bmr * 1.375), body.<Integer>read("$.tdee"));
        assertEquals(List.of(), body.<List<String>>read("$.focusMuscles"));
        // mục tiêu khớp màn dinh dưỡng
        DocumentContext nutrition = getJson("/nutrition/today", 200);
        assertEquals(nutrition.<Integer>read("$.target.kcal"), body.<Integer>read("$.targetKcal"));
        assertEquals(nutrition.<Integer>read("$.target.proteinG"), body.<Integer>read("$.proteinG"));
        assertNotNull(body.read("$.carbsG"));
        assertNotNull(body.read("$.fatG"));
        assertNotNull(body.read("$.waterMl"));
        assertNull(body.read("$.waistCm"));

        // 2. Cài đặt: cân nặng ghi vào số đo hôm nay, giữ mốc ban đầu, thêm mốc calo mới
        DocumentContext me = patchMe("""
            {"heightCm":172,"weightKg":68,"bodyFatPct":18,"focusMuscles":["abs","legs","abs"]}""", 200);
        assertEquals(172.0, me.<Double>read("$.profile.heightCm"));
        assertEquals(70.0, me.<Double>read("$.profile.startWeightKg"));
        assertEquals(18, me.<Integer>read("$.profile.bodyFatPct"));
        assertEquals(List.of("abs", "legs"), me.<List<String>>read("$.profile.focusMuscles"));
        Document measured = mongo.findOne(Query.query(Criteria.where("userId").is(userId())
            .and("measuredOn").is(today())), Document.class, "body_measurements");
        assertEquals(68.0, ((Number) measured.get("weightKg")).doubleValue());
        assertEquals(2, user().getList("nutritionTargets", Document.class).size());

        body = getJson("/me/body", 200);
        assertEquals(68.0, body.<Double>read("$.weightKg"));
        assertEquals(172.0, body.<Double>read("$.heightCm"));
        assertEquals(23.0, body.<Double>read("$.bmi"));                      // 68 / 1.72² = 22.99
        assertEquals(18, body.<Integer>read("$.bodyFatPct"));
        assertFalse(body.<Boolean>read("$.bodyFatEstimated"));
        assertEquals(List.of("abs", "legs"), body.<List<String>>read("$.focusMuscles"));
        assertEquals(getJson("/nutrition/today", 200).<Integer>read("$.target.kcal"),
            body.<Integer>read("$.targetKcal"));

        // chỉ gửi cân nặng cũng được (không báo NOTHING_TO_UPDATE)
        patchMe("{\"weightKg\":67.5}", 200);
        assertEquals(67.5, getJson("/me/body", 200).<Double>read("$.weightKg"));

        // số đo tỉ lệ mỡ thật thắng số tự chọn
        postJson("/measurements", "{\"bodyFatPct\":21.4}", 200);
        assertEquals(21, getJson("/me/body", 200).<Integer>read("$.bodyFatPct"));

        // số đo vòng mới nhất để app vẽ hình sát người thật
        postJson("/measurements", "{\"waistCm\":82,\"hipCm\":95}", 200);
        DocumentContext circ = getJson("/me/body", 200);
        assertEquals(82.0, circ.<Double>read("$.waistCm"));
        assertEquals(95.0, circ.<Double>read("$.hipCm"));
        assertNull(circ.read("$.chestCm"));

        // 3. Giá trị sai
        patchMe("{\"bodyFatPct\":60}", 400);
        patchMe("{\"focusMuscles\":[\"core\"]}", 400);
        patchMe("{\"heightCm\":50}", 400);
        patchMe("{\"weightKg\":500}", 400);
        // focusMuscles rỗng = bỏ chọn hết
        assertEquals(List.of(), patchMe("{\"focusMuscles\":[]}", 200).<List<String>>read("$.profile.focusMuscles"));
    }

    @Test
    void so_hiep_theo_nhom_co_trong_tuan() throws Exception {
        onboard();
        DocumentContext empty = getJson("/me/muscles/week", 200);
        String monday = LocalDate.now(VN).with(java.time.DayOfWeek.MONDAY).toString();
        assertEquals(monday, empty.read("$.weekStart"));
        assertEquals(7, empty.<java.util.Map<String, Integer>>read("$.muscles").size());
        assertEquals(0, empty.<Integer>read("$.muscles.abs"));

        String core = exerciseOf("core");
        String legs = exerciseOf("legs");
        String cardio = exerciseOf("cardio");
        Instant end = Instant.now().truncatedTo(ChronoUnit.SECONDS);
        postJson("/workouts", """
            {"clientId":"client-muscle-1","startedAt":"%s","endedAt":"%s","variant":"normal","rpe":6,
             "sets":[{"exerciseId":"%s","setIndex":1,"reps":10},{"exerciseId":"%s","setIndex":2,"reps":8},
                     {"exerciseId":"%s","setIndex":1,"reps":12},{"exerciseId":"%s","setIndex":1,"reps":20}]}"""
            .formatted(end.minus(10, ChronoUnit.MINUTES), end, core, core, legs, cardio), 200);

        DocumentContext week = getJson("/me/muscles/week", 200);
        assertEquals(2, week.<Integer>read("$.muscles.abs"));
        assertEquals(1, week.<Integer>read("$.muscles.legs"));
        assertEquals(0, week.<Integer>read("$.muscles.chest"));
        assertEquals(0, week.<Integer>read("$.muscles.back"));
        assertEquals(0, week.<Integer>read("$.muscles.shoulders"));
        assertEquals(0, week.<Integer>read("$.muscles.arms"));
        assertEquals(0, week.<Integer>read("$.muscles.glutes"));

        // ngày giữa tuần đưa về Thứ Hai; tuần trước chưa tập gì
        assertEquals(2, getJson("/me/muscles/week?weekStart=" + LocalDate.parse(monday).plusDays(3), 200)
            .<Integer>read("$.muscles.abs"));
        DocumentContext last = getJson("/me/muscles/week?weekStart=" + LocalDate.parse(monday).minusDays(7), 200);
        assertEquals(LocalDate.parse(monday).minusDays(7).toString(), last.read("$.weekStart"));
        assertEquals(0, last.<Integer>read("$.muscles.abs"));
        assertEquals("INVALID_DATE", getJson("/me/muscles/week?weekStart=tuan-nay", 400).read("$.code"));
    }

    private String exerciseOf(String primaryMuscle) {
        Document e = mongo.findOne(Query.query(Criteria.where("primaryMuscle").is(primaryMuscle)
            .and("isActive").is(true)), Document.class, "exercises");
        assertNotNull(e, "kho bài tập thiếu nhóm " + primaryMuscle);
        return e.getObjectId("_id").toHexString();
    }

    @Test
    void mo_ta_bua_an_bang_chu() throws Exception {
        onboard();
        String text = "2 bát phở bò " + java.util.UUID.randomUUID();

        // AI chưa cấu hình: 503, không trừ lượt
        when(ai.available()).thenReturn(false);
        assertEquals("AI_UNAVAILABLE", postJson("/meals/parse",
            "{\"text\":\"%s\",\"meal\":\"lunch\"}".formatted(text), 503).read("$.code"));
        assertEquals(0, photoScans());

        when(ai.available()).thenReturn(true);
        when(ai.complete(anyString(), any(), anyInt())).thenReturn(PHO_JSON);
        DocumentContext first = postJson("/meals/parse", "{\"text\":\"%s\",\"meal\":\"lunch\"}".formatted(text), 200);
        assertFalse(first.<Boolean>read("$.cached"));
        assertTrue(first.<Boolean>read("$.items[0].matched"));
        assertEquals("Phở bò tái", first.read("$.items[0].nameVi"));
        assertEquals(1100.0, first.<Double>read("$.items[0].portionGrams"));
        assertEquals(1071, first.<Integer>read("$.items[0].kcal"));          // 535.5 kcal / 550 g × 1100 g
        String recognitionId = first.read("$.recognitionId");
        String foodId = first.read("$.items[0].foodId");
        assertEquals(1, photoScans());
        Document rec = mongo.findById(new org.bson.types.ObjectId(recognitionId), Document.class, "food_recognitions");
        assertEquals("text", rec.getString("source"));
        assertTrue(rec.getString("imageSha256").matches("text:[0-9a-f]{64}"));
        assertFalse(rec.toJson().contains("2 bát phở bò"));                  // không lưu câu người dùng gõ

        // Cùng câu (khác hoa thường, khoảng trắng): dùng lại, không gọi AI, không trừ lượt
        DocumentContext again = postJson("/meals/parse",
            "{\"text\":\"  %s \",\"meal\":\"dinner\"}".formatted(text.replace("2 bát", "2  BÁT")), 200);
        assertTrue(again.<Boolean>read("$.cached"));
        assertEquals(recognitionId, again.read("$.recognitionId"));
        verify(ai, times(1)).complete(anyString(), any(), anyInt());
        verify(ai, never()).completeWithImage(anyString(), anyString(), any(), anyString(), anyInt());
        assertEquals(1, photoScans());

        // Lưu bữa như ảnh: method "photo" + recognitionId
        DocumentContext saved = postJson("/meals", """
            {"meal":"lunch","method":"photo","recognitionId":"%s",
             "items":[{"foodId":"%s","name":"Phở bò tái","portionGrams":1100,"kcal":1,"proteinG":0}]}"""
            .formatted(recognitionId, foodId), 200);
        assertEquals(1071, saved.<Integer>read("$.consumed.kcal"));

        // AI trả sai hai lần: 502, vẫn tính lượt
        when(ai.complete(anyString(), any(), anyInt())).thenReturn("xin lỗi, tôi không hiểu");
        assertEquals("AI_BAD_OUTPUT", postJson("/meals/parse",
            "{\"text\":\"cơm gà %s\",\"meal\":\"lunch\"}".formatted(java.util.UUID.randomUUID()), 502).read("$.code"));
        assertEquals(2, photoScans());

        // AI lỗi giữa chừng: 503 và trả lại lượt
        when(ai.complete(anyString(), any(), anyInt())).thenThrow(new AiClient.AiUnavailableException("lỗi", null));
        assertEquals("AI_UNAVAILABLE", postJson("/meals/parse",
            "{\"text\":\"bún chả %s\",\"meal\":\"lunch\"}".formatted(java.util.UUID.randomUUID()), 503).read("$.code"));
        assertEquals(2, photoScans());

        // Hết lượt trong ngày: 429 như ảnh
        mongo.updateFirst(Query.query(Criteria.where("userId").is(userId()).and("localDate").is(today())),
            new Update().set("usage.photoScans", 100000), "daily_stats");
        assertEquals("PHOTO_LIMIT_REACHED", postJson("/meals/parse",
            "{\"text\":\"xôi gà %s\",\"meal\":\"breakfast\"}".formatted(java.util.UUID.randomUUID()), 429).read("$.code"));

        // Dữ liệu vào sai
        postJson("/meals/parse", "{\"text\":\"\",\"meal\":\"lunch\"}", 400);
        postJson("/meals/parse", "{\"text\":\"%s\",\"meal\":\"lunch\"}".formatted("a".repeat(301)), 400);
        postJson("/meals/parse", "{\"text\":\"phở\",\"meal\":\"brunch\"}", 400);
    }

    @Test
    void mon_goi_y_theo_bua() throws Exception {
        onboard();
        // Chưa ghi bữa nào: danh sách món phổ biến của bữa
        DocumentContext breakfast = getJson("/foods/popular?meal=breakfast", 200);
        assertEquals(8, breakfast.<Integer>read("$.length()"));
        assertEquals("Phở bò tái", breakfast.read("$[0].nameVi"));
        assertNotNull(breakfast.read("$[0].foodId"));
        assertNotNull(breakfast.read("$[0].kcal"));

        // Ghi "Bánh flan" hai lần và "Táo" một lần cho bữa trưa: lên đầu danh sách bữa trưa
        String flan = foodId("Bánh flan");
        String apple = foodId("Táo");
        for (String id : List.of(flan, apple, flan)) {
            postJson("/meals", """
                {"meal":"lunch","method":"search","items":[{"foodId":"%s","name":"x","portionGrams":100}]}"""
                .formatted(id), 200);
        }
        DocumentContext lunch = getJson("/foods/popular?meal=lunch&limit=5", 200);
        assertEquals(5, lunch.<Integer>read("$.length()"));
        assertEquals(flan, lunch.read("$[0].foodId"));
        assertEquals(apple, lunch.read("$[1].foodId"));
        assertEquals("Cơm tấm sườn nướng", lunch.read("$[2].nameVi"));
        // bữa khác không bị ảnh hưởng
        assertEquals("Chuối chín", getJson("/foods/popular?meal=snack&limit=1", 200).read("$[0].nameVi"));

        // limit tối đa 20, không trùng
        List<String> ids = getJson("/foods/popular?meal=lunch&limit=99", 200).read("$[*].foodId");
        assertEquals(20, ids.size());
        assertEquals(20, new java.util.HashSet<>(ids).size());
        assertEquals("INVALID_MEAL", getJson("/foods/popular?meal=brunch", 400).read("$.code"));
    }

    private String foodId(String nameVi) {
        return mongo.findOne(Query.query(Criteria.where("nameVi").is(nameVi)), Document.class, "foods")
            .getObjectId("_id").toHexString();
    }
}
