package vn.levelup.nutrition;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.List;
import java.util.UUID;

import org.bson.Document;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import com.jayway.jsonpath.DocumentContext;
import vn.levelup.FlowTestBase;
import vn.levelup.coach.ai.AiClient;
import vn.levelup.nutrition.rules.VietText;
import vn.levelup.nutrition.service.MealRecognitionService;

/** Món chưa có trong kho: AI ước tính calo, gom vào food_candidates, Admin duyệt vào foods. */
@SpringBootTest(properties = "levelup.demo.uids=food-admin")
@ActiveProfiles("dev")
class FoodCandidateFlowTest extends FlowTestBase {

    private static final String ADMIN = "Bearer dev-food-admin";

    @MockitoBean AiClient ai;

    private final String name = "Trà thử " + UUID.randomUUID().toString().substring(0, 8);
    private final String key = VietText.normalize(name);

    @AfterEach
    void cleanUpFood() {
        mongo.remove(Query.query(Criteria.where("key").is(key)), "food_candidates");
        mongo.remove(Query.query(Criteria.where("key").is(key)), "food_candidate_users");
        mongo.remove(Query.query(Criteria.where("searchName").is(key)), "foods");
        mongo.remove(Query.query(Criteria.where("uid").is("food-admin")), "admin_audit");
        Document u = user();
        if (u != null) {
            Query mine = Query.query(Criteria.where("userId").is(u.getObjectId("_id")));
            mongo.remove(mine, "meal_logs");
            mongo.remove(mine, "food_recognitions");
        }
    }

    private DocumentContext recognize() throws Exception {
        byte[] image = ("anh-" + UUID.randomUUID()).getBytes(StandardCharsets.UTF_8);
        String body = """
            {"imageBase64":"%s","mediaType":"image/jpeg","sha256":"%s"}"""
            .formatted(Base64.getEncoder().encodeToString(image), MealRecognitionService.sha256Hex(image));
        return call(post("/meals/recognize").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content(body), 200);
    }

    private Document candidate() {
        return mongo.findOne(Query.query(Criteria.where("key").is(key)), Document.class, "food_candidates");
    }

    @Test
    void aiUocTinhGomVaoKhoChoRoiAdminDuyet() throws Exception {
        onboard();
        when(ai.available()).thenReturn(true);
        when(ai.completeWithImage(anyString(), anyString(), any(), anyString(), anyInt())).thenReturn("""
            {"dishes":[{"name":"Beef pho","nameVi":"Phở bò","portionGrams":550,"confidence":0.9,
               "per100g":{"kcal":80,"proteinG":5,"carbsG":10,"fatG":2}},
              {"name":"Strawberry tea","nameVi":"%s","portionGrams":500,"confidence":0.8,
               "per100g":{"kcal":75,"proteinG":1.2,"carbsG":12,"fatG":2.5}}]}""".formatted(name));

        // 1. Món lạ có số ước tính, món trong kho vẫn lấy số của kho
        DocumentContext r = recognize();
        assertTrue(r.<Boolean>read("$.items[0].matched"));
        assertFalse(r.<Boolean>read("$.items[0].estimated"));
        assertFalse(r.<Boolean>read("$.items[1].matched"));
        assertTrue(r.<Boolean>read("$.items[1].estimated"));
        assertEquals(375, r.<Integer>read("$.items[1].kcal"));
        assertEquals(281, r.<Integer>read("$.items[1].kcalMin"));
        assertNull(r.read("$.items[1].foodId"));

        // 2. Chỉ món lạ vào kho chờ
        Document c = candidate();
        assertEquals("pending", c.getString("status"));
        assertEquals(1, c.getInteger("sightings"));
        assertEquals(1, c.getInteger("userCount"));
        assertEquals(1, c.getList("aiSamples", Document.class).size());
        assertNull(mongo.findOne(Query.query(Criteria.where("key").is("pho bo")), Document.class, "food_candidates"));

        // 3. Người dùng chỉ sửa số gam (500 → 400); calo app gửi bị bỏ qua, server tự tính 75 kcal/100 g × 400 g.
        //    Món tên tự gõ (không khớp món AI nhận ra) vẫn lưu nhưng không vào kho chờ.
        call(post("/meals").header("Authorization", token).contentType(MediaType.APPLICATION_JSON).content("""
            {"meal":"snack","method":"photo","recognitionId":"%s",
             "items":[{"name":"%s","portionGrams":400,"kcal":999,"proteinG":6,"carbsG":60,"fatG":12},
                      {"name":"%s ghi chú","kcal":100}]}"""
            .formatted(r.read("$.recognitionId"), name, name)), 200);
        Document meal = mongo.findOne(Query.query(Criteria.where("userId").is(userId())), Document.class,
            "meal_logs");
        Document item = meal.getList("items", Document.class).get(0);
        assertEquals(300, item.getInteger("kcal"));
        assertEquals(48.0, item.getDouble("carbsG"));
        assertTrue(item.getBoolean("aiEstimated"));
        // Khoảng của bữa: món ước tính ±25%, món còn lại ±15%
        assertEquals(310, meal.getInteger("kcalMin"));       // 225 + 85
        assertEquals(490, meal.getInteger("kcalMax"));       // 375 + 115
        assertNull(mongo.findOne(Query.query(Criteria.where("key").is(key + " ghi chu")), Document.class,
            "food_candidates"));
        // Món khớp kho gửi thiếu foodId không được tính theo số AI và không vào kho chờ
        call(post("/meals").header("Authorization", token).contentType(MediaType.APPLICATION_JSON).content("""
            {"meal":"snack","method":"photo","recognitionId":"%s",
             "items":[{"name":"Phở bò","portionGrams":300,"kcal":100}]}""".formatted(r.<String>read("$.recognitionId"))), 200);
        assertNull(mongo.findOne(Query.query(Criteria.where("key").is("pho bo")), Document.class, "food_candidates"));
        assertEquals(1, candidate().getInteger("saves"));
        assertEquals(1, candidate().getInteger("userCount"));   // cùng người: không đếm lại

        // Tên gõ tay (manual) không vào kho chờ
        call(post("/meals").header("Authorization", token).contentType(MediaType.APPLICATION_JSON).content("""
            {"meal":"snack","method":"manual","items":[{"name":"%s riêng","kcal":100}]}""".formatted(name)), 200);
        assertNull(mongo.findOne(Query.query(Criteria.where("key").is(key + " rieng")), Document.class,
            "food_candidates"));

        // 4. Người thường không thấy API admin
        call(get("/admin/food-candidates").header("Authorization", token), 404);

        // 5. Admin thấy gợi ý /100 g (trung vị AI: 75 kcal) và khẩu phần người dùng hay lưu (400 g)
        DocumentContext list = call(get("/admin/food-candidates").header("Authorization", ADMIN), 200);
        List<Double> kcal = list.read("$[?(@.nameVi == '" + name + "')].suggested.kcal");
        assertEquals(List.of(75.0), kcal);
        List<Double> grams = list.read("$[?(@.nameVi == '" + name + "')].typicalGrams");
        assertEquals(List.of(400.0), grams);
        String id = list.<List<String>>read("$[?(@.nameVi == '" + name + "')].id").get(0);

        // 6. Duyệt: thêm vào foods, duyệt lần 2 báo đã duyệt, lần nhận diện sau khớp kho
        String approve = """
            {"nameVi":"%s","category":"do_uong","servingDesc":"1 ly 500 ml","servingGrams":500,
             "kcal":400,"proteinG":6,"carbsG":60,"fatG":12}""".formatted(name);
        DocumentContext ok = call(post("/admin/food-candidates/" + id + "/approve").header("Authorization", ADMIN)
            .contentType(MediaType.APPLICATION_JSON).content(approve), 200);
        assertEquals("approved", ok.read("$.status"));
        Document food = mongo.findOne(Query.query(Criteria.where("searchName").is(key)), Document.class, "foods");
        assertNotNull(food);
        assertEquals("ai", food.getString("source"));
        assertEquals(food.getObjectId("_id").toHexString(), ok.read("$.foodId"));
        assertEquals("CANDIDATE_REVIEWED", call(post("/admin/food-candidates/" + id + "/approve")
            .header("Authorization", ADMIN).contentType(MediaType.APPLICATION_JSON).content(approve), 409)
            .read("$.code"));

        DocumentContext again = recognize();
        assertTrue(again.<Boolean>read("$.items[1].matched"));
        assertEquals(food.getObjectId("_id").toHexString(), again.read("$.items[1].foodId"));
        assertEquals(0, mongo.count(Query.query(Criteria.where("key").is(key)), "food_candidate_users"));
    }

