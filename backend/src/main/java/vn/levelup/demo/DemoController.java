package vn.levelup.demo;

import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;
import vn.levelup.identity.model.User;
import vn.levelup.identity.service.CurrentUserService;


/**
 * POST /demo/{action}: skip-two | close-week | review | seed | checkin | push-test.
 * Chỉ chạy khi levelup.demo.enabled=true và uid nằm trong levelup.demo.uids ("demo*" = tiền tố);
 * ngoài ra trả 404 như endpoint không tồn tại.
 */
@RestController
public class DemoController {

    private final DemoService demo;
    private final CurrentUserService currentUser;
    private final DemoAccess access;

    public DemoController(DemoService demo, CurrentUserService currentUser, DemoAccess access) {
        this.demo = demo;
        this.currentUser = currentUser;
        this.access = access;
    }

    public record DemoResult(String action, Map<String, Object> result) {}

    @PostMapping("/demo/{action}")
    public DemoResult run(@PathVariable String action) {
        if (!access.allowedFor(currentUser.uid())) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "NOT_FOUND");
        }
        User user = currentUser.require();
        Map<String, Object> result = switch (action) {
            case "skip-two" -> demo.skipTwo(user);
            case "close-week" -> demo.closeWeek(user);
            case "review" -> demo.review(user);
            case "seed" -> demo.seed(user);
            case "checkin" -> demo.checkin(user);
            case "push-test" -> demo.pushTest(user);
            default -> throw new ResponseStatusException(HttpStatus.NOT_FOUND, "UNKNOWN_ACTION");
        };
        return new DemoResult(action, result);
    }
}
