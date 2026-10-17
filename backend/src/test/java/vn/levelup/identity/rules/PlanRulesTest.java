package vn.levelup.identity.rules;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

import org.junit.jupiter.api.Test;


class PlanRulesTest {

    private static final Instant NOW = Instant.parse("2026-10-17T00:00:00Z");

    @Test
    void later_expiry_wins_and_expired_paid_keeps_gift_days() {
        Instant gift = NOW.plus(30, ChronoUnit.DAYS);
        var e = PlanRules.effective(gift, "referral", NOW, NOW);
        assertEquals("pro", e.tier());
        assertEquals("referral", e.source());
        assertEquals(gift, e.expiresAt());

        var paid = PlanRules.effective(gift, "referral", NOW.plus(60, ChronoUnit.DAYS), NOW);
        assertEquals(PlanRules.PAID_SOURCE, paid.source());

        assertEquals("free", PlanRules.effective(null, null, NOW, NOW).tier());
        assertEquals("free", PlanRules.effective(null, null, null, NOW).tier());
    }

    @Test
    void legacy_plan_without_split_fields() {
        Instant exp = NOW.plus(5, ChronoUnit.DAYS);
        assertEquals(exp, PlanRules.giftExpiry(null, "referral", exp));
        assertNull(PlanRules.giftExpiry(null, "revenuecat", exp));
        assertEquals(exp, PlanRules.paidExpiry(null, "revenuecat", exp));
        assertNull(PlanRules.paidExpiry(null, "manual", exp));
    }
}
