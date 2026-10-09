package vn.levelup.training;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

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

/** Buổi planned bị rỗng bài (gặp trên máy thật) được xếp lại khi đọc kế hoạch. */
@SpringBootTest
@ActiveProfiles("dev")
class EmptySessionRepairFlowTest extends FlowTestBase {

    @Test
    void empty_planned_session_is_refilled_on_read() throws Exception {
        String sessionId = onboard().read("$.plan.sessions[0].id");
        ObjectId me = userId();
        mongo.updateFirst(Query.query(Criteria.where("userId").is(me).and("status").is("active")
                .and("sessions._id").is(new ObjectId(sessionId))),
            new Update().set("sessions.$.items", List.of()), "training_plans");

        DocumentContext plan = call(get("/plans/current").header("Authorization", token), 200);
        List<String> ids = plan.read("$.sessions[?(@.id == '" + sessionId + "')].items[*].exerciseId");
        assertFalse(ids.isEmpty(), "buổi rỗng được xếp lại bài");
        List<String> names = plan.read("$.sessions[?(@.id == '" + sessionId + "')].items[*].nameVi");
        assertEquals(ids.size(), names.size());

        Document stored = mongo.findOne(Query.query(Criteria.where("userId").is(me).and("status").is("active")),
            Document.class, "training_plans");
        Document session = stored.getList("sessions", Document.class).stream()
            .filter(s -> s.getObjectId("_id").toHexString().equals(sessionId)).findFirst().orElseThrow();
        assertEquals(ids.size(), session.getList("items", Document.class).size(), "đã lưu vào database");
    }
}
