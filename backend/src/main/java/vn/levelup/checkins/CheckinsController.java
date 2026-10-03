package vn.levelup.checkins;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;
import vn.levelup.auth.CurrentUserService;

@RestController
public class CheckinsController {

    private final CheckinService checkins;
    private final CurrentUserService currentUser;

    public CheckinsController(CheckinService checkins, CurrentUserService currentUser) {
        this.checkins = checkins;
        this.currentUser = currentUser;
    }

    /** Check-in một lần mỗi ngày, điều chỉnh buổi tập đã lên lịch hôm nay. */
    @PostMapping("/checkins")
    public CheckinService.CheckinResponse complete(@Valid @RequestBody CheckinRequest request) {
        return checkins.complete(currentUser.require(), request);
    }
}
