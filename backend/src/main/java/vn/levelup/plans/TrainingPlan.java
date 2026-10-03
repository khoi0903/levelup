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
        List<Item> items,
        String adjustedReason
    ) {
        /** Các nơi tạo buổi tập mới chưa có lý do điều chỉnh. */
        public Session(ObjectId id, String scheduledDate, String scheduledTime, String title,
                       Integer durationMin, String variant, String status, List<Item> items) {
            this(id, scheduledDate, scheduledTime, title, durationMin, variant, status, items, null);
        }
    }

    public record Item(
        ObjectId exerciseId,
        Integer targetSets,
        Integer targetReps,
        Integer targetDurationSec,
        Integer restSec
    ) {}
}
