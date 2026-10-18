package vn.levelup.nutrition.controller;

import java.util.List;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import vn.levelup.identity.service.AdminService;
import vn.levelup.nutrition.dto.FoodCandidateDtos;
import vn.levelup.nutrition.service.FoodCandidateService;

/** Admin duyệt món chưa có trong kho. Người không phải Admin nhận 404 như các API /admin khác. */
@RestController
@RequestMapping("/admin/food-candidates")
public class FoodCandidatesController {
    private final AdminService admin;
    private final FoodCandidateService candidates;
    public FoodCandidatesController(AdminService admin, FoodCandidateService candidates) {
        this.admin = admin; this.candidates = candidates;
    }
    @ModelAttribute
    public void authorize() { admin.requireAdmin(); }
    @GetMapping
    public List<FoodCandidateDtos.CandidateView> list(
            @RequestParam(defaultValue = "pending") String status, @RequestParam(defaultValue = "50") int limit) {
        if (!status.matches("pending|approved|rejected"))
            throw new org.springframework.web.server.ResponseStatusException(HttpStatus.BAD_REQUEST, "INVALID_STATUS");
        return candidates.list(status, Math.max(1, Math.min(limit, 200)));
    }
    @PostMapping("/{id}/approve")
    public FoodCandidateDtos.CandidateView approve(@PathVariable String id,
                                                   @Valid @RequestBody FoodCandidateDtos.ApproveRequest request) {
        return candidates.approve(admin.requireAdmin(), id, request);
    }
    @PostMapping("/{id}/reject")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void reject(@PathVariable String id) { candidates.reject(admin.requireAdmin(), id); }
}
