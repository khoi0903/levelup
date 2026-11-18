package vn.levelup.nutrition.service;

import java.time.Clock;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import vn.levelup.identity.model.User;
import vn.levelup.nutrition.dto.RecognitionDtos;
import vn.levelup.nutrition.rules.PopularFoods;
import vn.levelup.shared.util.LocalDates;

/** GET /foods/popular: món người dùng hay ghi cho một bữa (30 ngày gần nhất) rồi tới món phổ biến của bữa đó. */
@Service
public class PopularFoodService {

    private final MongoTemplate mongo;
    private final FoodCatalog foods;
    private final Clock clock;

    public PopularFoodService(MongoTemplate mongo, FoodCatalog foods, Clock clock) {
        this.mongo = mongo;
        this.foods = foods;
        this.clock = clock;
    }

    public List<RecognitionDtos.FoodView> popular(User user, String meal, int limit) {
        if (!PopularFoods.validMeal(meal)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "INVALID_MEAL");
        }
        LocalDate today = LocalDates.today(user.timezone(), clock);
        Query q = Query.query(Criteria.where("userId").is(new ObjectId(user.id())).and("meal").is(meal)
                .and("localDate").gte(today.minusDays(PopularFoods.LOOKBACK_DAYS).toString()))
            .with(Sort.by(Sort.Direction.DESC, "eatenAt"));
        q.fields().include("items.foodId");
        List<String> logged = new ArrayList<>();
        for (Document m : mongo.find(q, Document.class, "meal_logs")) {
            for (Document item : m.getList("items", Document.class, List.of())) {
                if (item.get("foodId") instanceof ObjectId id) {
                    logged.add(id.toHexString());
                }
            }
        }
        return PopularFoods.merge(PopularFoods.rank(logged), meal, foods.all(), limit).stream()
            .map(RecognitionDtos.FoodView::of).toList();
    }
}
