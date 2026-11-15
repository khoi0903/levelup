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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Base64;
import java.util.List;
import java.util.UUID;

import jakarta.servlet.Filter;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.RequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import com.jayway.jsonpath.DocumentContext;
import com.jayway.jsonpath.JsonPath;
import vn.levelup.coach.ai.AiClient;
import vn.levelup.nutrition.service.MealRecognitionService;


/**
 * Chạy trên MongoDB dev (localhost:27018, cần docker compose up và seed món ăn, huy hiệu).
 * AiClient được thay bằng mock: test không bao giờ gọi Claude thật.
 * Đồng hồ cố định 19:00 giờ Việt Nam hôm nay để luật gợi ý đạm (sau 15:00) chạy ổn định.
 */
@SpringBootTest
@ActiveProfiles("dev")
class NutritionFlowTest {

    static final String PHO_JSON = """
        {"dishes":[{"name":"Beef pho","nameVi":"Phở bò","ingredients":["bánh phở","thịt bò","hành"],
          "portionGrams":550,"confidence":0.9}]}""";

    @TestConfiguration
    static class FixedClock {
        @Bean
        @Primary
        Clock fixedClock() {
            return Clock.fixed(LocalDate.now(ZoneOffset.UTC).atTime(12, 0).toInstant(ZoneOffset.UTC), ZoneOffset.UTC);
        }
    }

