package vn.levelup.checkins;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Date;
import java.util.List;
import java.util.Set;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import vn.levelup.exercises.Exercise;
import vn.levelup.exercises.ExerciseRepository;
import vn.levelup.plans.TrainingPlan;
import vn.levelup.users.User;

class CheckinServiceTest {

    private static final Instant NOW = Instant.parse("2026-10-02T18:00:00Z");
    private static final ObjectId USER_ID = new ObjectId();
    private static final User USER = new User(USER_ID.toHexString(), "firebase-uid", null, "Khoi",
        "Asia/Ho_Chi_Minh", "vi", null, null, null, null, null, null, null);

    private final MongoTemplate mongo = mock(MongoTemplate.class);
    private final ExerciseRepository exercises = mock(ExerciseRepository.class);
    private final CheckinService service = new CheckinService(mongo, exercises, Clock.fixed(NOW, ZoneOffset.UTC));

    private TrainingPlan plan() {
        var item = new TrainingPlan.Item(new ObjectId(), 3, 10, null, 45);
        var session = new TrainingPlan.Session(new ObjectId(), "2026-10-03", "18:30", "Toàn thân", 15,
            "normal", "planned", List.of(item));
        // Buổi completed cùng ngày đứng trước: service phải chọn buổi planned.
        var completed = new TrainingPlan.Session(new ObjectId(), "2026-10-03", "06:00", "Đã tập", 15,
            "normal", "completed", List.of());
        var plan = new TrainingPlan(new ObjectId().toHexString(), USER_ID, "2026-09-28", "active", 3,
            "rule", null, List.of(completed, session), NOW);
        when(mongo.findOne(any(Query.class), eq(TrainingPlan.class))).thenReturn(plan);
        var exercise = mock(Exercise.class);
        when(exercise.id()).thenReturn(item.exerciseId().toHexString());
        when(exercise.nameVi()).thenReturn("Squat cơ bản");
        when(exercises.findAllById(Set.of(item.exerciseId().toHexString()))).thenReturn(List.of(exercise));
        return plan;
    }

    @Test
    void no_session_uses_user_day_and_omits_optional_sleep_in_mongo() {
        var result = service.complete(USER, new CheckinRequest("normal", null));
        assertEquals("2026-10-03", result.localDate());
        assertEquals("normal", result.energy());
        assertNull(result.sleep());
        assertFalse(result.adjusted());
        assertNull(result.session());

        var query = ArgumentCaptor.forClass(Query.class);
        var update = ArgumentCaptor.forClass(Update.class);
        verify(mongo).upsert(query.capture(), update.capture(), eq("daily_stats"));
        assertEquals(new Document("userId", USER_ID).append("localDate", "2026-10-03")
            .append("checkin", new Document("$exists", false)), query.getValue().getQueryObject());
        Document checkin = update.getValue().getUpdateObject().get("$set", Document.class)
            .get("checkin", Document.class);
        assertEquals(new Document("energy", "normal").append("at", Date.from(NOW)), checkin);
        assertEquals(new Document("userId", USER_ID).append("localDate", "2026-10-03"),
            update.getValue().getUpdateObject().get("$setOnInsert"));
        verify(mongo, never()).updateFirst(any(Query.class), any(Update.class), eq(TrainingPlan.class));
        verifyNoInteractions(exercises);
    }

    @Test
    void existing_checkin_returns_conflict_before_any_write() {
        when(mongo.exists(any(Query.class), eq("daily_stats"))).thenReturn(true);
        var error = assertThrows(ResponseStatusException.class,
            () -> service.complete(USER, new CheckinRequest("tired", "lt6")));
        assertEquals(HttpStatus.CONFLICT, error.getStatusCode());
        assertEquals("ALREADY_CHECKED_IN", error.getReason());
        var query = ArgumentCaptor.forClass(Query.class);
        verify(mongo).exists(query.capture(), eq("daily_stats"));
        assertEquals(new Document("userId", USER_ID).append("localDate", "2026-10-03")
            .append("checkin", new Document("$exists", true)), query.getValue().getQueryObject());
        verify(mongo, never()).upsert(any(Query.class), any(Update.class), eq("daily_stats"));
        verify(mongo, never()).findOne(any(Query.class), eq(TrainingPlan.class));
    }

