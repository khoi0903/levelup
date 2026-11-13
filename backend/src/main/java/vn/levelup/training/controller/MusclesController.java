package vn.levelup.training.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import vn.levelup.identity.service.CurrentUserService;
import vn.levelup.training.dto.MuscleWeekView;
import vn.levelup.training.service.MuscleWeekService;

@RestController
public class MusclesController {

    private final MuscleWeekService muscles;
    private final CurrentUserService currentUser;

    public MusclesController(MuscleWeekService muscles, CurrentUserService currentUser) {
        this.muscles = muscles;
        this.currentUser = currentUser;
    }

    /**
     * Số hiệp theo nhóm cơ trong tuần (hình cơ thể tô màu). weekStart "YYYY-MM-DD", bỏ trống là tuần này
     * theo múi giờ người dùng; sai định dạng trả 400 INVALID_DATE.
     */
    @GetMapping("/me/muscles/week")
    public MuscleWeekView week(@RequestParam(name = "weekStart", required = false) String weekStart) {
        return muscles.week(currentUser.require(), weekStart);
    }
}
