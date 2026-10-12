package vn.levelup.identity.service;

import org.bson.types.ObjectId;

import java.util.Locale;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import vn.levelup.identity.model.User;
import vn.levelup.identity.repository.UserRepository;


/**
 * Lấy người dùng hiện tại từ token. Mọi service phải dùng userId lấy ở đây,
 * không bao giờ lấy userId từ body hay query của request.
 */
@Service
public class CurrentUserService {

    private final UserRepository users;
    private final MongoTemplate mongo;

    public CurrentUserService(UserRepository users, MongoTemplate mongo) {
        this.users = users;
        this.mongo = mongo;
    }

    /** uid Firebase của người gọi. */
    public String uid() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof Jwt jwt)) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Cần đăng nhập");
        }
        return jwt.getSubject();
    }

    /** Email đăng nhập trong token Firebase (chữ thường), không có thì null. */
    public String email() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof Jwt jwt)) {
            return null;
        }
        String email = jwt.getClaimAsString("email");
        return email == null || email.isBlank() ? null : email.trim().toLowerCase(Locale.ROOT);
    }

    /** Người dùng đã onboarding; chưa có thì trả 404 ONBOARDING_REQUIRED để app mở màn onboarding. */
    public User require() {
        User user = users.findByAuthUid(uid())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "ONBOARDING_REQUIRED"));
        String email = email();
        if (email != null && !email.equals(user.email())) {
            // Tài khoản cũ chưa có email, hoặc đổi email ở Firebase: cập nhật (dùng cho tặng Pro theo email)
            mongo.updateFirst(Query.query(Criteria.where("_id").is(new ObjectId(user.id()))),
                Update.update("email", email), "users");
        }
        return user;
    }
}
