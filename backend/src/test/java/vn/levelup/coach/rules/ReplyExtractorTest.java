package vn.levelup.coach.rules;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class ReplyExtractorTest {

    /** Ghép mọi phần trả về khi đưa từng đoạn vào. */
    private static String feedAll(String... chunks) {
        ReplyExtractor x = new ReplyExtractor();
        StringBuilder out = new StringBuilder();
        for (String c : chunks) {
            out.append(x.feed(c));
        }
        return out.toString();
    }

    @Test
    void whole_json_at_once() {
        assertEquals("Chào Khôi!", feedAll("{\"reply\": \"Chào Khôi!\", \"action\": null}"));
    }

    @Test
    void reply_split_across_many_chunks_including_key() {
        assertEquals("Hôm nay tập nhẹ nhé",
            feedAll("```json\n{\"re", "ply\"", " :", " \"Hôm na", "y tập nh", "ẹ nhé\", \"memory\": []}"));
    }

    @Test
    void escapes_and_unicode_cut_between_chunks() {
        assertEquals("Dòng 1\nDòng \"2\" \\ ê",
            feedAll("{\"reply\":\"Dòng 1\\", "nDòng \\\"2\\\" \\\\ \\u0", "0ea\"}"));
    }

    @Test
    void stops_at_end_of_reply_and_ignores_rest() {
        ReplyExtractor x = new ReplyExtractor();
        assertEquals("Ok", x.feed("{\"reply\":\"Ok\",\"action\":{\"reason\":\"reply\"}"));
        assertTrue(x.done());
        assertEquals("", x.feed(", \"reply\": \"khác\"}"));
    }

    @Test
    void streams_incrementally() {
        ReplyExtractor x = new ReplyExtractor();
        assertEquals("", x.feed("{\"memory\": [], "));
        assertEquals("Xin", x.feed("\"reply\": \"Xin"));
        assertEquals(" chào", x.feed(" chào"));
        assertEquals("", x.feed("\\"));                 // chờ ký tự sau dấu \
        assertEquals("!", x.feed("u0021\"}"));
    }

    @Test
    void no_reply_key_yields_nothing() {
        assertEquals("", feedAll("{\"answer\": \"x\"}", "không phải JSON"));
    }
}
