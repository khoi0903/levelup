package vn.levelup.motivation;

import java.util.List;

import org.bson.types.ObjectId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Component;

/**
 * Gọi mọi bean {@link WeekClosedListener} (có thể chưa có bean nào). Lỗi của một listener chỉ ghi log,
 * không làm hỏng việc chốt tuần hay các listener khác.
 */
@Component
public class WeekCloseListeners {

    private static final Logger log = LoggerFactory.getLogger(WeekCloseListeners.class);

    private final ObjectProvider<WeekClosedListener> listeners;

    public WeekCloseListeners(ObjectProvider<WeekClosedListener> listeners) {
        this.listeners = listeners;
    }

    /** @return số listener chạy xong không lỗi */
    public int weekClosed(ObjectId userId, String weekStart) {
        int ok = 0;
        List<WeekClosedListener> all = listeners.orderedStream().toList();
        for (WeekClosedListener listener : all) {
            try {
                listener.onWeekClosed(userId, weekStart);
                ok++;
            } catch (RuntimeException e) {
                log.warn("[week-close] listener {} lỗi user={} week={}: {}", listener.getClass().getSimpleName(),
                    userId, weekStart, e.getMessage(), e);
            }
        }
        return ok;
    }
}
