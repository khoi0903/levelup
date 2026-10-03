package vn.levelup.motivation;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.bson.Document;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

/**
 * Mẫu tin nhắn coach theo phong cách strict | supportive | funny, đọc từ docs/content/coach-messages.json
 * (pom.xml đóng gói vào classpath:content/). Chỗ trống dạng {ten}, {ly_do}, {so_buoi}.
 */
@Component
public class CoachTemplates {

    private static final Logger log = LoggerFactory.getLogger(CoachTemplates.class);
    static final String RESOURCE = "content/coach-messages.json";

    private final Document templates;

    public CoachTemplates() {
        this(load());
    }

    CoachTemplates(Document templates) {
        this.templates = templates;
    }

    private static Document load() {
        ClassPathResource resource = new ClassPathResource(RESOURCE);
        if (!resource.exists()) {
            log.warn("Không thấy {}, dùng câu mặc định", RESOURCE);
            return new Document();
        }
        try (InputStream in = resource.getInputStream()) {
            return Document.parse(new String(in.readAllBytes(), StandardCharsets.UTF_8));
        } catch (IOException e) {
            log.warn("Không đọc được {}: {}", RESOURCE, e.getMessage());
            return new Document();
        }
    }

    /**
     * Câu theo khóa và phong cách (thiếu phong cách thì dùng supportive). seed chọn một trong các biến thể,
     * cùng seed luôn ra cùng câu để job chạy lại không đổi nội dung.
     */
    public Optional<String> render(String key, String style, Map<String, String> vars, String seed) {
        if (!(templates.get(key) instanceof Document byStyle)) {
            return Optional.empty();
        }
        List<?> options = asList(byStyle.get(style == null ? "supportive" : style));
        if (options.isEmpty()) {
            options = asList(byStyle.get("supportive"));
        }
        if (options.isEmpty()) {
            return Optional.empty();
        }
        int idx = Math.floorMod(seed == null ? 0 : seed.hashCode(), options.size());
        return Optional.of(fill(String.valueOf(options.get(idx)), vars));
    }

    private static List<?> asList(Object value) {
        return value instanceof List<?> l ? l : List.of();
    }

    /** Điền chỗ trống; chỗ trống không có giá trị thì thay bằng chuỗi rỗng và gọn khoảng trắng. */
    static String fill(String template, Map<String, String> vars) {
        String text = template;
        for (var e : vars.entrySet()) {
            text = text.replace("{" + e.getKey() + "}", e.getValue() == null ? "" : e.getValue());
        }
        return text.replaceAll("\\{[a-z_]+}", "").replaceAll(" {2,}", " ").replace(" ,", ",").trim();
    }
}
