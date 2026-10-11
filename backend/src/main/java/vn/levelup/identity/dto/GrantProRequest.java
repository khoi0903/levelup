package vn.levelup.identity.dto;
import jakarta.validation.constraints.*;
public record GrantProRequest(@NotBlank @Email String email, @Positive @Max(36500) int days) {}
