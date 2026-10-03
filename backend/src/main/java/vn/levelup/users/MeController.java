package vn.levelup.users;

import java.time.Clock;
import java.time.LocalDate;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import vn.levelup.auth.CurrentUserService;
import vn.levelup.common.LocalDates;

@RestController
public class MeController {

    private final CurrentUserService currentUser;
    private final Clock clock;

    public MeController(CurrentUserService currentUser, Clock clock) {
        this.currentUser = currentUser;
        this.clock = clock;
    }

    /**
     * Dữ liệu cho màn Trang chủ. Sprint sau bổ sung tiến độ tuần và calo còn lại.
     * Chưa onboarding thì trả 404 ONBOARDING_REQUIRED.
     */
    @GetMapping("/me")
    public MeResponse me() {
        User user = currentUser.require();
        LocalDate today = LocalDates.today(user.timezone(), clock);
        return new MeResponse(
            user.id(),
            user.displayName(),
            LocalDates.zone(user.timezone()).getId(),
            today.toString(),
            LocalDates.weekStart(today).toString(),
            user.profile(),
            user.streak());
    }

    public record MeResponse(
        String id,
        String displayName,
        String timezone,
        String localDate,
        String weekStart,
        User.Profile profile,
        User.Streak streak
    ) {}
}
