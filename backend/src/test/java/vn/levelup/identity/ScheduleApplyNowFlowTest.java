package vn.levelup.identity;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;

import com.jayway.jsonpath.DocumentContext;
import vn.levelup.FlowTestBase;
import vn.levelup.shared.util.LocalDates;

/** Đổi lịch rảnh áp dụng ngay cho phần còn lại của tuần này. */
@SpringBootTest
@ActiveProfiles("dev")
class ScheduleApplyNowFlowTest extends FlowTestBase {

    private DocumentContext setDays(int... weekdays) throws Exception {
        StringBuilder b = new StringBuilder("{\"availability\":[");
        for (int i = 0; i < weekdays.length; i++) {
            b.append(i == 0 ? "" : ",").append("{\"weekday\":").append(weekdays[i]).append(",\"slot\":\"evening\"}");
        }
        call(patch("/me").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content(b.append("]}").toString()), 200);
        return call(get("/plans/current").header("Authorization", token), 200);
    }

    @Test
    void adding_and_removing_today_updates_this_week() throws Exception {
        onboard();
        LocalDate today = LocalDate.now(LocalDates.DEFAULT_ZONE);
        String day = today.toString();
        int todayWd = today.getDayOfWeek().getValue();
        int otherWd = todayWd == 1 ? 2 : todayWd - 1;          // một ngày khác hôm nay

        DocumentContext without = setDays(otherWd);
        List<String> todayPlanned = without.read("$.sessions[?(@.scheduledDate == '" + day
            + "' && @.status == 'planned')].id");
        assertTrue(todayPlanned.isEmpty(), "bỏ hôm nay khỏi lịch: không còn buổi planned hôm nay");

        DocumentContext with = setDays(otherWd, todayWd);
        List<Map<String, Object>> todays = with.read("$.sessions[?(@.scheduledDate == '" + day + "')]");
        assertEquals(1, todays.size(), "thêm hôm nay vào lịch: có buổi hôm nay");
        assertEquals("planned", todays.getFirst().get("status"));
        assertEquals("18:30", todays.getFirst().get("scheduledTime"));
        assertFalse(((List<?>) todays.getFirst().get("items")).isEmpty(), "buổi mới có bài");
        assertEquals(with.<Integer>read("$.sessions.length()"), with.<Integer>read("$.targetSessions"),
            "chỉ tiêu = số buổi tuần này");

        DocumentContext again = setDays(otherWd, todayWd);       // gửi lại y hệt: không tạo trùng
        assertEquals(1, again.<List<?>>read("$.sessions[?(@.scheduledDate == '" + day + "')]").size());

        // đổi sang giờ riêng cho hôm nay: buổi planned hôm nay đổi giờ theo, cài đặt trả lại giờ riêng
        call(patch("/me").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content("{\"availability\":[{\"weekday\":" + otherWd + ",\"slot\":\"evening\"},{\"weekday\":"
                + todayWd + ",\"slot\":\"evening\",\"time\":\"21:15\"}]}"), 200);
        DocumentContext retimed = call(get("/plans/current").header("Authorization", token), 200);
        assertEquals("21:15", retimed.<List<String>>read("$.sessions[?(@.scheduledDate == '" + day
            + "')].scheduledTime").getFirst());
        // giờ sai định dạng bị từ chối
        call(patch("/me").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content("{\"availability\":[{\"weekday\":1,\"slot\":\"evening\",\"time\":\"7h\"}]}"), 400);
    }
}
