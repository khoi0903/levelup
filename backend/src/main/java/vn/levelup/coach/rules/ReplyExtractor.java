package vn.levelup.coach.rules;

/**
 * Đọc dần câu trả lời của coach từ JSON AI đang trả về ({"reply": "...", "action": ..., "memory": ...}),
 * để app hiện chữ ngay mà không chờ AI trả xong. Chỉ lấy chuỗi "reply"; phần còn lại (đề xuất, trí nhớ)
 * vẫn được backend kiểm tra sau khi có đủ JSON như cũ.
 *
 * Mỗi lần {@link #feed} trả phần chữ mới giải mã được (có thể rỗng). Ký tự thoát hoặc \\uXXXX bị cắt giữa
 * hai đoạn thì chờ đoạn sau. Không phải trình phân tích JSON đầy đủ: chỉ tìm khóa "reply" đầu tiên.
 */
public final class ReplyExtractor {

    private static final String KEY = "\"reply\"";

    private enum State { SEARCH, IN_STRING, DONE }

    private final StringBuilder raw = new StringBuilder();
    private State state = State.SEARCH;
    /** Vị trí bắt đầu tìm khóa (SEARCH) hoặc ký tự kế tiếp cần đọc trong chuỗi (IN_STRING). */
    private int pos;

    public String feed(String chunk) {
        if (chunk == null || chunk.isEmpty() || state == State.DONE) {
            return "";
        }
        raw.append(chunk);
        if (state == State.SEARCH && !findStart()) {
            return "";
        }
        return readString();
    }

    boolean done() {
        return state == State.DONE;
    }

    /** Tìm "reply" : " — đủ thì chuyển sang đọc chuỗi; thiếu (bị cắt) thì giữ vị trí chờ đoạn sau. */
    private boolean findStart() {
        while (true) {
            int key = raw.indexOf(KEY, pos);
            if (key < 0) {
                pos = Math.max(pos, raw.length() - KEY.length());
                return false;
            }
            int i = skipSpaces(key + KEY.length());
            if (i >= raw.length()) {
                pos = key;
                return false;
            }
            if (raw.charAt(i) != ':') {
                pos = key + 1;
                continue;
            }
            i = skipSpaces(i + 1);
            if (i >= raw.length()) {
                pos = key;
                return false;
            }
            if (raw.charAt(i) != '"') {
                pos = key + 1;
                continue;
            }
            pos = i + 1;
            state = State.IN_STRING;
            return true;
        }
    }

    private String readString() {
        StringBuilder out = new StringBuilder();
        while (pos < raw.length()) {
            char c = raw.charAt(pos);
            if (c == '"') {
                state = State.DONE;
                pos++;
                break;
            }
            if (c != '\\') {
                out.append(c);
                pos++;
                continue;
            }
            if (pos + 1 >= raw.length()) {
                break;                                  // chờ ký tự sau dấu \
            }
            char n = raw.charAt(pos + 1);
            if (n == 'u') {
                if (pos + 6 > raw.length()) {
                    break;                              // chờ đủ 4 chữ số hex
                }
                try {
                    out.append((char) Integer.parseInt(raw.substring(pos + 2, pos + 6), 16));
                } catch (NumberFormatException e) {
                    // \\u sai: bỏ qua, phần kiểm tra JSON đầy đủ phía sau sẽ quyết định
                }
                pos += 6;
                continue;
            }
            out.append(switch (n) {
                case 'n' -> '\n';
                case 't' -> '\t';
                case 'r' -> '\r';
                case 'b' -> '\b';
                case 'f' -> '\f';
                default -> n;                           // \" \\ \/
            });
            pos += 2;
        }
        return out.toString();
    }

    private int skipSpaces(int i) {
        while (i < raw.length() && Character.isWhitespace(raw.charAt(i))) {
            i++;
        }
        return i;
    }
}
