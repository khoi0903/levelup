package vn.levelup.nutrition;

import java.util.List;

import org.bson.Document;

/** Một món trong kho foods (mongo/seed/foods.json). Số liệu tính cho một khẩu phần servingGrams. */
public record Food(
    String id,
    String nameVi,
    String searchName,
    List<String> aliases,
    String category,
    String servingDesc,
    double servingGrams,
    double kcal,
    double proteinG,
    double carbsG,
    double fatG
) {
    public static Food from(Document d) {
        return new Food(d.getObjectId("_id").toHexString(), d.getString("nameVi"), d.getString("searchName"),
            d.getList("aliases", String.class, List.of()), d.getString("category"), d.getString("servingDesc"),
            number(d, "servingGrams"), number(d, "kcal"), number(d, "proteinG"), number(d, "carbsG"),
            number(d, "fatG"));
    }

    private static double number(Document d, String key) {
        return d.get(key) instanceof Number n ? n.doubleValue() : 0;
    }
}
