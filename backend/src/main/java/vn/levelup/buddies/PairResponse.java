package vn.levelup.buddies;

import java.time.Instant;

/** Cặp vừa ghép. buddyName là tên hiển thị của người còn lại. */
public record PairResponse(String pairId, String buddyName, Instant since) {}
