package vn.levelup.exercises;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.util.List;
import java.util.Set;

import org.junit.jupiter.api.Test;

class ExerciseFilterTest {

    private static Exercise ex(String slug, List<String> equipment, List<String> contra) {
        return new Exercise(slug, slug, slug, null, null, null, null, null, "legs", 1, "reps", 4.0,
            equipment, contra, null, true);
    }

    private static final List<Exercise> ALL = List.of(
        ex("squat", List.of(), List.of("knee")),
        ex("goblet-squat", List.of("dumbbell"), List.of("knee", "lower_back")),
        ex("plank", List.of("mat"), List.of("lower_back")),
        ex("pull-up", List.of("pullup_bar"), List.of("shoulder")),
        ex("glute-bridge", List.of("mat"), List.of()));

    private static List<String> slugs(List<Exercise> list) {
        return list.stream().map(Exercise::slug).toList();
    }

    @Test
    void oNhaKhongDungCuChiCoBaiTayKhongVaBaiCanTham() {
        assertEquals(List.of("squat", "plank", "glute-bridge"),
            slugs(ExerciseFilter.forUser(ALL, "home", Set.of(), Set.of())));
    }

    @Test
    void boBaiChongChiDinhVoiVungDangDau() {
        assertEquals(List.of("glute-bridge"),
            slugs(ExerciseFilter.forUser(ALL, "home", Set.of("dumbbell"), Set.of("knee", "lower_back"))));
    }

    @Test
    void phongGymCoiNhuDuDungCu() {
        assertEquals(List.of("squat", "goblet-squat", "plank", "glute-bridge"),
            slugs(ExerciseFilter.forUser(ALL, "gym", Set.of(), Set.of("shoulder"))));
    }
}
