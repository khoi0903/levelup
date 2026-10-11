package vn.levelup.identity.service;

import java.time.Clock;
import java.util.Date;
import java.util.regex.Pattern;
import org.bson.Document;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.*;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import vn.levelup.demo.DemoAccess;
import vn.levelup.identity.dto.GrantProRequest;

@Service
public class AdminService {
    private final DemoAccess access;
    private final CurrentUserService current;
    private final MongoTemplate mongo;
    private final PlanGrantService grants;
    private final Clock clock;
    public AdminService(DemoAccess access, CurrentUserService current, MongoTemplate mongo, PlanGrantService grants, Clock clock) {
        this.access = access; this.current = current; this.mongo = mongo; this.grants = grants; this.clock = clock;
    }
    public String requireAdmin() {
        String uid = current.uid();
        if (!access.isAdmin(uid)) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "NOT_FOUND");
        return uid;
    }
    @Transactional
    public void grant(GrantProRequest r) {
        String uid = requireAdmin();
        Document user = mongo.findOne(Query.query(Criteria.where("email")
            .regex("^" + Pattern.quote(r.email().trim()) + "$", "i")), Document.class, "users");
        if (user == null) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND");
        Object before = user.get("plan");
        grants.addDays(user.getObjectId("_id"), r.days(), "manual");
        Document after = mongo.findById(user.getObjectId("_id"), Document.class, "users");
        mongo.insert(new Document("uid", uid).append("userId", user.getObjectId("_id"))
            .append("before", before).append("after", after.get("plan")).append("at", Date.from(clock.instant())), "admin_audit");
    }
}
