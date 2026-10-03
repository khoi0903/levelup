package vn.levelup;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.charset.StandardCharsets;
import java.util.UUID;

import jakarta.servlet.Filter;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.RequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import com.jayway.jsonpath.DocumentContext;
import com.jayway.jsonpath.JsonPath;

/**
 * Nền chung cho test chạy trên MongoDB dev (localhost:27018, cần docker compose up và seed bài tập).
 * Mỗi test dùng một uid ngẫu nhiên và dọn sạch dữ liệu của người dùng đó sau khi chạy.
 * Lớp con cần @SpringBootTest và @ActiveProfiles("dev").
 */
public abstract class FlowTestBase {

    private static final String[] USER_COLLECTIONS = {"workout_logs", "training_plans", "weekly_streaks",
        "personal_records", "daily_stats", "notifications", "skip_reports", "coach_messages"};

    @Autowired protected WebApplicationContext context;
    @Autowired protected MongoTemplate mongo;

    protected MockMvc mvc;
    protected String uid;
    protected String token;

    /** Tiền tố uid; demo dùng "demo-". */
    protected String uidPrefix() {
        return "it-";
    }

    @BeforeEach
    void setUpMvc() {
        mvc = MockMvcBuilders.webAppContextSetup(context)
            .addFilters(context.getBean("springSecurityFilterChain", Filter.class)).build();
        uid = uidPrefix() + UUID.randomUUID();
        token = "Bearer dev-" + uid;
    }

    @AfterEach
    void cleanUpUser() {
        Document user = mongo.findOne(Query.query(Criteria.where("authUid").is(uid)), Document.class, "users");
        if (user == null) {
            return;
        }
        Query mine = Query.query(Criteria.where("userId").is(user.getObjectId("_id")));
        for (String c : USER_COLLECTIONS) {
            mongo.remove(mine, c);
        }
        mongo.remove(Query.query(Criteria.where("_id").is(user.getObjectId("_id"))), "users");
    }

    protected DocumentContext call(RequestBuilder req, int expected) throws Exception {
        String body = mvc.perform(req).andExpect(status().is(expected)).andReturn().getResponse()
            .getContentAsString(StandardCharsets.UTF_8);
        return JsonPath.parse(body.isEmpty() ? "{}" : body);
    }

    /** Onboarding với 7 ngày rảnh: kế hoạch có buổi từ hôm nay tới Chủ nhật. */
    protected DocumentContext onboard() throws Exception {
        String body = """
            {"displayName":"Thử","goal":"lose_fat","gender":"male","birthYear":1995,"heightCm":170,
             "weightKg":70,"experience":"beginner","location":"home","equipment":[],"injuries":[],
             "availability":[{"weekday":1,"slot":"evening"},{"weekday":2,"slot":"evening"},
               {"weekday":3,"slot":"evening"},{"weekday":4,"slot":"evening"},{"weekday":5,"slot":"evening"},
               {"weekday":6,"slot":"evening"},{"weekday":7,"slot":"evening"}],
             "sessionMinutes":15,"coachStyle":"supportive","timezone":"Asia/Ho_Chi_Minh"}""";
        return call(post("/onboarding").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content(body), 200);
    }

    protected ObjectId userId() {
        return mongo.findOne(Query.query(Criteria.where("authUid").is(uid)), Document.class, "users")
            .getObjectId("_id");
    }

    protected Document user() {
        return mongo.findOne(Query.query(Criteria.where("authUid").is(uid)), Document.class, "users");
    }
}
