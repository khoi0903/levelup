package vn.levelup.nutrition.rules;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.Test;

class MealCommentsTest {

    /** Bữa trưa 12h, mục tiêu 2000, sàn 1200; macro cân bằng mặc định. */
    private static MealComments.Input in(String meal, int hour, int kcal, double p, double c, double f,
                                         Integer target, int dayAfter) {
        return new MealComments.Input(meal, hour, kcal, p, c, f, target, dayAfter, 1200);
    }

    @Test
    void vuotMucTieuNgayUuTienCaoNhat() {
        assertEquals("vuot_ngay", MealComments.situation(in("dinner", 22, 900, 20, 100, 40, 2000, 2100)));
    }

    @Test
    void buaToiMaCaNgayDuoiMucSanThiNhacAnDu() {
        assertEquals("an_qua_it", MealComments.situation(in("dinner", 19, 300, 20, 30, 10, 2000, 900)));
        assertEquals("an_qua_it", MealComments.situation(in("snack", 20, 150, 5, 20, 5, null, 500)));
    }

    @Test
    void anKhuyaBuaLon() {
        assertEquals("an_khuya", MealComments.situation(in("snack", 23, 450, 15, 50, 20, 2000, 1700)));
        // Ăn khuya nhẹ thì không tính là ăn khuya
        assertNotEquals("an_khuya", MealComments.situation(in("snack", 23, 120, 2, 25, 2, 2000, 1500)));
    }

    @Test
    void ganChamMucTieu() {
        assertEquals("gan_du", MealComments.situation(in("dinner", 19, 600, 35, 60, 20, 2000, 1900)));
    }

    @Test
    void buaNangChuaVuot() {
        assertEquals("bua_nang", MealComments.situation(in("lunch", 12, 900, 40, 100, 30, 2000, 1300)));
    }

    @Test
    void phanLoaiTheoMacro() {
        // Béo: 30 g chất béo = 270 / 470 kcal
        assertEquals("nhieu_beo", MealComments.situation(in("lunch", 12, 470, 15, 35, 30, 2000, 900)));
        // Tinh bột: 100 g = 400 / 500 kcal
        assertEquals("nhieu_tinh_bot", MealComments.situation(in("lunch", 12, 500, 15, 100, 5, 2000, 900)));
        // Đạm: 40 g = 160 / 400 kcal
        assertEquals("nhieu_dam", MealComments.situation(in("lunch", 12, 400, 40, 40, 8, 2000, 900)));
    }

    @Test
    void loaiBuaVaBuaNhe() {
        assertEquals("an_vat", MealComments.situation(in("snack", 15, 180, 3, 30, 5, 2000, 900)));
        assertEquals("bua_nhe", MealComments.situation(in("lunch", 12, 200, 10, 20, 8, 2000, 700)));
        assertEquals("bua_sang", MealComments.situation(in("breakfast", 7, 400, 15, 55, 12, 2000, 400)));
        assertEquals("can_bang", MealComments.situation(in("lunch", 12, 500, 25, 60, 15, 2000, 900)));
    }

    @Test
    void chuaCoMucTieuVanCoTinhHuong() {
        assertEquals("bua_sang", MealComments.situation(in("breakfast", 7, 400, 15, 55, 12, null, 400)));
    }

    @Test
    void pickKhongLapCauDaDungGanDay() {
        List<Integer> recent = List.of(3, 0, 7, 1);
        for (long seed = 0; seed < 200; seed++) {
            int i = MealComments.pick(10, recent, seed);
            assertTrue(i >= 0 && i < 10);
            assertTrue(!recent.contains(i), "chọn lại câu vừa dùng: " + i);
        }
    }

    @Test
    void pickDungHetThiChiTranhLanGanNhat() {
        List<Integer> recent = List.of(2, 0, 1);
        Set<Integer> seen = new HashSet<>();
        for (long seed = 0; seed < 50; seed++) {
            int i = MealComments.pick(3, recent, seed);
            assertNotEquals(2, i);
            seen.add(i);
        }
        assertEquals(Set.of(0, 1), seen);
    }

    @Test
    void pickTraiDeuCacCauConLai() {
        Set<Integer> seen = new HashSet<>();
        for (long seed = 0; seed < 500; seed++) {
            seen.add(MealComments.pick(12, List.of(), seed));
        }
        assertEquals(12, seen.size());
    }

    @Test
    void fillDienChoTrongVaBoChoThieu() {
        assertEquals("Phở bò 520 kcal, còn 900 kcal.",
            MealComments.fill("{mon} {kcal} kcal, còn {con_lai} kcal.",
                Map.of("mon", "Phở bò", "kcal", "520", "con_lai", "900")));
        assertEquals("Ngon đấy.", MealComments.fill("Ngon {vuot} đấy.", Map.of()));
    }
}
