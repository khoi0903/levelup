package vn.levelup.training;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

import java.time.LocalDate;
import java.util.List;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.test.context.ActiveProfiles;

import com.jayway.jsonpath.DocumentContext;
import vn.levelup.FlowTestBase;
import vn.levelup.shared.util.LocalDates;

/** Tuần mới chưa chốt tổng kết tuần: không trả kế hoạch tuần trước. */
@SpringBootTest
@ActiveProfiles("dev")
class NewWeekPlanFlowTest extends FlowTestBase {

    private String thisWeek() {
        return LocalDates.weekStart(LocalDate.now(LocalDates.DEFAULT_ZONE)).toString();
    }

    /** Đẩy kế hoạch hiện có về tuần trước (như người dùng sang tuần mới mà chưa chốt tổng kết). */
    private void moveCurrentPlanToLastWeek(ObjectId me) {
        String lastWeek = LocalDate.parse(thisWeek()).minusWeeks(1).toString();
        mongo.updateMulti(Query.query(Criteria.where("userId").is(me).and("status").is("active")),
            Update.update("weekStart", lastWeek), "training_plans");
    }

    @Test
    void builds_this_week_plan_from_availability() throws Exception {
        onboard();
        ObjectId me = userId();
        moveCurrentPlanToLastWeek(me);

        DocumentContext plan = call(get("/plans/current").header("Authorization", token), 200);
        assertEquals(thisWeek(), plan.read("$.weekStart"));
        List<String> dates = plan.read("$.sessions[*].scheduledDate");
        assertFalse(dates.isEmpty(), "lập buổi từ lịch rảnh");
        dates.forEach(d -> assertFalse(d.compareTo(thisWeek()) < 0, "không còn buổi của tuần trước"));
        assertEquals(1, mongo.count(Query.query(Criteria.where("userId").is(me).and("weekStart").is(thisWeek())
            .and("status").is("active")), "training_plans"));

        // gọi lại không tạo thêm
        call(get("/plans/current").header("Authorization", token), 200);
        assertEquals(1, mongo.count(Query.query(Criteria.where("userId").is(me).and("weekStart").is(thisWeek())
            .and("status").is("active")), "training_plans"));
    }

    @Test
    void activates_this_week_review_draft() throws Exception {
        onboard();
        ObjectId me = userId();
        Document current = mongo.findOne(Query.query(Criteria.where("userId").is(me).and("status").is("active")),
            Document.class, "training_plans");
        moveCurrentPlanToLastWeek(me);
        ObjectId draftId = new ObjectId();
        current.put("_id", draftId);
        current.put("weekStart", thisWeek());
        current.put("status", "draft");
        current.put("createdBy", "ai");
        mongo.insert(current, "training_plans");

        DocumentContext plan = call(get("/plans/current").header("Authorization", token), 200);
        assertEquals(draftId.toHexString(), plan.read("$.id"), "dùng bản nháp tổng kết tuần");
        assertEquals("active", plan.read("$.status"));
        assertNotEquals(null, plan.<Object>read("$.targetSessions"));
    }
}
