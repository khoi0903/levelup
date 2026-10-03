package vn.levelup.plans;

import java.time.Instant;
import java.util.List;

import org.bson.types.ObjectId;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;
import org.springframework.data.mongodb.core.mapping.Field;

/** Collection "training_plans": một tuần là một document, các buổi tập nhúng bên trong. */
@Document("training_plans")
public record TrainingPlan(
    @Id String id,
    ObjectId userId,
    String weekStart,
    String status,            // draft | active | completed | replaced
    Integer targetSessions,
    String createdBy,         // rule | ai | user
    String aiRationale,
    List<Session> sessions,
    Instant createdAt
) {
    public record Session(
        @Field("_id") ObjectId id,
        String scheduledDate,
        String scheduledTime,
        String title,
        Integer durationMin,
        String variant,       // normal | light | quick5 | advanced
        String status,        // planned | completed | skipped | rescheduled | rest
        List<Item> items
    ) {}

    public record Item(
        ObjectId exerciseId,
        Integer targetSets,
        Integer targetReps,
        Integer targetDurationSec,
        Integer restSec
    ) {}
}
