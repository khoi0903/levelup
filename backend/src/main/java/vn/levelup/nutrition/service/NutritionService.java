package vn.levelup.nutrition.service;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;

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
import vn.levelup.training.service.ActivityService;
import vn.levelup.identity.model.User;
import vn.levelup.nutrition.dto.MealDtos;
import vn.levelup.nutrition.dto.RecognitionDtos;
import vn.levelup.nutrition.model.Food;
import vn.levelup.nutrition.rules.NutritionRules;
import vn.levelup.nutrition.rules.RecognitionParser;
import vn.levelup.nutrition.rules.VietText;
import vn.levelup.shared.util.LocalDates;


/** Bữa ăn, nước uống và tổng kết dinh dưỡng trong ngày (F8). */
@Service
public class NutritionService {

    private static final Duration CLOCK_SKEW = Duration.ofMinutes(5);
    private static final Duration MAX_BACKFILL = Duration.ofDays(30);

    private final MongoTemplate mongo;
    private final FoodCatalog foods;
    private final Clock clock;
    private final ActivityService activity;
    private final FoodCandidateService candidates;

    public NutritionService(MongoTemplate mongo, FoodCatalog foods, Clock clock, ActivityService activity,
                            FoodCandidateService candidates) {
        this.mongo = mongo;
        this.foods = foods;
        this.clock = clock;
        this.activity = activity;
        this.candidates = candidates;
    }

