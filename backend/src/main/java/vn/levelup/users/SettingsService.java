package vn.levelup.users;

import java.time.DateTimeException;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import vn.levelup.notifications.NotificationRules;
import vn.levelup.onboarding.OnboardingRequest;

/** Đọc và sửa cài đặt người dùng. Ghi bằng $set từng đường dẫn, không ghi đè cả document users. */
@Service
public class SettingsService {

    private final MongoTemplate mongo;

    public SettingsService(MongoTemplate mongo) {
        this.mongo = mongo;
    }

    public void update(User user, SettingsRequest r) {
        Update u = new Update();
        if (r.displayName() != null) {
            u.set("displayName", r.displayName().trim());
        }
        if (r.timezone() != null) {
            try {
                u.set("timezone", ZoneId.of(r.timezone()).getId());
            } catch (DateTimeException e) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "INVALID_TIMEZONE");
            }
        }
        if (r.coachStyle() != null) {
            u.set("profile.coachStyle", r.coachStyle());
        }
        if (r.sessionMinutes() != null) {
            u.set("profile.sessionMinutes", r.sessionMinutes());
        }
        if (r.availability() != null) {
            Set<Integer> days = new HashSet<>();
            for (OnboardingRequest.Slot s : r.availability()) {
                if (!days.add(s.weekday())) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "DUPLICATE_WEEKDAY");
                }
            }
            u.set("availability", r.availability().stream()
                .sorted((a, b) -> Integer.compare(a.weekday(), b.weekday()))
                .map(s -> new Document("weekday", s.weekday()).append("slot", s.slot()))
                .toList());
        }
        SettingsRequest.Notifications n = r.notifications();
        if (n != null) {
            setIfPresent(u, "notificationSettings.pushEnabled", n.pushEnabled());
            setIfPresent(u, "notificationSettings.checkinTime", n.checkinTime());
            setIfPresent(u, "notificationSettings.preWorkoutMinutes", n.preWorkoutMinutes());
            setIfPresent(u, "notificationSettings.quietStart", n.quietStart());
            setIfPresent(u, "notificationSettings.quietEnd", n.quietEnd());
            setIfPresent(u, "notificationSettings.maxPerDay", n.maxPerDay());
        }
        SettingsRequest.Sharing s = r.sharing();
        if (s != null) {
            setIfPresent(u, "sharing.weight", s.weight());
            setIfPresent(u, "sharing.measurements", s.measurements());
            setIfPresent(u, "sharing.photos", s.photos());
            setIfPresent(u, "sharing.meals", s.meals());
        }
        if (u.getUpdateObject().isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "NOTHING_TO_UPDATE");
        }
        mongo.updateFirst(Query.query(Criteria.where("_id").is(new ObjectId(user.id()))), u, "users");
    }

    /** Cài đặt hiện tại kèm giá trị mặc định, để app hiển thị ngay không cần tự đoán. */
    public Settings read(String userId) {
        Document user = mongo.findById(new ObjectId(userId), Document.class, "users");
        Document n = user == null ? new Document() : user.get("notificationSettings", new Document());
        Document sh = user == null ? new Document() : user.get("sharing", new Document());
        List<Document> slots = user == null ? List.of() : user.getList("availability", Document.class, List.of());
        return new Settings(
            new Settings.Notifications(
                n.getBoolean("pushEnabled", true),
                n.getString("checkinTime"),
                n.get("preWorkoutMinutes") instanceof Number p ? p.intValue() : null,
                n.get("quietStart") instanceof String qs ? qs : NotificationRules.DEFAULT_QUIET_START.toString(),
                n.get("quietEnd") instanceof String qe ? qe : NotificationRules.DEFAULT_QUIET_END.toString(),
                NotificationRules.maxPerDay(n.get("maxPerDay"))),
            new Settings.Sharing(sh.getBoolean("weight", false), sh.getBoolean("measurements", false),
                sh.getBoolean("photos", false), sh.getBoolean("meals", false)),
            slots.stream().map(d -> new User.Availability(
                d.get("weekday") instanceof Number w ? w.intValue() : null, d.getString("slot"))).toList());
    }

    /** Huy hiệu đã đạt, mới nhất trước, kèm tên tiếng Việt từ collection achievements. */
    public List<Achievement> achievements(String userId) {
        Document user = mongo.findById(new ObjectId(userId), Document.class, "users");
        List<Document> earned = user == null ? List.of() : user.getList("achievements", Document.class, List.of());
        if (earned.isEmpty()) {
            return List.of();
        }
        Map<String, Document> catalog = mongo.find(Query.query(Criteria.where("code")
                .in(earned.stream().map(a -> a.getString("code")).toList())), Document.class, "achievements")
            .stream().collect(Collectors.toMap(d -> d.getString("code"), d -> d, (a, b) -> a, LinkedHashMap::new));
        List<Achievement> out = new ArrayList<>();
        for (Document a : earned) {
            Document c = catalog.get(a.getString("code"));
            Date at = a.getDate("earnedAt");
            out.add(new Achievement(a.getString("code"), c == null ? null : c.getString("nameVi"),
                c == null ? null : c.getString("descriptionVi"), c == null ? null : c.getString("category"),
                at == null ? null : at.toInstant().toString()));
        }
        out.sort((x, y) -> String.valueOf(y.earnedAt()).compareTo(String.valueOf(x.earnedAt())));
        return out;
    }

    private static void setIfPresent(Update u, String path, Object value) {
        if (value != null) {
            u.set(path, value);
        }
    }

    public record Settings(Notifications notifications, Sharing sharing, List<User.Availability> availability) {
        public record Notifications(boolean pushEnabled, String checkinTime, Integer preWorkoutMinutes,
                                    String quietStart, String quietEnd, int maxPerDay) {}

        public record Sharing(boolean weight, boolean measurements, boolean photos, boolean meals) {}
    }

    public record Achievement(String code, String nameVi, String descriptionVi, String category, String earnedAt) {}
}
