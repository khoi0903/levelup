package vn.levelup.identity.service;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.time.*;
import org.junit.jupiter.api.Test;
import vn.levelup.identity.dto.ProductConfig;
import vn.levelup.identity.model.User;
class PlanAccessTest {
    @Test void serverExpiryBoundaryAndLegacyLimits() {
        Instant now = Instant.parse("2026-10-11T10:00:00Z");
        ProductConfigService configs = mock(ProductConfigService.class);
        when(configs.get()).thenReturn(ProductConfig.defaults());
        PlanAccess access = new PlanAccess(configs, Clock.fixed(now, ZoneOffset.UTC), 30, 10);
        User pro = user(new User.Plan("pro", "manual", now.plusSeconds(1), now));
        assertTrue(access.isPro(pro, now));
        assertFalse(access.isPro(pro, now.plusSeconds(1)));
        assertFalse(access.isPro(user(null), now));
        assertEquals(30, access.coachLimit(pro)); assertEquals(10, access.photoLimit(pro));
        when(configs.get()).thenReturn(new ProductConfig(true, false, 10, 100, 3, 30, 7,
            ProductConfig.defaults().referralMilestones(), 49000, 399000, 7, 1, "admin", now));
        assertEquals(100, access.coachLimit(pro)); assertEquals(30, access.photoLimit(pro));
        assertEquals(10, access.coachLimit(user(null))); assertEquals(3, access.photoLimit(user(null)));
    }
    private User user(User.Plan plan) {
        return new User("012345678901234567890123", "uid", null, "U", "Asia/Ho_Chi_Minh", "vi",
            null, null, null, null, null, null, null, plan, null);
    }
}
