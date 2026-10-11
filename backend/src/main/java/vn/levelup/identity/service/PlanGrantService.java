package vn.levelup.identity.service;

import java.time.Clock;
import java.time.temporal.ChronoUnit;
import java.util.Date;
import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.*;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class PlanGrantService {
    private final MongoTemplate mongo;
    private final Clock clock;
    public PlanGrantService(MongoTemplate mongo, Clock clock) { this.mongo = mongo; this.clock = clock; }

    // Called inside the caller's transaction: concurrent grants conflict instead of losing days.
    public void addDays(ObjectId userId, int days, String source) {
        Document user = mongo.findById(userId, Document.class, "users");
        if (user == null) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND");
        Document plan = user.get("plan", Document.class);
        var base = clock.instant();
        if (plan != null && "pro".equals(plan.getString("tier")) && plan.getDate("expiresAt") != null
                && plan.getDate("expiresAt").toInstant().isAfter(base)) base = plan.getDate("expiresAt").toInstant();
        mongo.updateFirst(Query.query(Criteria.where("_id").is(userId)), Update.update("plan",
            new Document("tier", "pro").append("source", source)
                .append("expiresAt", Date.from(base.plus(days, ChronoUnit.DAYS)))
                .append("updatedAt", Date.from(clock.instant()))), "users");
    }
}
