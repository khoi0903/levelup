package vn.levelup.motivation;

import org.bson.types.ObjectId;

/**
 * Gọi sau khi chốt tuần của một người dùng (F4), ví dụ để chạy tổng kết tuần (F6).
 * Job chốt tuần nhận mọi bean cài interface này; lỗi của một listener không làm hỏng việc chốt tuần.
 */
public interface WeekClosedListener {

    /** weekStart: Thứ Hai của tuần vừa chốt, dạng "YYYY-MM-DD". Phải chạy lại an toàn nếu bị gọi hai lần. */
    void onWeekClosed(ObjectId userId, String weekStart);
}
