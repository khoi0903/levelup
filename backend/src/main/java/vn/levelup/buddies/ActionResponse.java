package vn.levelup.buddies;

/** localDate: ngày của người gửi, mỗi loại chỉ gửi được 1 lần trong ngày này. */
public record ActionResponse(String type, String localDate) {}
