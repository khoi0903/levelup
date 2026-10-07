package vn.levelup.nutrition.rules;

import java.util.ArrayList;
import java.util.List;

import tools.jackson.core.JacksonException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * Đọc và kiểm tra JSON AI trả về cho ảnh món ăn. AI không ghi database:
 * chỉ kết quả qua được bước kiểm tra này mới được lưu.
 * Dạng mong đợi: {"dishes":[{"name","nameVi","ingredients":[...],"portionGrams","confidence"}]}
 */
public final class RecognitionParser {

    static final int MAX_DISHES = 10;
    static final double MAX_PORTION_G = 3000;

    private static final JsonMapper JSON = JsonMapper.builder().build();

    public record Dish(String name, String nameVi, List<String> ingredients, double portionGrams,
                       double confidence) {}

    /** JSON sai định dạng hoặc giá trị ngoài khoảng cho phép. */
    public static class InvalidOutputException extends RuntimeException {
        public InvalidOutputException(String message) { super(message); }
    }

    private RecognitionParser() {}

    public static List<Dish> parse(String raw) {
        if (raw == null) {
            throw new InvalidOutputException("rỗng");
        }
        // AI đôi khi bọc JSON trong ```json ... ```: lấy từ dấu { đầu đến } cuối
        int start = raw.indexOf('{');
        int end = raw.lastIndexOf('}');
        if (start < 0 || end <= start) {
            throw new InvalidOutputException("không có JSON");
        }
        JsonNode root;
        try {
            root = JSON.readTree(raw.substring(start, end + 1));
        } catch (JacksonException e) {
            throw new InvalidOutputException("JSON lỗi: " + e.getOriginalMessage());
        }
        JsonNode dishes = root.get("dishes");
        if (dishes == null || !dishes.isArray() || dishes.size() > MAX_DISHES) {
            throw new InvalidOutputException("thiếu dishes");
        }
        List<Dish> result = new ArrayList<>();
        for (JsonNode d : dishes) {
            String name = text(d, "name");
            String nameVi = text(d, "nameVi");
            if (name == null && nameVi == null) {
                throw new InvalidOutputException("món thiếu tên");
            }
            JsonNode grams = d.get("portionGrams");
            JsonNode conf = d.get("confidence");
            if (grams == null || !grams.isNumber() || grams.doubleValue() <= 0
                    || grams.doubleValue() > MAX_PORTION_G) {
                throw new InvalidOutputException("portionGrams sai");
            }
            if (conf == null || !conf.isNumber() || conf.doubleValue() < 0 || conf.doubleValue() > 1) {
                throw new InvalidOutputException("confidence sai");
            }
            List<String> ingredients = new ArrayList<>();
            JsonNode ing = d.get("ingredients");
            if (ing != null && !ing.isNull()) {
                if (!ing.isArray()) {
                    throw new InvalidOutputException("ingredients sai");
                }
                for (JsonNode i : ing) {
                    if (i.isString() && !i.stringValue().isBlank() && ingredients.size() < 20) {
                        ingredients.add(limit(i.stringValue().trim()));
                    }
                }
            }
            result.add(new Dish(limit(name != null ? name : nameVi), limit(nameVi != null ? nameVi : name),
                List.copyOf(ingredients), Math.round(grams.doubleValue()), conf.doubleValue()));
        }
        return List.copyOf(result);
    }

    private static String text(JsonNode node, String field) {
        JsonNode v = node.get(field);
        return v != null && v.isString() && !v.stringValue().isBlank() ? v.stringValue().trim() : null;
    }

    private static String limit(String s) {
        return s.length() > 100 ? s.substring(0, 100) : s;
    }
}
