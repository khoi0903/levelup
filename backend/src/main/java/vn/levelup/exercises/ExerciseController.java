package vn.levelup.exercises;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import vn.levelup.auth.CurrentUserService;
import vn.levelup.users.User;

@RestController
public class ExerciseController {

    private final ExerciseRepository exercises;
    private final CurrentUserService currentUser;

    public ExerciseController(ExerciseRepository exercises, CurrentUserService currentUser) {
        this.exercises = exercises;
        this.currentUser = currentUser;
    }

    /** Thư viện bài tập đã lọc theo dụng cụ và chấn thương của người dùng, kèm cấu hình camera đang bật. */
    @GetMapping("/exercises")
    public List<ExerciseResponse> list() {
        User user = currentUser.require();
        User.Profile p = user.profile();
        String location = p == null ? null : p.location();
        Set<String> equipment = p == null || p.equipment() == null ? Set.of() : Set.copyOf(p.equipment());
        return ExerciseFilter.forUser(exercises.findByIsActiveTrue(), location, equipment, activeInjuries(user))
            .stream().map(ExerciseResponse::from).toList();
    }

    static Set<String> activeInjuries(User user) {
        if (user.injuries() == null) {
            return Set.of();
        }
        return user.injuries().stream()
            .filter(i -> !Boolean.FALSE.equals(i.active()))
            .map(User.Injury::bodyArea)
            .collect(Collectors.toSet());
    }

    public record ExerciseResponse(
        String id, String slug, String nameVi, String instructions, List<String> cues,
        String videoUrl, String thumbnailUrl, String primaryMuscle, Integer difficulty,
        String tracking, List<String> equipment, Camera camera
    ) {
        /** Chỉ gửi cấu hình camera của phiên bản đang bật; null nếu bài không hỗ trợ đếm bằng camera. */
        public record Camera(Integer version, String cameraPosition, Map<String, Object> config) {}

        static ExerciseResponse from(Exercise e) {
            Camera camera = null;
            Exercise.Cv cv = e.cv();
            if (cv != null && Boolean.TRUE.equals(cv.supported()) && cv.configs() != null) {
                camera = cv.configs().stream()
                    .filter(c -> c.version() != null && c.version().equals(cv.activeVersion()))
                    .findFirst()
                    .map(c -> new Camera(c.version(), c.cameraPosition(), c.config()))
                    .orElse(null);
            }
            return new ExerciseResponse(e.id(), e.slug(), e.nameVi(), e.instructions(), e.cues(),
                e.videoUrl(), e.thumbnailUrl(), e.primaryMuscle(), e.difficulty(), e.tracking(),
                e.equipmentOrEmpty(), camera);
        }
    }
}
