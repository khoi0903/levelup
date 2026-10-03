package vn.levelup.reviews;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;
import vn.levelup.auth.CurrentUserService;
import vn.levelup.plans.PlanView;

@RestController
public class ReviewsController {

    private final WeeklyReviewService reviews;
    private final CurrentUserService currentUser;

    public ReviewsController(WeeklyReviewService reviews, CurrentUserService currentUser) {
        this.reviews = reviews;
        this.currentUser = currentUser;
    }

    /** Tổng kết tuần gần nhất kèm kế hoạch nháp tuần sau. Chưa có: 404 NO_REVIEW. */
    @GetMapping("/reviews/latest")
    public ReviewViews.ReviewView latest() {
        return reviews.latest(currentUser.require());
    }

    /** Đồng ý hoặc chỉnh kế hoạch tuần sau; trả kế hoạch đã thành active. */
    @PostMapping("/reviews/{reviewId}/decision")
    public PlanView decide(@PathVariable String reviewId, @Valid @RequestBody ReviewViews.DecisionRequest request) {
        return reviews.decide(currentUser.require(), reviewId, request);
    }
}
