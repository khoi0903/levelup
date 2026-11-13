package vn.levelup.identity.service;

import java.time.Clock;
import java.time.DateTimeException;
import java.time.LocalDate;
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
import vn.levelup.engagement.rules.NotificationRules;
import vn.levelup.identity.dto.OnboardingRequest;
import vn.levelup.identity.dto.SettingsRequest;
import vn.levelup.identity.model.User;
import vn.levelup.nutrition.rules.NutritionCalculator;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.dto.MeasurementDtos;
import vn.levelup.training.service.MeasurementService;
import vn.levelup.training.service.ThisWeekScheduleSync;


/** Đọc và sửa cài đặt người dùng. Ghi bằng $set từng đường dẫn, không ghi đè cả document users. */
@Service
public class SettingsService {

    private final MongoTemplate mongo;
    private final ThisWeekScheduleSync scheduleSync;
    private final MeasurementService measurements;

    public SettingsService(MongoTemplate mongo, ThisWeekScheduleSync scheduleSync, MeasurementService measurements) {
        this.mongo = mongo;
        this.scheduleSync = scheduleSync;
        this.measurements = measurements;
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
        if (r.location() != null) {
            u.set("profile.location", r.location());
        }
        if (r.equipment() != null) {
            u.set("profile.equipment", r.equipment().stream().distinct().sorted().toList());
        }
        User.Profile p = user.profile();
        if (r.goal() != null) {
            u.set("profile.goal", r.goal());
        }
        if (r.bodyFatPct() != null) {
            u.set("profile.bodyFatPct", r.bodyFatPct());
        }
        if (r.focusMuscles() != null) {
            u.set("profile.focusMuscles", r.focusMuscles().stream().distinct().toList());
        }
        if (r.heightCm() != null) {
            u.set("profile.heightCm", r.heightCm());
        }
        boolean goalChanged = r.goal() != null && p != null && !r.goal().equals(p.goal());
        boolean bodyChanged = p != null && (r.weightKg() != null
            || (r.heightCm() != null && !r.heightCm().equals(p.heightCm())));
        if (goalChanged || bodyChanged) {
            // Mục tiêu / chiều cao / cân nặng mới: thêm mốc calo có hiệu lực từ hôm nay (giữ lịch sử, không sửa mốc cũ).
            // Chỉ đổi mục tiêu thì vẫn tính theo cân ban đầu như trước.
            Double height = r.heightCm() != null ? r.heightCm() : p.heightCm();
            Double weight = r.weightKg() != null ? r.weightKg()
                : bodyChanged ? measurements.latestWeightKg(user.id()).orElse(p.startWeightKg())
                : p.startWeightKg();
            String goal = r.goal() != null ? r.goal() : p.goal();
            if (height != null && weight != null && goal != null) {
                LocalDate today = LocalDates.today(user.timezone(), Clock.systemUTC());
                u.push("nutritionTargets", NutritionCalculator.compute(
                    p.gender(), p.birthYear(), height, weight, goal, today));
            }
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
            setIfPresent(u, "notificationSettings.waterReminder", n.waterReminder());
        }
        SettingsRequest.Sharing s = r.sharing();
        if (s != null) {
            setIfPresent(u, "sharing.weight", s.weight());
            setIfPresent(u, "sharing.measurements", s.measurements());
            setIfPresent(u, "sharing.photos", s.photos());
            setIfPresent(u, "sharing.meals", s.meals());
        }
        if (u.getUpdateObject().isEmpty() && r.weightKg() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "NOTHING_TO_UPDATE");
        }
        if (!u.getUpdateObject().isEmpty()) {
            mongo.updateFirst(Query.query(Criteria.where("_id").is(new ObjectId(user.id()))), u, "users");
        }
        if (r.weightKg() != null) {
            // Cân nặng hiện tại là số đo của hôm nay (gộp với số đã nhập trong ngày), không sửa mốc ban đầu
            measurements.save(user, new MeasurementDtos.MeasurementRequest(r.weightKg(), null, null, null, null,
                null, null));
        }
        if (r.availability() != null) {
            // Lịch rảnh mới áp dụng ngay cho các ngày còn lại của tuần này (tuần sau lập theo lịch mới như cũ)
            scheduleSync.apply(user, r.availability());
        }
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
                NotificationRules.maxPerDay(n.get("maxPerDay")),
                n.getBoolean("waterReminder", false)),
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
                                    String quietStart, String quietEnd, int maxPerDay, boolean waterReminder) {}

        public record Sharing(boolean weight, boolean measurements, boolean photos, boolean meals) {}
    }

    public record Achievement(String code, String nameVi, String descriptionVi, String category, String earnedAt) {}
}
