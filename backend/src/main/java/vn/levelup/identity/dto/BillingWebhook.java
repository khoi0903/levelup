package vn.levelup.identity.dto;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
public record BillingWebhook(@NotNull @Valid Event event) {
    public record Event(@NotBlank String id, @NotBlank String type,
        @NotBlank @JsonProperty("app_user_id") String appUserId,
        @JsonProperty("expiration_at_ms") Long expirationAtMs,
        @JsonProperty("event_timestamp_ms") Long eventTimestampMs) {}
}
