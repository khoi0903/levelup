package vn.levelup.training.dto;

/** Check-in hôm nay của người dùng (daily_stats.checkin): energy tired|normal|energized, sleep lt6|h6_7|h7_8|gt8. */
public record TodayCheckin(String energy, String sleep) {

    /** Mệt hoặc ngủ dưới 6 tiếng: nên tập nhẹ, ngắn (cùng điều kiện với CheckinAdjuster). */
    public boolean low() {
        return "tired".equals(energy) || "lt6".equals(sleep);
    }
}
