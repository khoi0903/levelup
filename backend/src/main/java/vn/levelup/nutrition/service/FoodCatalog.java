package vn.levelup.nutrition.service;

import java.util.List;
import java.util.Optional;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.stereotype.Service;
import vn.levelup.nutrition.model.Food;

/** Đọc kho foods. Kho nhỏ (khoảng 100 món) nên đọc hết rồi so khớp trong bộ nhớ. */
@Service
public class FoodCatalog {

    private final MongoTemplate mongo;

    public FoodCatalog(MongoTemplate mongo) {
        this.mongo = mongo;
    }

    public List<Food> all() {
        return mongo.findAll(Document.class, "foods").stream().map(Food::from).toList();
    }

    public Optional<Food> byId(String id) {
        if (id == null || !ObjectId.isValid(id)) {
            return Optional.empty();
        }
        Document d = mongo.findOne(Query.query(Criteria.where("_id").is(new ObjectId(id))), Document.class, "foods");
        return Optional.ofNullable(d).map(Food::from);
    }
}
