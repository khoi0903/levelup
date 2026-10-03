package vn.levelup.buddies;

import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.random.RandomGenerator;

import org.bson.Document;
import org.bson.types.ObjectId;

/** Quy tắc thuần của F5 Buddy, không đụng database để test riêng được. */
final class BuddyRules {

    /** Bỏ 0/O và 1/I cho khỏi đọc nhầm khi gõ lại mã từ tin nhắn Zalo. */
    static final String CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    static final int CODE_LENGTH = 6;

    private BuddyRules() {}

    static String newCode(RandomGenerator random) {
        StringBuilder sb = new StringBuilder(CODE_LENGTH);
        for (int i = 0; i < CODE_LENGTH; i++) {
            sb.append(CODE_ALPHABET.charAt(random.nextInt(CODE_ALPHABET.length())));
        }
        return sb.toString();
    }

    /** Người dùng gõ chữ thường, có khoảng trắng hay gạch ngang thì vẫn nhận. */
    static String normalizeCode(String raw) {
        return raw == null ? "" : raw.replaceAll("[\\s-]", "").toUpperCase(Locale.ROOT);
    }

    /** "<idNhỏ>_<idLớn>": hai người ghép theo thứ tự nào cũng ra cùng một khóa. */
    static String pairKey(ObjectId a, ObjectId b) {
        String x = a.toHexString();
        String y = b.toHexString();
        return x.compareTo(y) <= 0 ? x + "_" + y : y + "_" + x;
    }

    // ---------------------------------------------------------------------
    // Trạng thái hôm nay của buddy
    // ---------------------------------------------------------------------

    /** Buổi trong kế hoạch rơi vào hôm nay của buddy. */
    record PlannedSession(String status, String scheduledTime, String title) {}

    /** status: done | planned | rest | none. scheduledTime, title chỉ có khi planned. */
    record TodayStatus(String status, String scheduledTime, String title) {
        static TodayStatus of(String status) {
            return new TodayStatus(status, null, null);
        }
    }

    /**
     * - done: đã có buổi tính streak (từ 5 phút) hôm nay, hoặc buổi hôm nay trong kế hoạch đã hoàn thành
     * - planned: còn buổi chưa tập hôm nay, lấy giờ sớm nhất
     * - rest: có kế hoạch tuần này nhưng hôm nay là ngày nghỉ (không có buổi hoặc buổi đánh dấu nghỉ)
     * - none: chưa có kế hoạch, hoặc buổi hôm nay đã bỏ / dời đi
     */
    static TodayStatus todayStatus(boolean trainedToday, boolean hasPlan, List<PlannedSession> today) {
        if (trainedToday || today.stream().anyMatch(s -> "completed".equals(s.status()))) {
            return TodayStatus.of("done");
        }
        PlannedSession next = today.stream().filter(s -> "planned".equals(s.status()))
            .min(Comparator.comparing(PlannedSession::scheduledTime, Comparator.nullsLast(Comparator.naturalOrder())))
            .orElse(null);
        if (next != null) {
            return new TodayStatus("planned", next.scheduledTime(), next.title());
        }
        if (hasPlan && (today.isEmpty() || today.stream().anyMatch(s -> "rest".equals(s.status())))) {
            return TodayStatus.of("rest");
        }
        return TodayStatus.of("none");
    }

    // ---------------------------------------------------------------------
    // Chia sẻ: mặc định buddy chỉ thấy trạng thái tập và streak
    // ---------------------------------------------------------------------

    /** users.sharing; thiếu trường nào coi như tắt. */
    record Sharing(boolean weight, boolean measurements, boolean photos, boolean meals) {
        static final Sharing NONE = new Sharing(false, false, false, false);

        static Sharing from(Document sharing) {
            if (sharing == null) {
                return NONE;
            }
            return new Sharing(on(sharing, "weight"), on(sharing, "measurements"), on(sharing, "photos"),
                on(sharing, "meals"));
        }

        private static boolean on(Document d, String key) {
            return Boolean.TRUE.equals(d.get(key));
        }
    }

    /** Lọc dữ liệu riêng tư trước khi trả cho buddy. Không mục nào được bật thì trả null. */
    static BuddyTodayResponse.Shared filter(Sharing sharing, BuddyTodayResponse.Shared all) {
        if (all == null) {
            return null;
        }
        BuddyTodayResponse.Shared visible = new BuddyTodayResponse.Shared(
            sharing.weight() ? all.weightKg() : null,
            sharing.measurements() ? all.measurements() : null,
            sharing.meals() ? all.mealsKcalToday() : null);
        boolean empty = visible.weightKg() == null && visible.measurements() == null
            && visible.mealsKcalToday() == null;
        return empty ? null : visible;
    }
}
