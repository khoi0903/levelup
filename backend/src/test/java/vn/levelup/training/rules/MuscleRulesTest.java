package vn.levelup.training.rules;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;

class MuscleRulesTest {

    @Test
    void anhXaNhomCo() {
        assertEquals("chest", MuscleRules.group("chest"));
        assertEquals("back", MuscleRules.group("back"));
        assertEquals("shoulders", MuscleRules.group("shoulders"));
        assertEquals("arms", MuscleRules.group("arms"));
        assertEquals("abs", MuscleRules.group("core"));
        assertEquals("glutes", MuscleRules.group("glutes"));
        assertEquals("legs", MuscleRules.group("legs"));
        assertNull(MuscleRules.group("cardio"));
        assertNull(MuscleRules.group("mobility"));
        assertNull(MuscleRules.group("abs"));          // không phải giá trị của exercises.primaryMuscle
        assertNull(MuscleRules.group(null));
    }

    @Test
    void demSoHiepLuonDuBayKhoa() {
        Map<String, Integer> empty = MuscleRules.countSets(List.of());
        assertEquals(MuscleRules.GROUPS, new ArrayList<>(empty.keySet()));
        assertEquals(List.of(0, 0, 0, 0, 0, 0, 0), new ArrayList<>(empty.values()));

        // Arrays.asList vì có phần tử null (bài đã bị xoá khỏi kho)
        Map<String, Integer> counts = MuscleRules.countSets(Arrays.asList(
            "core", "core", "legs", "cardio", "mobility", null, "chest", "core", "la"));
        assertEquals(3, counts.get("abs"));
        assertEquals(1, counts.get("legs"));
        assertEquals(1, counts.get("chest"));
        assertEquals(0, counts.get("back"));
        assertEquals(7, counts.size());
    }
}
