package vn.levelup.onboarding;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;
import vn.levelup.auth.CurrentUserService;

@RestController
public class OnboardingController {

    private final OnboardingService onboarding;
    private final CurrentUserService currentUser;

    public OnboardingController(OnboardingService onboarding, CurrentUserService currentUser) {
        this.onboarding = onboarding;
        this.currentUser = currentUser;
    }

    /** Màn cuối onboarding gửi toàn bộ câu trả lời; trả về mục tiêu calo và kế hoạch tuần 1. */
    @PostMapping("/onboarding")
    public OnboardingService.OnboardingResponse complete(@Valid @RequestBody OnboardingRequest request) {
        return onboarding.complete(currentUser.uid(), request);
    }
}
