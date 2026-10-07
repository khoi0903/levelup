package vn.levelup.nutrition.rules;

import java.text.Normalizer;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Chuẩn hóa tên món tiếng Việt để so khớp với foods.searchName:
 * chữ thường, bỏ dấu (kể cả đ thành d), bỏ ký tự lạ, gộp khoảng trắng. "Phở Bò Tái!" -> "pho bo tai".
 */
public final class VietText {

    private static final Pattern MARKS = Pattern.compile("\\p{M}+");
    private static final Pattern NOT_WORD = Pattern.compile("[^a-z0-9]+");

    private VietText() {}

    public static String normalize(String text) {
        if (text == null) {
            return "";
        }
        String lower = text.toLowerCase(Locale.ROOT).replace('đ', 'd');
        String stripped = MARKS.matcher(Normalizer.normalize(lower, Normalizer.Form.NFD)).replaceAll("");
        return NOT_WORD.matcher(stripped).replaceAll(" ").trim();
    }

    public static List<String> tokens(String text) {
        String n = normalize(text);
        return n.isEmpty() ? List.of() : Arrays.asList(n.split(" "));
    }
}
