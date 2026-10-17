package vn.levelup.identity.rules;

import java.time.Instant;

/**
 * Hạn Pro gồm hai nguồn tách riêng: tặng (giới thiệu bạn bè, admin cấp) và trả tiền (RevenueCat).
 * Sự kiện RevenueCat chỉ đổi hạn trả tiền, không xoá ngày được tặng; hạn thực tế là hạn xa hơn.
 */
public final class PlanRules {

    public static final String PAID_SOURCE = "revenuecat";

    private PlanRules() {}

    public record Effective(String tier, String source, Instant expiresAt) {}

    /**
     * @param gift       hạn tặng (null nếu không có)
     * @param giftSource referral | manual
     * @param paid       hạn trả tiền (null nếu chưa mua)
     */
    public static Effective effective(Instant gift, String giftSource, Instant paid, Instant now) {
        boolean paidLater = paid != null && (gift == null || paid.isAfter(gift));
        Instant expires = paidLater ? paid : gift;
        String source = paidLater ? PAID_SOURCE : giftSource;
        return new Effective(expires != null && expires.isAfter(now) ? "pro" : "free", source, expires);
    }

    /** Hạn tặng; dữ liệu cũ chỉ có expiresAt thì coi là tặng khi source không phải RevenueCat. */
    public static Instant giftExpiry(Instant giftExpiresAt, String source, Instant expiresAt) {
        if (giftExpiresAt != null) {
            return giftExpiresAt;
        }
        return source != null && !PAID_SOURCE.equals(source) ? expiresAt : null;
    }

    /** Hạn trả tiền; dữ liệu cũ thì lấy expiresAt khi source là RevenueCat. */
    public static Instant paidExpiry(Instant paidExpiresAt, String source, Instant expiresAt) {
        if (paidExpiresAt != null) {
            return paidExpiresAt;
        }
        return PAID_SOURCE.equals(source) ? expiresAt : null;
    }
}
