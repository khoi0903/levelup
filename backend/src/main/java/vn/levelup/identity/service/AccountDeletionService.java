package vn.levelup.identity.service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.bson.types.ObjectId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.google.firebase.FirebaseApp;
import com.google.firebase.auth.AuthErrorCode;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;

import vn.levelup.identity.model.User;

/**
 * DELETE /me: xoá vĩnh viễn tài khoản (yêu cầu của Google Play). Xoá mọi dữ liệu của người dùng trong MongoDB
 * (một transaction), rồi xoá tài khoản đăng nhập Firebase. Dữ liệu dùng chung (bài tập, món ăn, huy hiệu) giữ nguyên.
 */
@Service
public class AccountDeletionService {

    private static final Logger log = LoggerFactory.getLogger(AccountDeletionService.class);

    /** Collection có trường userId của chủ dữ liệu. Thêm collection mới chứa dữ liệu người dùng thì thêm vào đây. */
    static final List<String> BY_USER_ID = List.of(
        "training_plans", "workout_logs", "daily_stats", "meal_logs", "food_recognitions", "coach_messages",
        "body_measurements", "personal_records", "progress_photos", "skip_reports", "weekly_reviews",
        "weekly_streaks", "notifications");

    /** Tên FirebaseApp do PushConfig tạo khi có FIREBASE_CREDENTIALS. */
    static final String FIREBASE_APP = "levelup-fcm";

    private final MongoTemplate mongo;

    public AccountDeletionService(MongoTemplate mongo) {
        this.mongo = mongo;
    }

    /** Số tài liệu đã xoá theo collection (để log và test). */
    @Transactional
    public Map<String, Long> deleteData(User user) {
        ObjectId userId = new ObjectId(user.id());
        Map<String, Long> deleted = new LinkedHashMap<>();
        for (String c : BY_USER_ID) {
            deleted.put(c, mongo.remove(Query.query(Criteria.where("userId").is(userId)), c).getDeletedCount());
        }
        // Buddy: cặp có người này, lời nhắc/cổ vũ gửi hoặc nhận, mã mời đã tạo
        deleted.put("buddy_pairs",
            mongo.remove(Query.query(Criteria.where("members").is(userId)), "buddy_pairs").getDeletedCount());
        deleted.put("buddy_actions", mongo.remove(Query.query(new Criteria().orOperator(
            Criteria.where("fromUser").is(userId), Criteria.where("toUser").is(userId))), "buddy_actions")
            .getDeletedCount());
        deleted.put("buddy_invites", mongo.remove(Query.query(new Criteria().orOperator(
            Criteria.where("inviterId").is(userId), Criteria.where("acceptedBy").is(userId))), "buddy_invites")
            .getDeletedCount());
        deleted.put("users", mongo.remove(Query.query(Criteria.where("_id").is(userId)), "users").getDeletedCount());
        return deleted;
    }

    /**
     * events là collection time-series (userId nằm trong meta): MongoDB không cho xoá nhiều tài liệu
     * time-series trong transaction nên xoá riêng, sau deleteData.
     */
    public long deleteEvents(User user) {
        return mongo.remove(Query.query(Criteria.where("meta.userId").is(new ObjectId(user.id()))), "events")
            .getDeletedCount();
    }

    /** Xoá tài khoản Firebase; chưa cấu hình Firebase (máy dev) hoặc đã xoá rồi thì bỏ qua. */
    public void deleteLogin(String authUid) {
        if (authUid == null || authUid.startsWith("dev-")) {
            return;
        }
        FirebaseApp app = FirebaseApp.getApps().stream().filter(a -> a.getName().equals(FIREBASE_APP))
            .findFirst().orElse(null);
        if (app == null) {
            log.warn("[delete-account] chưa cấu hình Firebase, không xoá tài khoản đăng nhập uid={}", authUid);
            return;
        }
        try {
            FirebaseAuth.getInstance(app).deleteUser(authUid);
        } catch (FirebaseAuthException e) {
            if (e.getAuthErrorCode() != AuthErrorCode.USER_NOT_FOUND) {
                // Dữ liệu đã xoá; tài khoản đăng nhập còn lại thì đăng nhập lại chỉ ra màn onboarding trống
                log.error("[delete-account] xoá tài khoản Firebase lỗi uid={}: {}", authUid, e.getMessage());
            }
        }
    }
}