    /** Lưu một bữa. Số liệu tính lại ở server; trả về tổng kết hôm nay kèm gợi ý nếu thiếu đạm. */
    public MealDtos.TodayView saveMeal(User user, MealDtos.MealRequest r) {
        ObjectId userId = new ObjectId(user.id());
        Instant now = clock.instant();
        Instant eatenAt = r.eatenAt() == null ? now : r.eatenAt();
        if (eatenAt.isAfter(now.plus(CLOCK_SKEW)) || eatenAt.isBefore(now.minus(MAX_BACKFILL))) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "INVALID_TIME");
        }
        LocalDate localDate = eatenAt.atZone(LocalDates.zone(user.timezone())).toLocalDate();

        // Ảnh: recognitionId phải là của chính người dùng này
        Document recognition = null;
        if (r.recognitionId() != null) {
            if (!"photo".equals(r.method())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "INVALID_METHOD");
            }
            recognition = mongo.findOne(Query.query(Criteria.where("_id").is(new ObjectId(r.recognitionId()))
                .and("userId").is(userId)), Document.class, "food_recognitions");
            if (recognition == null) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "UNKNOWN_RECOGNITION");
            }
        } else if ("photo".equals(r.method())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "RECOGNITION_REQUIRED");
        }

        List<Document> items = new ArrayList<>();
        double kcal = 0;
        double protein = 0;
        double carbs = 0;
        double fat = 0;
        // Món AI ước tính (chưa có trong kho): server tự tính calo theo số gam, người dùng chỉ sửa được số gam
        java.util.Map<String, RecognitionParser.Estimate> estimates = new java.util.HashMap<>();
        if (recognition != null) {
            for (RecognitionParser.Dish d : MealRecognitionService.dishesFrom(recognition)) {
                if (d.per100g() != null) {
                    estimates.putIfAbsent(VietText.normalize(d.nameVi()), d.per100g());
                }
            }
        }
        for (MealDtos.Item it : r.items()) {
            Document item = item(it, "photo".equals(r.method()), estimates);
            items.add(item);
            kcal += ((Number) item.get("kcal")).doubleValue();
            protein += ((Number) item.get("proteinG")).doubleValue();
            carbs += ((Number) item.get("carbsG")).doubleValue();
            fat += ((Number) item.get("fatG")).doubleValue();
        }

        Document meal = new Document("userId", userId)
            .append("localDate", localDate.toString())
            .append("eatenAt", Date.from(eatenAt))
            .append("meal", r.meal())
            .append("method", r.method())
            .append("kcal", (int) Math.round(kcal))
            .append("proteinG", NutritionRules.round1(protein))
            .append("carbsG", NutritionRules.round1(carbs))
            .append("fatG", NutritionRules.round1(fat))
            .append("items", items)
            .append("createdAt", Date.from(now))
            .append("updatedAt", Date.from(now));
        if (recognition != null) {
            meal.append("recognitionId", recognition.getObjectId("_id"));
            MealRecognitionService.dishesFrom(recognition).stream()
                .mapToDouble(RecognitionParser.Dish::confidence).min()
                .ifPresent(c -> meal.append("aiConfidence", c));
            meal.append("kcalMin", (int) Math.round(kcal * (1 - NutritionRules.RANGE)))
                .append("kcalMax", (int) Math.round(kcal * (1 + NutritionRules.RANGE)));
        }
        mongo.insert(meal, "meal_logs");
        // Món ảnh chưa có trong kho: số người dùng đã xem/sửa trước khi lưu, gom vào kho chờ duyệt.
        // Không gom tên gõ tay (method manual/search): dễ là chữ riêng tư hoặc không phải tên món.
        for (Document item : "photo".equals(r.method()) ? items : List.<Document>of()) {
            if (item.get("foodId") == null) {
                candidates.recordSaved(userId, item.getString("name"),
                    item.get("grams") instanceof Number g ? g.doubleValue() : null,
                    ((Number) item.get("kcal")).doubleValue(), ((Number) item.get("proteinG")).doubleValue(),
                    ((Number) item.get("carbsG")).doubleValue(), ((Number) item.get("fatG")).doubleValue(),
                    "photo".equals(r.method()));
            }
        }
        return today(user);
    }

    /**
     * Món có foodId: tính lại từ kho. Món AI ước tính trong ảnh: tính lại từ số /100 g đã lưu theo số gam.
     * Món nhập tay: dùng số app gửi, đã giới hạn bằng validation.
     */
    private Document item(MealDtos.Item it, boolean fromPhoto, java.util.Map<String, RecognitionParser.Estimate> estimates) {
        Document d = new Document("name", it.name().trim()).append("aiSuggested", fromPhoto);
        if (it.foodId() != null) {
            Food food = foods.byId(it.foodId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "UNKNOWN_FOOD"));
            double grams = it.portionGrams() != null ? it.portionGrams() : food.servingGrams();
            NutritionRules.Portion p = NutritionRules.portion(food, grams);
            return d.append("foodId", new ObjectId(food.id())).append("grams", grams).append("kcal", p.kcal())
                .append("proteinG", p.proteinG()).append("carbsG", p.carbsG()).append("fatG", p.fatG());
        }
        RecognitionParser.Estimate estimate = estimates.get(VietText.normalize(it.name()));
        if (estimate != null && it.portionGrams() != null) {
            NutritionRules.Portion p = NutritionRules.estimatePortion(estimate, it.portionGrams());
            return d.append("grams", it.portionGrams()).append("kcal", p.kcal()).append("proteinG", p.proteinG())
                .append("carbsG", p.carbsG()).append("fatG", p.fatG()).append("aiEstimated", true);
        }
        if (it.kcal() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "ITEM_KCAL_REQUIRED");
        }
        if (it.portionGrams() != null) {
            d.append("grams", it.portionGrams());
        }
        return d.append("kcal", (int) Math.round(it.kcal()))
            .append("proteinG", NutritionRules.round1(orZero(it.proteinG())))
            .append("carbsG", NutritionRules.round1(orZero(it.carbsG())))
            .append("fatG", NutritionRules.round1(orZero(it.fatG())))
            .append("userEdited", true);
    }

    public MealDtos.TodayView today(User user) {
        ObjectId userId = new ObjectId(user.id());
        ZoneId zone = LocalDates.zone(user.timezone());
        LocalDate today = LocalDates.today(user.timezone(), clock);
        String gender = user.profile() == null ? null : user.profile().gender();
        NutritionRules.Target target = NutritionRules.effectiveTarget(user.nutritionTargets(), today, gender);

        List<Document> logs = mongo.find(Query.query(Criteria.where("userId").is(userId)
                .and("localDate").is(today.toString())).with(Sort.by("eatenAt", "_id")),
            Document.class, "meal_logs");
        List<MealDtos.MealView> meals = logs.stream().map(NutritionService::mealView).toList();
        int kcal = meals.stream().mapToInt(MealDtos.MealView::kcal).sum();
        double protein = NutritionRules.round1(meals.stream().mapToDouble(MealDtos.MealView::proteinG).sum());
        double carbs = NutritionRules.round1(meals.stream().mapToDouble(MealDtos.MealView::carbsG).sum());
        double fat = NutritionRules.round1(meals.stream().mapToDouble(MealDtos.MealView::fatG).sum());
        MealDtos.Totals consumed = new MealDtos.Totals(kcal, protein, carbs, fat);

        MealDtos.Totals remaining = null;
        MealDtos.Suggestion suggestion = null;
        if (target != null) {
            remaining = new MealDtos.Totals(target.kcal() - kcal, NutritionRules.round1(target.proteinG() - protein),
                NutritionRules.round1(target.carbsG() - carbs), NutritionRules.round1(target.fatG() - fat));
            suggestion = suggestion(LocalTime.now(clock.withZone(zone)), remaining);
        }
        int burned = burnedKcal(userId, today);
        ActivityService.Activity a = activity.today(userId, today).orElse(new ActivityService.Activity(0, 0));
        return new MealDtos.TodayView(today.toString(), target, consumed, remaining, waterMl(userId, today),
            meals, suggestion, burned, a.steps(), a.activeKcal(), NutritionRules.totalBurnedKcal(burned, a.activeKcal()));
    }

    private MealDtos.Suggestion suggestion(LocalTime localTime, MealDtos.Totals remaining) {
        if (!NutritionRules.shouldSuggestProtein(localTime, remaining.proteinG())) {
            return null;
        }
        List<Food> picked = NutritionRules.proteinFoods(foods.all(), remaining.kcal(), remaining.proteinG());
        if (picked.isEmpty()) {
            return null;            // không còn calo cho món nhiều đạm: không gợi ý ăn thêm
        }
        return new MealDtos.Suggestion(NutritionRules.suggestionMessage(remaining.proteinG(), picked),
            picked.stream().map(RecognitionDtos.FoodView::of).toList());
    }

    /** Cộng nước uống hôm nay (một lệnh $inc, tạo document của ngày nếu chưa có). */
    public MealDtos.WaterView addWater(User user, int ml) {
        ObjectId userId = new ObjectId(user.id());
        LocalDate today = LocalDates.today(user.timezone(), clock);
        Document day = mongo.findAndModify(dayQuery(userId, today), new Update().inc("waterMl", ml),
            FindAndModifyOptions.options().upsert(true).returnNew(true), Document.class, "daily_stats");
        String gender = user.profile() == null ? null : user.profile().gender();
        NutritionRules.Target target = NutritionRules.effectiveTarget(user.nutritionTargets(), today, gender);
        return new MealDtos.WaterView(today.toString(), ((Number) day.get("waterMl")).intValue(),
            target == null ? null : target.waterMl());
    }

    /** Tổng calo đốt ước tính của các buổi tập trong ngày (workout_logs.kcalBurned). */
    private int burnedKcal(ObjectId userId, LocalDate day) {
        return mongo.find(Query.query(Criteria.where("userId").is(userId).and("localDate").is(day.toString())),
                Document.class, "workout_logs").stream()
            .mapToInt(d -> d.get("kcalBurned") instanceof Number n ? n.intValue() : 0).sum();
    }

    private int waterMl(ObjectId userId, LocalDate day) {
        Document d = mongo.findOne(dayQuery(userId, day), Document.class, "daily_stats");
        return d != null && d.get("waterMl") instanceof Number n ? n.intValue() : 0;
    }

    private static Query dayQuery(ObjectId userId, LocalDate day) {
        return Query.query(Criteria.where("userId").is(userId).and("localDate").is(day.toString()));
    }

    private static MealDtos.MealView mealView(Document d) {
        List<MealDtos.ItemView> items = d.getList("items", Document.class, List.of()).stream()
            .map(i -> new MealDtos.ItemView(i.get("foodId") instanceof ObjectId f ? f.toHexString() : null,
                i.getString("name"), i.get("grams") instanceof Number g ? g.doubleValue() : null, intOf(i, "kcal"),
                num(i, "proteinG"), num(i, "carbsG"), num(i, "fatG")))
            .toList();
        Date eatenAt = d.getDate("eatenAt");
        return new MealDtos.MealView(d.getObjectId("_id").toHexString(), d.getString("meal"), d.getString("method"),
            eatenAt == null ? null : eatenAt.toInstant(), intOf(d, "kcal"),
            d.get("kcalMin") instanceof Number n ? n.intValue() : null,
            d.get("kcalMax") instanceof Number n ? n.intValue() : null,
            num(d, "proteinG"), num(d, "carbsG"), num(d, "fatG"), items);
    }

    private static int intOf(Document d, String key) {
        return d.get(key) instanceof Number n ? (int) Math.round(n.doubleValue()) : 0;
    }

    private static double num(Document d, String key) {
        return d.get(key) instanceof Number n ? n.doubleValue() : 0;
    }

    private static double orZero(Double v) {
        return v == null ? 0 : v;
    }
}
