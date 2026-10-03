package vn.levelup.demo;

import java.util.Arrays;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import vn.levelup.auth.CurrentUserService;
import vn.levelup.users.User;

/**
 * POST /demo/{action}: skip-two | close-week | review | seed.
 * Chỉ chạy khi levelup.demo.enabled=true và uid nằm trong levelup.demo.uids ("demo*" = tiền tố);
 * ngoài ra trả 404 như endpoint không tồn tại.
 */
@RestController
public class DemoController {

    private final DemoService demo;
    private final CurrentUserService currentUser;
    private final boolean enabled;
    private final List<String> uids;

    public DemoController(DemoService demo, CurrentUserService currentUser,
                          @Value("${levelup.demo.enabled:false}") boolean enabled,
                          @Value("${levelup.demo.uids:}") String uids) {
        this.demo = demo;
        this.currentUser = currentUser;
        this.enabled = enabled;
        this.uids = Arrays.stream(uids.split(",")).map(String::trim).filter(s -> !s.isEmpty()).toList();
    }

    public record DemoResult(String action, Map<String, Object> result) {}

    @PostMapping("/demo/{action}")
    public DemoResult run(@PathVariable String action) {
        if (!enabled || !allowed(uids, currentUser.uid())) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "NOT_FOUND");
        }
        User user = currentUser.require();
        Map<String, Object> result = switch (action) {
            case "skip-two" -> demo.skipTwo(user);
            case "close-week" -> demo.closeWeek(user);
            case "review" -> demo.review(user);
            case "seed" -> demo.seed(user);
            default -> throw new ResponseStatusException(HttpStatus.NOT_FOUND, "UNKNOWN_ACTION");
        };
        return new DemoResult(action, result);
    }

    /** "abc" khớp đúng uid, "demo*" khớp mọi uid bắt đầu bằng "demo". */
    static boolean allowed(List<String> patterns, String uid) {
        return patterns.stream().anyMatch(p -> p.endsWith("*") ? uid.startsWith(p.substring(0, p.length() - 1))
            : uid.equals(p));
    }
}
