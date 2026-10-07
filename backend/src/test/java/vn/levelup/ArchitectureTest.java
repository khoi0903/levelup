package vn.levelup;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;

import org.junit.jupiter.api.Test;

/**
 * Giữ cấu trúc nhóm/tầng mô tả trong backend/README.md. Đọc thẳng mã nguồn, không cần thư viện thêm.
 */
class ArchitectureTest {

    private static final Path SRC = Path.of("src/main/java/vn/levelup");
    private static final Set<String> GROUPS =
        Set.of("identity", "training", "coach", "nutrition", "engagement", "shared", "demo");
    private static final Set<String> LAYERS =
        Set.of("controller", "service", "rules", "model", "dto", "repository", "config", "ai", "notification", "web", "util");
    private static final Pattern IMPORT = Pattern.compile("^import (?:static )?([\\w.]+);", Pattern.MULTILINE);

    record Source(String group, String layer, String name, List<String> imports) {}

    private static List<Source> sources() throws IOException {
        List<Source> out = new ArrayList<>();
        try (Stream<Path> files = Files.walk(SRC)) {
            for (Path p : files.filter(f -> f.toString().endsWith(".java")).toList()) {
                Path rel = SRC.relativize(p);
                String group = rel.getNameCount() > 1 ? rel.getName(0).toString() : "";
                String layer = rel.getNameCount() > 2 ? rel.getName(1).toString() : "";
                List<String> imports = new ArrayList<>();
                Matcher m = IMPORT.matcher(Files.readString(p));
                while (m.find()) {
                    imports.add(m.group(1));
                }
                out.add(new Source(group, layer, rel.toString(), imports));
            }
        }
        return out;
    }

    private static String layerOf(String imported) {
        String[] parts = imported.split("\\.");
        return parts.length > 3 && parts[0].equals("vn") ? parts[3] : "";
    }

    @Test
    void moiLopNamDungNhomVaTang() throws IOException {
        List<String> bad = new ArrayList<>();
        for (Source s : sources()) {
            if (s.group().isEmpty() || s.name().endsWith("package-info.java")) {
                continue;
            }
            boolean flatGroup = s.group().equals("demo") && s.layer().isEmpty();
            if (!GROUPS.contains(s.group()) || !(flatGroup || LAYERS.contains(s.layer()))) {
                bad.add(s.name());
            }
        }
        assertTrue(bad.isEmpty(), "Lớp nằm ngoài nhóm/tầng đã định: " + bad);
    }

    @Test
    void rulesVaDtoKhongDungSpringHayDatabase() throws IOException {
        List<String> bad = new ArrayList<>();
        for (Source s : sources()) {
            if (!s.layer().equals("rules") && !s.layer().equals("dto")) {
                continue;
            }
            for (String imp : s.imports()) {
                if (imp.startsWith("org.springframework") || imp.startsWith("com.mongodb")
                    || Set.of("service", "repository", "controller", "ai", "notification").contains(layerOf(imp))) {
                    bad.add(s.name() + " -> " + imp);
                }
            }
        }
        assertTrue(bad.isEmpty(), "rules/dto phải là logic thuần: " + bad);
    }

    @Test
    void khongAiGoiThangVaoController() throws IOException {
        List<String> bad = new ArrayList<>();
        for (Source s : sources()) {
            for (String imp : s.imports()) {
                if (layerOf(imp).equals("controller") && imp.startsWith("vn.levelup.")) {
                    bad.add(s.name() + " -> " + imp);
                }
            }
        }
        assertTrue(bad.isEmpty(), "Controller chỉ nhận request, lớp khác không gọi vào: " + bad);
    }

    @Test
    void modelKhongPhuThuocTangTren() throws IOException {
        List<String> bad = new ArrayList<>();
        for (Source s : sources()) {
            if (!s.layer().equals("model")) {
                continue;
            }
            for (String imp : s.imports()) {
                if (Set.of("service", "repository", "controller").contains(layerOf(imp))) {
                    bad.add(s.name() + " -> " + imp);
                }
            }
        }
        assertTrue(bad.isEmpty(), "model chỉ mô tả dữ liệu: " + bad);
    }
}
