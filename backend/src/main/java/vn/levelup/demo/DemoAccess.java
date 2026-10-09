package vn.levelup.demo;

import java.util.Arrays;
import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Ai được dùng nút giả lập: levelup.demo.enabled=true và uid nằm trong levelup.demo.uids ("demo*" = tiền tố).
 * Dùng chung cho POST /demo/{action} và cờ /me.demoEnabled (app chỉ mở màn Demo khi cờ này bật).
 */
@Component
public class DemoAccess {

    private final boolean enabled;
    private final List<String> uids;

    public DemoAccess(@Value("${levelup.demo.enabled:false}") boolean enabled,
                      @Value("${levelup.demo.uids:}") String uids) {
        this.enabled = enabled;
        this.uids = Arrays.stream(uids.split(",")).map(String::trim).filter(s -> !s.isEmpty()).toList();
    }

    public boolean allowedFor(String uid) {
        return enabled && uid != null && allowed(uids, uid);
    }

    /** "abc" khớp đúng uid, "demo*" khớp mọi uid bắt đầu bằng "demo". */
    static boolean allowed(List<String> patterns, String uid) {
        return patterns.stream().anyMatch(p -> p.endsWith("*") ? uid.startsWith(p.substring(0, p.length() - 1))
            : uid.equals(p));
    }
}
