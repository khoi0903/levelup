package vn.levelup.engagement.notification;

import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.ApnsConfig;
import com.google.firebase.messaging.Aps;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.Notification;

/**
 * Gửi push thật qua Firebase Cloud Messaging. Bật khi có file service account (xem PushConfig).
 * Token không còn hợp lệ (gỡ app, token cũ) → TOKEN_EXPIRED để cổng gửi xóa khỏi users.devices.
 */
public class FcmPushSender implements PushSender {

    private static final Logger log = LoggerFactory.getLogger(FcmPushSender.class);

    private final FirebaseMessaging messaging;

    public FcmPushSender(FirebaseApp app) {
        this.messaging = FirebaseMessaging.getInstance(app);
    }

    @Override
    public Outcome send(String token, String platform, String title, String body, Map<String, String> data) {
        Message message = Message.builder()
            .setToken(token)
            .setNotification(Notification.builder().setTitle(title).setBody(body).build())
            .putAllData(data == null ? Map.of() : data)
            // Nhắc tập cần hiện ngay, không gom lô
            .setAndroidConfig(AndroidConfig.builder().setPriority(AndroidConfig.Priority.HIGH).build())
            .setApnsConfig(ApnsConfig.builder().setAps(Aps.builder().setSound("default").build()).build())
            .build();
        try {
            messaging.send(message);
            return Outcome.SENT;
        } catch (FirebaseMessagingException e) {
            Outcome outcome = outcomeFor(e.getMessagingErrorCode());
            Throwable root = e;
            while (root.getCause() != null && root.getCause() != root) {
                root = root.getCause();
            }
            log.warn("[fcm] gửi lỗi platform={} code={} → {}: {} (gốc: {}: {})", platform,
                e.getMessagingErrorCode(), outcome, e.getMessage(), root.getClass().getSimpleName(), root.getMessage());
            return outcome;
        }
    }

    /** Lỗi do token (gỡ app, token sai) thì xóa token; lỗi tạm thời hoặc cấu hình thì chỉ báo FAILED. */
    static Outcome outcomeFor(MessagingErrorCode code) {
        if (code == MessagingErrorCode.UNREGISTERED || code == MessagingErrorCode.INVALID_ARGUMENT
            || code == MessagingErrorCode.SENDER_ID_MISMATCH) {
            return Outcome.TOKEN_EXPIRED;
        }
        return Outcome.FAILED;
    }
}