    @Test
    void adminTuChoiVaKiemTraDauVao() throws Exception {
        onboard();
        when(ai.available()).thenReturn(true);
        when(ai.completeWithImage(anyString(), anyString(), any(), anyString(), anyInt())).thenReturn("""
            {"dishes":[{"nameVi":"%s","portionGrams":300,"confidence":0.5}]}""".formatted(name));
        DocumentContext r = recognize();
        assertFalse(r.<Boolean>read("$.items[0].estimated"));
        assertNull(r.read("$.items[0].kcal"));
        String id = candidate().getObjectId("_id").toHexString();

        call(post("/admin/food-candidates/" + id + "/approve").header("Authorization", ADMIN)
            .contentType(MediaType.APPLICATION_JSON).content("{\"nameVi\":\"x\",\"category\":\"pizza\"}"), 400);
        call(get("/admin/food-candidates?status=abc").header("Authorization", ADMIN), 400);

        // Tên trùng alias của món đã có trong kho: 409, món vẫn chờ duyệt (transaction hoàn lại)
        Document withAlias = mongo.findOne(Query.query(Criteria.where("aliases.0").exists(true)), Document.class,
            "foods");
        String alias = withAlias.getList("aliases", String.class).get(0);
        assertEquals("FOOD_EXISTS", call(post("/admin/food-candidates/" + id + "/approve")
            .header("Authorization", ADMIN).contentType(MediaType.APPLICATION_JSON).content("""
                {"nameVi":"%s","category":"com","servingDesc":"1 phần","servingGrams":300,
                 "kcal":400,"proteinG":10,"carbsG":60,"fatG":12}""".formatted(alias)), 409).read("$.code"));
        assertEquals("pending", candidate().getString("status"));
        assertNull(candidate().get("foodId"));

        call(post("/admin/food-candidates/" + id + "/reject").header("Authorization", ADMIN), 204);
        assertEquals("rejected", candidate().getString("status"));
        assertEquals(0, mongo.count(Query.query(Criteria.where("key").is(key)), "food_candidate_users"));

        // Món đã bỏ: lần nhận diện sau không ghi thêm
        recognize();
        assertEquals("rejected", candidate().getString("status"));
        assertEquals(1, candidate().getInteger("sightings"));
        assertEquals(0, mongo.count(Query.query(Criteria.where("key").is(key)), "food_candidate_users"));
        call(post("/admin/food-candidates/000000000000000000000000/reject").header("Authorization", ADMIN), 404);
    }
}
