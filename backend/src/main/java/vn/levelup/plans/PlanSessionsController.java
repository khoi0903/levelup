package vn.levelup.plans;

import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;
import vn.levelup.auth.CurrentUserService;

@RestController
public class PlanSessionsController {

    private final PlanSessionService sessions;
    private final CurrentUserService currentUser;

    public PlanSessionsController(PlanSessionService sessions, CurrentUserService currentUser) {
        this.sessions = sessions;
        this.currentUser = currentUser;
    }

    /**
     * Sửa một buổi còn planned trong kế hoạch active: action reschedule (scheduledDate, scheduledTime),
     * quick5 (bản 5 phút) hoặc rest (nghỉ). Trả lại cả kế hoạch tuần sau khi sửa.
     */
    @PatchMapping("/plans/sessions/{id}")
    public PlanView patch(@PathVariable String id, @Valid @RequestBody PlanSessionService.PatchRequest request) {
        return sessions.patch(currentUser.require(), id, request);
    }
}