    @Autowired WebApplicationContext context;
    @Autowired MongoTemplate mongo;
    @Autowired Clock clock;
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
        Document user = currentUser();
        if (user == null) {
            return;
        }
        Query mine = Query.query(Criteria.where("userId").is(user.getObjectId("_id")));
        for (String c : new String[] {"meal_logs", "food_recognitions", "daily_stats", "body_measurements",
                                      "training_plans", "weekly_streaks"}) {
            mongo.remove(mine, c);
        }
        mongo.remove(Query.query(Criteria.where("_id").is(user.getObjectId("_id"))), "users");
    }

    private Document currentUser() {
        return mongo.findOne(Query.query(Criteria.where("authUid").is(token.substring("Bearer dev-".length()))),
            Document.class, "users");
    }

    private DocumentContext call(RequestBuilder req, int expected) throws Exception {
        String body = mvc.perform(req).andExpect(status().is(expected)).andReturn().getResponse()
            .getContentAsString(StandardCharsets.UTF_8);
        return JsonPath.parse(body);
    }

    private DocumentContext postJson(String path, String body, int expected) throws Exception {
        return call(post(path).header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content(body), expected);
    }

    private void onboard() throws Exception {
        // nam 70 kg giảm mỡ: 1790 kcal, 112 g đạm
        postJson("/onboarding", """
            {"displayName":"Thử","goal":"lose_fat","gender":"male","birthYear":1998,"heightCm":170,
             "weightKg":70,"experience":"beginner","location":"home","equipment":[],"injuries":[],
             "availability":[{"weekday":1,"slot":"evening"},{"weekday":3,"slot":"evening"}],
             "sessionMinutes":15,"coachStyle":"supportive","timezone":"Asia/Ho_Chi_Minh"}""", 200);
    }

    private static String recognizeBody(byte[] image, String sha) {
        return """
            {"imageBase64":"%s","mediaType":"image/jpeg","sha256":"%s"}"""
            .formatted(Base64.getEncoder().encodeToString(image), sha);
    }

    private static byte[] fakeImage() {
        return ("anh-thu-" + UUID.randomUUID()).getBytes(StandardCharsets.UTF_8);
    }

    private int photoScans() {
        Document day = mongo.findOne(Query.query(Criteria.where("userId").is(currentUser().getObjectId("_id"))
            .and("localDate").is(today())), Document.class, "daily_stats");
        if (day == null || !(day.get("usage") instanceof Document usage)) {
            return 0;
        }
        return usage.get("photoScans") instanceof Number n ? n.intValue() : 0;
    }

    private String today() {
        return LocalDate.now(clock.withZone(java.time.ZoneId.of("Asia/Ho_Chi_Minh"))).toString();
    }

    @Test
    void chup_mon_luu_bua_nuoc_va_so_do() throws Exception {
        onboard();
        when(ai.available()).thenReturn(true);
        when(ai.completeWithImage(anyString(), anyString(), any(), anyString(), anyInt())).thenReturn(PHO_JSON);

        // 1. Nhận diện: gọi AI một lần, ghép được "Phở bò tái" trong kho
        byte[] image = fakeImage();
        String sha = MealRecognitionService.sha256Hex(image);
        DocumentContext first = postJson("/meals/recognize", recognizeBody(image, sha), 200);
        assertFalse(first.<Boolean>read("$.cached"));
        assertTrue(first.<Boolean>read("$.items[0].matched"));
        assertEquals("Phở bò tái", first.read("$.items[0].nameVi"));
        assertEquals(536, first.<Integer>read("$.items[0].kcal"));
        assertEquals(455, first.<Integer>read("$.items[0].kcalMin"));
        assertEquals(616, first.<Integer>read("$.items[0].kcalMax"));
        assertEquals(0.9, first.<Double>read("$.items[0].confidence"));
        String recognitionId = first.read("$.recognitionId");
        String foodId = first.read("$.items[0].foodId");
        assertEquals(1, photoScans());
        Document rec = mongo.findById(new ObjectId(recognitionId), Document.class, "food_recognitions");
        assertNotNull(rec.get("latencyMs"));
        assertEquals(sha, rec.getString("imageSha256"));
        assertFalse(rec.toJson().contains(Base64.getEncoder().encodeToString(image)));   // không lưu ảnh

        // 2. Cùng ảnh: dùng lại kết quả, không gọi AI, không trừ lượt
        DocumentContext again = postJson("/meals/recognize", recognizeBody(image, sha.toUpperCase()), 200);
        assertTrue(again.<Boolean>read("$.cached"));
        assertEquals(recognitionId, again.read("$.recognitionId"));
        verify(ai, times(1)).completeWithImage(anyString(), anyString(), any(), anyString(), anyInt());
        assertEquals(1, photoScans());

        // sha256 không khớp ảnh
        assertEquals("SHA256_MISMATCH", postJson("/meals/recognize",
            recognizeBody(fakeImage(), sha), 400).read("$.code"));

        // 3. Lưu bữa: server tính lại kcal từ kho, không tin số app gửi; thêm một món nhập tay
        postJson("/meals", """
            {"meal":"lunch","method":"photo","recognitionId":"%s",
             "items":[{"foodId":"%s","name":"Phở bò tái","portionGrams":550,"kcal":1,"proteinG":0}]}"""
            .formatted(recognitionId, foodId), 200);
        DocumentContext afterSnack = postJson("/meals", """
            {"meal":"snack","method":"manual",
             "items":[{"name":"Sữa chua tự làm","portionGrams":100,"kcal":120,"proteinG":5,"carbsG":15,"fatG":3}]}""",
            200);
        assertEquals(656, afterSnack.<Integer>read("$.consumed.kcal"));
        assertNotNull(afterSnack.read("$.suggestion.message"));

        // 4. Tổng kết hôm nay
        DocumentContext today = call(get("/nutrition/today").header("Authorization", token), 200);
        assertEquals(today(), today.read("$.localDate"));
        assertEquals(1790, today.<Integer>read("$.target.kcal"));
        assertEquals(656, today.<Integer>read("$.consumed.kcal"));
        assertEquals(0, today.<Integer>read("$.burnedKcal"));                     // chưa tập buổi nào hôm nay
        assertEquals(40.1, today.<Double>read("$.consumed.proteinG"));
        assertEquals(1134, today.<Integer>read("$.remaining.kcal"));
        assertEquals(71.9, today.<Double>read("$.remaining.proteinG"));
        assertEquals(2, today.<Integer>read("$.meals.length()"));
        assertEquals(536, today.<Integer>read("$.meals[0].kcal"));
        assertEquals(456, today.<Integer>read("$.meals[0].kcalMin"));
        assertEquals(foodId, today.read("$.meals[0].items[0].foodId"));
        // 19:00 và còn thiếu 72 g đạm: gợi ý món nhiều đạm từ kho
        List<Object> suggested = today.read("$.suggestion.foods");
        assertFalse(suggested.isEmpty());
        assertTrue(today.<String>read("$.suggestion.message").startsWith("Hôm nay bạn còn thiếu khoảng 72 g đạm"));

        // món không có trong kho, recognitionId của người khác, photo thiếu recognitionId
        assertEquals("UNKNOWN_FOOD", postJson("/meals", """
            {"meal":"dinner","method":"search","items":[{"foodId":"%s","name":"x"}]}""".formatted("0".repeat(24)),
            400).read("$.code"));
        assertEquals("ITEM_KCAL_REQUIRED", postJson("/meals", """
            {"meal":"dinner","method":"manual","items":[{"name":"x"}]}""", 400).read("$.code"));
        assertEquals("RECOGNITION_REQUIRED", postJson("/meals", """
            {"meal":"dinner","method":"photo","items":[{"name":"x","kcal":100}]}""", 400).read("$.code"));
        assertEquals("VALIDATION_ERROR", postJson("/meals", """
            {"meal":"dinner","method":"manual","items":[{"name":"x","kcal":99999}]}""", 400).read("$.code"));

        // 5. Nước uống
        postJson("/water", "{\"ml\":300}", 200);
        DocumentContext water = postJson("/water", "{\"ml\":250}", 200);
        assertEquals(550, water.<Integer>read("$.waterMl"));
        assertEquals(2500, water.<Integer>read("$.targetMl"));
        assertEquals(550, call(get("/nutrition/today").header("Authorization", token), 200)
            .<Integer>read("$.waterMl"));
        assertEquals("VALIDATION_ERROR", postJson("/water", "{\"ml\":20}", 400).read("$.code"));

        // 6. Số đo: lần đầu 85 cm, giảm còn 83.9 cm thì có huy hiệu, lần sau không cấp lại
        String tenDaysAgo = LocalDate.parse(today()).minusDays(10).toString();
        DocumentContext m1 = postJson("/measurements",
            "{\"waistCm\":85,\"weightKg\":70,\"measuredOn\":\"%s\"}".formatted(tenDaysAgo), 200);
        assertEquals(0, m1.<Integer>read("$.newAchievements.length()"));
        DocumentContext m2 = postJson("/measurements", "{\"waistCm\":83.9}", 200);
        assertEquals("body_waist_cm_1", m2.read("$.newAchievements[0].code"));
        assertNotNull(m2.read("$.newAchievements[0].nameVi"));
        assertEquals(today(), m2.read("$.measurement.measuredOn"));
        // gửi thêm cân nặng cùng ngày: gộp vào số đo hôm nay
        DocumentContext m3 = postJson("/measurements", "{\"waistCm\":83,\"weightKg\":69.2}", 200);
        assertEquals(0, m3.<Integer>read("$.newAchievements.length()"));
        assertEquals(83.0, m3.<Double>read("$.measurement.waistCm"));
        long owned = currentUser().getList("achievements", Document.class).stream()
            .filter(a -> "body_waist_cm_1".equals(a.getString("code"))).count();
        assertEquals(1, owned);

        DocumentContext list = call(get("/measurements?days=30").header("Authorization", token), 200);
        assertEquals(2, list.<Integer>read("$.items.length()"));
        assertEquals(tenDaysAgo, list.read("$.items[0].measuredOn"));
        assertEquals(69.2, list.<Double>read("$.items[1].weightKg"));
        assertEquals(1, call(get("/measurements?days=5").header("Authorization", token), 200)
            .<Integer>read("$.items.length()"));

        assertEquals("MEASUREMENT_EMPTY", postJson("/measurements", "{}", 400).read("$.code"));
        assertEquals("VALIDATION_ERROR", postJson("/measurements", "{\"waistCm\":500}", 400).read("$.code"));
        assertEquals("INVALID_DATE", postJson("/measurements",
            "{\"weightKg\":70,\"measuredOn\":\"2099-01-01\"}", 400).read("$.code"));
    }

    @Test
    void ai_loi_tra_503_khong_tru_luot() throws Exception {
        onboard();
        byte[] image = fakeImage();
        String body = recognizeBody(image, MealRecognitionService.sha256Hex(image));

        // Chưa có key: báo ngay, không gọi
        when(ai.available()).thenReturn(false);
        assertEquals("AI_UNAVAILABLE", postJson("/meals/recognize", body, 503).read("$.code"));
        verify(ai, never()).completeWithImage(anyString(), anyString(), any(), anyString(), anyInt());
        assertEquals(0, photoScans());

        // Có key nhưng Claude lỗi: trả lại lượt đã giữ
        when(ai.available()).thenReturn(true);
        when(ai.completeWithImage(anyString(), anyString(), any(), anyString(), anyInt()))
            .thenThrow(new AiClient.AiUnavailableException("bận", null));
        assertEquals("AI_UNAVAILABLE", postJson("/meals/recognize", body, 503).read("$.code"));
        assertEquals(0, photoScans());
        assertNull(mongo.findOne(Query.query(Criteria.where("userId").is(currentUser().getObjectId("_id"))),
            Document.class, "food_recognitions"));
    }

    @Test
    void json_sai_thu_lai_mot_lan_roi_502() throws Exception {
        onboard();
        when(ai.available()).thenReturn(true);
        when(ai.completeWithImage(anyString(), anyString(), any(), anyString(), anyInt()))
            .thenReturn("Đây là phở bò", "{\"dishes\":[{\"name\":\"x\"}]}");
        byte[] image = fakeImage();
        assertEquals("AI_BAD_OUTPUT", postJson("/meals/recognize",
            recognizeBody(image, MealRecognitionService.sha256Hex(image)), 502).read("$.code"));
        verify(ai, times(2)).completeWithImage(anyString(), anyString(), any(), anyString(), anyInt());

        // Lần 1 sai, lần 2 đúng: thành công
        when(ai.completeWithImage(anyString(), anyString(), any(), anyString(), anyInt()))
            .thenReturn("không phải JSON", PHO_JSON);
        DocumentContext ok = postJson("/meals/recognize",
            recognizeBody(image, MealRecognitionService.sha256Hex(image)), 200);
        assertEquals("Phở bò tái", ok.read("$.items[0].nameVi"));
    }

    @Test
    void het_luot_anh_qua_lon_va_multipart() throws Exception {
        onboard();
        when(ai.available()).thenReturn(true);
        when(ai.completeWithImage(anyString(), anyString(), any(), anyString(), anyInt())).thenReturn(PHO_JSON);

        // Ảnh gửi multipart
        byte[] image = fakeImage();
        DocumentContext r = call(multipart("/meals/recognize")
            .file(new MockMultipartFile("image", "pho.jpg", "image/jpeg", image))
            .param("sha256", MealRecognitionService.sha256Hex(image))
            .header("Authorization", token), 200);
        assertTrue(r.<Boolean>read("$.items[0].matched"));
        assertEquals(1, photoScans());

        // Quá 2 MB
        byte[] big = new byte[MealRecognitionService.MAX_IMAGE_BYTES + 1];
        assertEquals("IMAGE_TOO_LARGE", postJson("/meals/recognize",
            recognizeBody(big, MealRecognitionService.sha256Hex(big)), 413).read("$.code"));

        // Hết lượt trong ngày (mặc định 10): ảnh mới bị chặn, ảnh cũ vẫn dùng lại được
        mongo.updateFirst(Query.query(Criteria.where("userId").is(currentUser().getObjectId("_id"))
            .and("localDate").is(today())), Update.update("usage.photoScans", 10), "daily_stats");
        byte[] other = fakeImage();
        assertEquals("PHOTO_LIMIT_REACHED", postJson("/meals/recognize",
            recognizeBody(other, MealRecognitionService.sha256Hex(other)), 429).read("$.code"));
        assertTrue(postJson("/meals/recognize", recognizeBody(image, MealRecognitionService.sha256Hex(image)), 200)
            .<Boolean>read("$.cached"));
        assertEquals(10, photoScans());
    }

    @Test
    void tim_mon_khong_dau() throws Exception {
        onboard();
        DocumentContext r = call(get("/foods/search").param("q", "pho bo").header("Authorization", token), 200);
        assertTrue(r.<Integer>read("$.length()") >= 2);
        assertTrue(r.<String>read("$[0].nameVi").startsWith("Phở bò"));
        assertNotNull(r.read("$[0].foodId"));
        assertEquals(0, call(get("/foods/search").param("q", "  ").header("Authorization", token), 200)
            .<Integer>read("$.length()"));
    }

    @Test
    void luu_bua_tra_cau_nhan_xet_theo_phong_cach_va_khong_lap() throws Exception {
        onboard();
        String body = """
            {"meal":"snack","method":"manual",
             "items":[{"name":"Sữa chua tự làm","portionGrams":100,"kcal":120,"proteinG":5,"carbsG":15,"fatG":3}]}""";
        java.util.Set<String> texts = new java.util.HashSet<>();
        java.util.Set<Integer> mos = new java.util.HashSet<>();
        for (int n = 0; n < 5; n++) {
            DocumentContext r = postJson("/meals", body, 200);
            String text = r.read("$.comment.text");
            assertNotNull(text);
            assertTrue(!text.contains("{"), "còn chỗ trống chưa điền: " + text);
            texts.add(text);
        }
        // 5 bữa giống hệt nhau vẫn ra 5 câu khác nhau, câu "mo" không lặp
        assertEquals(5, texts.size());
        for (Document m : mongo.find(Query.query(Criteria.where("userId").is(currentUser().getObjectId("_id"))),
                Document.class, "meal_logs")) {
            Document c = m.get("comment", Document.class);
            assertEquals("supportive", c.getString("style"));
            mos.add(c.getInteger("mo"));
        }
        assertEquals(5, mos.size());
        // Xem lại hôm nay: không kèm câu nhận xét
        assertNull(call(get("/nutrition/today").header("Authorization", token), 200).read("$.comment"));
    }
}
