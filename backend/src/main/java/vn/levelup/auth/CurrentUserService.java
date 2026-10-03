package vn.levelup.auth;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import vn.levelup.users.User;
import vn.levelup.users.UserRepository;

/**
 * Lấy người dùng hiện tại từ token. Mọi service phải dùng userId lấy ở đây,
 * không bao giờ lấy userId từ body hay query của request.
 */
@Service
public class CurrentUserService {

    private final UserRepository users;

    public CurrentUserService(UserRepository users) {
        this.users = users;
    }

    /** uid Firebase của người gọi. */
    public String uid() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof Jwt jwt)) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Cần đăng nhập");
        }
        return jwt.getSubject();
    }

    /** Người dùng đã onboarding; chưa có thì trả 404 ONBOARDING_REQUIRED để app mở màn onboarding. */
    public User require() {
        return users.findByAuthUid(uid())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "ONBOARDING_REQUIRED"));
    }
}
