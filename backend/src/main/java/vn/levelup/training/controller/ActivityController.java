package vn.levelup.training.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;
import vn.levelup.identity.service.CurrentUserService;
import vn.levelup.training.dto.ActivityDtos;
import vn.levelup.training.service.ActivityService;

@RestController
public class ActivityController {

    private final ActivityService activity;
    private final CurrentUserService currentUser;

    public ActivityController(ActivityService activity, CurrentUserService currentUser) {
        this.activity = activity;
        this.currentUser = currentUser;
    }

    /**
     * Số bước và calo vận động hôm nay từ Health Connect (app gửi khi mở Trang chủ / kéo làm mới).
     * Dùng cho thẻ dinh dưỡng (GET /nutrition/today) và ngữ cảnh AI coach.
     */
    @PostMapping("/activity/today")
    public ActivityDtos.ActivityView save(@Valid @RequestBody ActivityDtos.ActivityRequest request) {
        return activity.save(currentUser.require(), request);
    }

    /** Số đã lưu hôm nay (lớn nhất giữa các điện thoại) và giờ các buổi tập hôm nay. */
    @GetMapping("/activity/today")
    public ActivityDtos.TodayView today() {
        return activity.todayView(currentUser.require());
    }

    /** Lịch sử số bước và calo vận động từng ngày, days = 1–90 (mặc định 30). */
    @GetMapping("/activity/history")
    public ActivityDtos.HistoryView history(@RequestParam(defaultValue = "30") int days) {
        return activity.history(currentUser.require(), days);
    }
}
