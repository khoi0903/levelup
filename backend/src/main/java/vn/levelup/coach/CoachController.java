package vn.levelup.coach;

import java.time.Instant;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;
import vn.levelup.auth.CurrentUserService;
import vn.levelup.plans.PlanView;

@RestController
public class CoachController {

    private final CoachService coach;
    private final CurrentUserService currentUser;

    public CoachController(CoachService coach, CurrentUserService currentUser) {
        this.coach = coach;
        this.currentUser = currentUser;
    }

    /** Gửi tin cho coach. Hết lượt hôm nay: 429 COACH_LIMIT. Thẻ hành động chỉ là đề xuất, chưa sửa kế hoạch. */
    @PostMapping("/coach/messages")
    public CoachViews.SendResponse send(@Valid @RequestBody CoachViews.SendRequest request) {
        return coach.send(currentUser.require(), request.text());
    }

    /** Lịch sử chat, mới nhất trước. before: thời điểm ISO (lấy từ nextBefore của trang trước). */
    @GetMapping("/coach/messages")
    public CoachViews.HistoryResponse history(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant before,
            @RequestParam(defaultValue = "20") int limit) {
        return coach.history(currentUser.require(), before, limit);
    }

    /** "Dùng buổi này": áp dụng thẻ hành động của tin coach, trả kế hoạch đã cập nhật. */
    @PostMapping("/coach/messages/{messageId}/actions/apply")
    public PlanView apply(@PathVariable String messageId) {
        return coach.apply(currentUser.require(), messageId);
    }
}
