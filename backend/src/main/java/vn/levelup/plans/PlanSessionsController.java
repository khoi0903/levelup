package vn.levelup.plans;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;
import vn.levelup.auth.CurrentUserService;

@RestController
public class PlanSessionsController {

    private final PlanSessionService sessions;
    private final ExerciseSwapService swaps;
    private final CurrentUserService currentUser;

    public PlanSessionsController(PlanSessionService sessions, ExerciseSwapService swaps,
                                  CurrentUserService currentUser) {
        this.sessions = sessions;
        this.swaps = swaps;
        this.currentUser = currentUser;
    }

    /** Bài thay thế cho một bài trong buổi còn planned: an toàn với người dùng, chưa có trong buổi (tối đa 6). */
    @GetMapping("/plans/sessions/{id}/alternatives")
    public List<ExerciseSwapService.Alternative> alternatives(@PathVariable String id,
                                                              @RequestParam String exerciseId) {
        return swaps.alternatives(currentUser.require(), id, exerciseId);
    }

    /** Đổi một bài trong buổi; remember=true thì các kế hoạch tuần sau không xếp lại bài cũ. */
    @PostMapping("/plans/sessions/{id}/swap")
    public PlanView swap(@PathVariable String id, @Valid @RequestBody ExerciseSwapService.SwapRequest request) {
        return swaps.swap(currentUser.require(), id, request);
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
