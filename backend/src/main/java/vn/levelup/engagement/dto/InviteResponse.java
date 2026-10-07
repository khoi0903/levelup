package vn.levelup.engagement.dto;

import java.time.Instant;

/** Mã mời và tin nhắn soạn sẵn để dán vào Zalo, Messenger. */
public record InviteResponse(String code, Instant expiresAt, String shareText) {}
