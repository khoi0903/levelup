package vn.levelup.identity.controller;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import vn.levelup.identity.dto.BillingWebhook;
import vn.levelup.identity.service.RevenueCatService;
import jakarta.validation.Valid;

@RestController
public class BillingController {
    private final RevenueCatService billing;
    private final String secret;
    public BillingController(RevenueCatService billing, @Value("${REVENUECAT_WEBHOOK_SECRET:}") String secret) {
        this.billing = billing; this.secret = secret;
    }
    @ModelAttribute
    public void authorize(@RequestHeader(value = "Authorization", required = false) String auth) {
        if (secret.isBlank() || auth == null || !MessageDigest.isEqual(secret.getBytes(StandardCharsets.UTF_8),
                auth.getBytes(StandardCharsets.UTF_8)))
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "INVALID_WEBHOOK_SECRET");
    }
    @PostMapping("/billing/revenuecat/webhook")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void webhook(@Valid @RequestBody BillingWebhook body) {
        billing.handle(body.event());
    }
}
