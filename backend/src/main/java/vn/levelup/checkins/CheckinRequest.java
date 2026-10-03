package vn.levelup.checkins;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

/** Giá trị enum khớp validator daily_stats.checkin. */
public record CheckinRequest(
    @NotNull @Pattern(regexp = "tired|normal|energized") String energy,
    @Pattern(regexp = "lt6|h6_7|h7_8|gt8") String sleep
) {}
