package vn.levelup.engagement.controller;

import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import vn.levelup.engagement.service.PainFollowUpService;
import vn.levelup.identity.service.CurrentUserService;

@RestController
public class PainFollowUpsController {

    private final PainFollowUpService painFollowUps;
    private final CurrentUserService currentUser;

    public PainFollowUpsController(PainFollowUpService painFollowUps, CurrentUserService currentUser) {
        this.painFollowUps = painFollowUps;
        this.currentUser = currentUser;
    }

    public record AnswerRequest(@NotNull @Pattern(regexp = "gone|better|same|worse") String answer) {}

    /**
     * Trả lời hỏi thăm vùng đau (thẻ ở Trang chủ, danh sách lấy từ GET /me.painFollowUps).
     * gone: hết đau, tập bình thường. better/same: vẫn tránh vùng này. worse hoặc vẫn đau sau 3 ngày: chấn thương.
     */
    @PostMapping("/pain-followups/{bodyArea}")
    public PainFollowUpService.AnswerResponse answer(
            @PathVariable @Pattern(regexp = "lower_back|knee|shoulder|neck|wrist|ankle|hip|other") String bodyArea,
            @Valid @RequestBody AnswerRequest request) {
        return painFollowUps.answer(currentUser.require(), bodyArea, request.answer());
    }
}
