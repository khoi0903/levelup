package vn.levelup.workouts;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;
import vn.levelup.auth.CurrentUserService;

@RestController
public class WorkoutsController {

    private final WorkoutService workouts;
    private final CurrentUserService currentUser;

    public WorkoutsController(WorkoutService workouts, CurrentUserService currentUser) {
        this.workouts = workouts;
        this.currentUser = currentUser;
    }

    /** Lưu buổi tập vừa xong. Gửi lại cùng clientId thì nhận kết quả cũ (duplicate = true). */
    @PostMapping("/workouts")
    public WorkoutResponse save(@Valid @RequestBody WorkoutRequest request) {
        return workouts.save(currentUser.require(), request);
    }
}
