package vn.levelup.common;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;

import org.junit.jupiter.api.Test;

class LocalDatesTest {

    @Test
    void tapLuc23h30GioVietNamVanTinhLaHomNay() {
        // 16:30 UTC = 23:30 giờ Việt Nam ngày 20/11
        Clock clock = Clock.fixed(Instant.parse("2026-11-20T16:30:00Z"), ZoneOffset.UTC);
        assertEquals(LocalDate.parse("2026-11-20"), LocalDates.today("Asia/Ho_Chi_Minh", clock));
    }

    @Test
    void quaNuaDemGioVietNamLaNgayMoi() {
        // 17:30 UTC = 00:30 giờ Việt Nam ngày 21/11
        Clock clock = Clock.fixed(Instant.parse("2026-11-20T17:30:00Z"), ZoneOffset.UTC);
        assertEquals(LocalDate.parse("2026-11-21"), LocalDates.today("Asia/Ho_Chi_Minh", clock));
    }

    @Test
    void muiGioSaiThiDungGioVietNam() {
        Clock clock = Clock.fixed(Instant.parse("2026-11-20T17:30:00Z"), ZoneOffset.UTC);
        assertEquals(LocalDate.parse("2026-11-21"), LocalDates.today("Sao/Hoa", clock));
    }

    @Test
    void tuanBatDauThuHai() {
        assertEquals(LocalDate.parse("2026-11-16"), LocalDates.weekStart(LocalDate.parse("2026-11-22"))); // Chủ nhật
        assertEquals(LocalDate.parse("2026-11-16"), LocalDates.weekStart(LocalDate.parse("2026-11-16"))); // Thứ Hai
    }
}
