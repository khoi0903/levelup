package vn.levelup.identity.controller;

import java.time.Clock;
import java.time.LocalDate;
import java.util.List;

import org.bson.types.ObjectId;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;
import vn.levelup.identity.dto.SettingsRequest;
import vn.levelup.identity.model.User;
import vn.levelup.identity.service.CurrentUserService;
import vn.levelup.identity.service.SettingsService;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.dto.TodayCheckin;
import vn.levelup.training.service.CheckinService;

@RestController
public class MeController {

    private final CurrentUserService currentUser;
    private final SettingsService settings;
    private final Clock clock;
    private final CheckinService checkins;

    public MeController(CurrentUserService currentUser, SettingsService settings, Clock clock,
                        CheckinService checkins) {
        this.currentUser = currentUser;
        this.settings = settings;
        this.clock = clock;
        this.checkins = checkins;
    }

    /**
     * Hồ sơ, cài đặt và huy hiệu cho Trang chủ, tab Tôi, màn Huy hiệu.
     * Chưa onboarding thì trả 404 ONBOARDING_REQUIRED.
     */
    @GetMapping("/me")
    public MeResponse me() {
        return view(currentUser.require());
    }

    /** Trang Cài đặt: chỉ đổi những trường được gửi, trả lại toàn bộ hồ sơ sau khi đổi. */
    @PatchMapping("/me")
    public MeResponse update(@Valid @RequestBody SettingsRequest request) {
        User user = currentUser.require();
        settings.update(user, request);
        return view(currentUser.require());
    }

    private MeResponse view(User user) {
        LocalDate today = LocalDates.today(user.timezone(), clock);
        return new MeResponse(
            user.id(),
            user.displayName(),
            LocalDates.zone(user.timezone()).getId(),
            today.toString(),
            LocalDates.weekStart(today).toString(),
            user.profile(),
            user.streak(),
            settings.read(user.id()),
            settings.achievements(user.id()),
            checkins.today(new ObjectId(user.id()), today.toString()));
    }

    public record MeResponse(
        String id,
        String displayName,
        String timezone,
        String localDate,
        String weekStart,
        User.Profile profile,
        User.Streak streak,
        SettingsService.Settings settings,
        List<SettingsService.Achievement> achievements,
        TodayCheckin todayCheckin              // null: hôm nay chưa check-in
    ) {}
}
