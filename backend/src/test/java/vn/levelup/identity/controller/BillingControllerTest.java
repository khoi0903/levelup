package vn.levelup.identity.controller;
import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;
class BillingControllerTest {
    @Test void emptySecretAlwaysRejects() {
        BillingController c = new BillingController(null, "");
        assertEquals(401, assertThrows(ResponseStatusException.class, () -> c.authorize("")).getStatusCode().value());
        assertEquals(401, assertThrows(ResponseStatusException.class, () -> c.authorize(null)).getStatusCode().value());
    }
    @Test void headerMustMatchExactly() {
        BillingController c = new BillingController(null, "Bearer secret");
        assertDoesNotThrow(() -> c.authorize("Bearer secret"));
        assertThrows(ResponseStatusException.class, () -> c.authorize("secret"));
        assertThrows(ResponseStatusException.class, () -> c.authorize("Bearer wrong"));
    }
}
