package vn.levelup.coach.controller;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;
import vn.levelup.coach.dto.VoiceLineDtos;
import vn.levelup.coach.service.VoiceLineService;
import vn.levelup.identity.service.CurrentUserService;

@RestController
public class VoiceLineController {

    private final VoiceLineService voiceLines;
    private final CurrentUserService currentUser;

    public VoiceLineController(VoiceLineService voiceLines, CurrentUserService currentUser) {
        this.voiceLines = voiceLines;
        this.currentUser = currentUser;
    }

    /** Câu coach đọc trong lúc tập: Pro do AI soạn, còn lại câu mẫu. Luôn trả 200 kèm một câu. */
    @PostMapping("/coach/voice-line")
    public VoiceLineDtos.View line(@Valid @RequestBody VoiceLineDtos.Request request) {
        return voiceLines.line(currentUser.require(), request);
    }
}
