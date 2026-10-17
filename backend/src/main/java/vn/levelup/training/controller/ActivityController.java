package vn.levelup.training.controller;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
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
}
