package vn.levelup.identity.controller;

import java.time.Clock;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import org.bson.types.ObjectId;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;
import jakarta.validation.constraints.AssertTrue;
import vn.levelup.demo.DemoAccess;
import vn.levelup.identity.dto.SettingsRequest;
import vn.levelup.identity.model.User;
import vn.levelup.identity.service.AccountDeletionService;
import vn.levelup.identity.service.CurrentUserService;
import vn.levelup.identity.service.SettingsService;
import vn.levelup.identity.service.PlanAccess;
import vn.levelup.identity.service.ProductConfigService;
import vn.levelup.identity.dto.SubscriptionView;
import vn.levelup.identity.dto.ProductConfig;
import java.time.Instant;
import vn.levelup.engagement.service.PainFollowUpService;
import vn.levelup.engagement.service.ReferralService;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.dto.TodayCheckin;
import vn.levelup.training.service.CheckinService;

@RestController
public class MeController {

    private static final Logger log = LoggerFactory.getLogger(MeController.class);

    private final CurrentUserService currentUser;
    private final SettingsService settings;
    private final Clock clock;
    private final CheckinService checkins;
    private final AccountDeletionService deletion;
    private final DemoAccess demo;
    private final PlanAccess plans;
    private final ProductConfigService configs;
    private final ReferralService referrals;
    private final PainFollowUpService painFollowUps;

    public MeController(CurrentUserService currentUser, SettingsService settings, Clock clock,
                        CheckinService checkins, AccountDeletionService deletion, DemoAccess demo, PlanAccess plans, ProductConfigService configs, ReferralService referrals,
                        PainFollowUpService painFollowUps) {
        this.currentUser = currentUser;
        this.settings = settings;
        this.clock = clock;
        this.checkins = checkins;
        this.deletion = deletion;
        this.demo = demo;
        this.plans = plans;
        this.configs = configs;
        this.referrals = referrals;
        this.painFollowUps = painFollowUps;
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

    /**
     * Xoá vĩnh viễn tài khoản và toàn bộ dữ liệu (Google Play bắt buộc). Body {"confirm": true} để tránh gọi nhầm.
     * Xong trả 204; app đăng xuất. Không hoàn tác được.
     */
    @DeleteMapping("/me")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@Valid @RequestBody DeleteAccountRequest request) {
        User user = currentUser.require();
        Map<String, Long> deleted = deletion.deleteData(user);
        deleted.put("events", deletion.deleteEvents(user));
        deletion.deleteLogin(user.authUid());
        log.info("[delete-account] user={} đã xoá {}", user.id(), deleted);
    }

    public record DeleteAccountRequest(@AssertTrue boolean confirm) {}

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
            checkins.today(new ObjectId(user.id()), today.toString()),
            demo.allowedFor(user.authUid()), demo.isAdmin(user.authUid()), plans.subscription(user),
            configs.get(), user.createdAt(), referrals.canRedeem(user), painFollowUps.due(user, today),
            painFollowUps.activeInjuries(user));
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
        TodayCheckin todayCheckin,             // null: hôm nay chưa check-in
        boolean demoEnabled,
        boolean isAdmin,
        SubscriptionView subscription,
        ProductConfig productConfig,
        Instant createdAt,
        boolean referralRedeemEligible,
        List<PainFollowUpService.FollowUpView> painFollowUps,  // vùng đau cần hỏi thăm hôm nay, rỗng nếu không có
        List<PainFollowUpService.ActiveInjuryView> activeInjuries  // vùng đang tránh khi chọn bài
    ) {}
}
