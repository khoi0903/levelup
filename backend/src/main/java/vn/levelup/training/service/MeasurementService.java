package vn.levelup.training.service;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.FindAndModifyOptions;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import vn.levelup.identity.model.User;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.dto.MeasurementDtos;
import vn.levelup.training.rules.MeasurementRules;


/** Cân, đo vòng: mỗi người mỗi ngày một document body_measurements (gửi lại trong ngày thì gộp). */
@Service
public class MeasurementService {

    static final int MAX_DAYS = 730;
    private static final String[] FIELDS = {"weightKg", "waistCm", "hipCm", "chestCm", "armCm", "bodyFatPct"};

    private final MongoTemplate mongo;
    private final Clock clock;

    public MeasurementService(MongoTemplate mongo, Clock clock) {
        this.mongo = mongo;
        this.clock = clock;
    }

    public MeasurementDtos.SaveResponse save(User user, MeasurementDtos.MeasurementRequest r) {
        if (!MeasurementRules.hasAnyValue(r)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "MEASUREMENT_EMPTY");
        }
        LocalDate today = LocalDates.today(user.timezone(), clock);
        LocalDate measuredOn;
        try {
            measuredOn = r.measuredOn() == null ? today : LocalDate.parse(r.measuredOn());
        } catch (DateTimeParseException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "INVALID_DATE");
        }
        if (!MeasurementRules.validDate(measuredOn, today)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "INVALID_DATE");
        }
        ObjectId userId = new ObjectId(user.id());
        Instant now = clock.instant();

        Object[] values = {r.weightKg(), r.waistCm(), r.hipCm(), r.chestCm(), r.armCm(), r.bodyFatPct()};
        Update update = new Update().setOnInsert("createdAt", Date.from(now)).set("source", "manual");
        for (int i = 0; i < FIELDS.length; i++) {
            if (values[i] != null) {
                update.set(FIELDS[i], values[i]);
            }
        }
        Document saved = mongo.findAndModify(Query.query(Criteria.where("userId").is(userId)
                .and("measuredOn").is(measuredOn.toString())), update,
            FindAndModifyOptions.options().upsert(true).returnNew(true), Document.class, "body_measurements");

        List<MeasurementDtos.Achievement> earned = r.waistCm() == null ? List.of() : waistAchievement(userId, now);
        return new MeasurementDtos.SaveResponse(view(saved), earned);
    }

    /** So vòng eo lần đo đầu và lần đo mới nhất; đạt thì thêm huy hiệu vào users.achievements (không trùng). */
    private List<MeasurementDtos.Achievement> waistAchievement(ObjectId userId, Instant now) {
        Query withWaist = Query.query(Criteria.where("userId").is(userId).and("waistCm").exists(true));
        Document first = mongo.findOne(Query.of(withWaist).with(Sort.by(Sort.Direction.ASC, "measuredOn")).limit(1),
            Document.class, "body_measurements");
        Document latest = mongo.findOne(Query.of(withWaist).with(Sort.by(Sort.Direction.DESC, "measuredOn")).limit(1),
            Document.class, "body_measurements");
        if (first == null || latest == null) {
            return List.of();
        }
        Double firstWaist = number(first, "waistCm");
        Double latestWaist = number(latest, "waistCm");
        var code = MeasurementRules.waistAchievement(firstWaist, latestWaist, ownedAchievements(userId));
        if (code.isEmpty()) {
            return List.of();
        }
        // Điều kiện $ne trong cùng lệnh: hai request song song cũng không thêm trùng
        var result = mongo.updateFirst(Query.query(Criteria.where("_id").is(userId)
                .and("achievements.code").ne(code.get())),
            new Update().push("achievements", new Document("code", code.get()).append("earnedAt", Date.from(now))
                .append("context", new Document("firstWaistCm", firstWaist).append("waistCm", latestWaist))),
            "users");
        if (result.getModifiedCount() == 0) {
            return List.of();
        }
        Document a = mongo.findOne(Query.query(Criteria.where("code").is(code.get())), Document.class,
            "achievements");
        return List.of(new MeasurementDtos.Achievement(code.get(), a == null ? null : a.getString("nameVi"),
            a == null ? null : a.getString("descriptionVi")));
    }

    public MeasurementDtos.ListResponse list(User user, int days) {
        if (days < 1 || days > MAX_DAYS) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "INVALID_DAYS");
        }
        LocalDate today = LocalDates.today(user.timezone(), clock);
        String from = today.minusDays(days - 1L).toString();
        List<MeasurementDtos.MeasurementView> items = mongo.find(Query.query(Criteria.where("userId")
                    .is(new ObjectId(user.id())).and("measuredOn").gte(from).lte(today.toString()))
                .with(Sort.by(Sort.Direction.ASC, "measuredOn")), Document.class, "body_measurements")
            .stream().map(MeasurementService::view).toList();
        return new MeasurementDtos.ListResponse(days, items);
    }

    private Set<String> ownedAchievements(ObjectId userId) {
        Document user = mongo.findById(userId, Document.class, "users");
        if (user == null) {
            return Set.of();
        }
        return user.getList("achievements", Document.class, List.of()).stream()
            .map(a -> a.getString("code")).collect(Collectors.toSet());
    }

    private static MeasurementDtos.MeasurementView view(Document d) {
        Map<String, Double> v = new HashMap<>();
        for (String f : FIELDS) {
            v.put(f, number(d, f));
        }
        return new MeasurementDtos.MeasurementView(d.getString("measuredOn"), v.get("weightKg"), v.get("waistCm"),
            v.get("hipCm"), v.get("chestCm"), v.get("armCm"), v.get("bodyFatPct"));
    }

    private static Double number(Document d, String key) {
        return d.get(key) instanceof Number n ? n.doubleValue() : null;
    }
}