    @Test
    void duplicate_key_during_guarded_upsert_returns_conflict() {
        when(mongo.upsert(any(Query.class), any(Update.class), eq("daily_stats")))
            .thenThrow(new DuplicateKeyException("daily_stats unique index"));
        var error = assertThrows(ResponseStatusException.class,
            () -> service.complete(USER, new CheckinRequest("normal", null)));
        assertEquals(HttpStatus.CONFLICT, error.getStatusCode());
        assertEquals("ALREADY_CHECKED_IN", error.getReason());
        verify(mongo, never()).findOne(any(Query.class), eq(TrainingPlan.class));
    }

    @Test
    void tired_updates_only_selected_session_fields_and_returns_names() {
        TrainingPlan plan = plan();
        var result = service.complete(USER, new CheckinRequest("energized", "lt6"));
        assertTrue(result.adjusted());
        assertEquals(plan.sessions().get(1).id().toHexString(), result.session().id());
        assertEquals("light", result.session().variant());
        assertEquals("checkin_tired", result.session().adjustedReason());
        assertEquals(2, result.session().items().get(0).sets());
        assertEquals("Squat cơ bản", result.session().items().get(0).nameVi());

        var planQuery = ArgumentCaptor.forClass(Query.class);
        verify(mongo).findOne(planQuery.capture(), eq(TrainingPlan.class));
        assertEquals(new Document("userId", USER_ID).append("status", "active")
            .append("sessions", new Document("$elemMatch", new Document("scheduledDate", "2026-10-03")
                .append("status", "planned"))), planQuery.getValue().getQueryObject());

        var query = ArgumentCaptor.forClass(Query.class);
        var update = ArgumentCaptor.forClass(Update.class);
        verify(mongo).updateFirst(query.capture(), update.capture(), eq(TrainingPlan.class));
        assertEquals(new Document("_id", new ObjectId(plan.id())).append("userId", USER_ID)
            .append("status", "active").append("sessions", new Document("$elemMatch",
                new Document("_id", plan.sessions().get(1).id()).append("scheduledDate", "2026-10-03")
                    .append("status", "planned"))), query.getValue().getQueryObject());
        assertEquals(new Document("$set", new Document("sessions.$.variant", "light")
            .append("sessions.$.adjustedReason", "checkin_tired")
            .append("sessions.$.items.0.targetSets", 2)), update.getValue().getUpdateObject());

        var dailyUpdate = ArgumentCaptor.forClass(Update.class);
        verify(mongo).upsert(any(Query.class), dailyUpdate.capture(), eq("daily_stats"));
        assertEquals("lt6", dailyUpdate.getValue().getUpdateObject().get("$set", Document.class)
            .get("checkin", Document.class).getString("sleep"));
    }

    @Test
    void normal_returns_existing_session_without_plan_update() {
        plan();
        var result = service.complete(USER, new CheckinRequest("normal", "h7_8"));
        assertFalse(result.adjusted());
        assertEquals("normal", result.session().variant());
        assertEquals(3, result.session().items().get(0).sets());
        verify(mongo, never()).updateFirst(any(Query.class), any(Update.class), eq(TrainingPlan.class));
    }

    @Test
    void energized_does_not_write_item_sets() {
        plan();
        var result = service.complete(USER, new CheckinRequest("energized", null));
        assertTrue(result.adjusted());
        assertEquals("advanced", result.session().variant());
        assertEquals(3, result.session().items().get(0).sets());
        var update = ArgumentCaptor.forClass(Update.class);
        verify(mongo).updateFirst(any(Query.class), update.capture(), eq(TrainingPlan.class));
        assertEquals(new Document("$set", new Document("sessions.$.variant", "advanced")
            .append("sessions.$.adjustedReason", "checkin_energized")), update.getValue().getUpdateObject());
    }
}
