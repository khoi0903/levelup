package vn.levelup.engagement.service;

import java.util.Map;
import org.bson.types.ObjectId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.event.TransactionalEventListener;
import vn.levelup.engagement.dto.ReferralCompleted;
import vn.levelup.engagement.notification.NotificationGateway;

@Service
public class ReferralNotifications {
    private static final Logger log = LoggerFactory.getLogger(ReferralNotifications.class);
    private final NotificationGateway notifications;
    public ReferralNotifications(NotificationGateway notifications) { this.notifications = notifications; }
    // The gateway runs without a transaction. Send only after the workout and reward really commit.
    @TransactionalEventListener
    public void completed(ReferralCompleted event) {
        try {
            notifications.send(new ObjectId(event.referrerId()), "referral_completed", "Bạn của bạn đã tập buổi đầu!",
                "Bạn đã mời thành công " + event.successfulCount() + " người bạn. Xem tiến độ nhận Pro trong tab Tôi.",
                "referral:" + event.referralId(), Map.of("route", "/referrals"));
        } catch (RuntimeException e) {
            log.error("[referral] notification failed referral={}", event.referralId(), e);
        }
    }
}
