package vn.levelup.coach.controller;

import java.io.IOException;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import jakarta.validation.Valid;
import vn.levelup.coach.dto.CoachViews;
import vn.levelup.coach.service.CoachService;
import vn.levelup.identity.model.User;
import vn.levelup.identity.service.CurrentUserService;
import vn.levelup.training.dto.PlanView;

@RestController
public class CoachController {

    private static final Logger log = LoggerFactory.getLogger(CoachController.class);
    /** Coach + AI tối đa ~45 giây (2 lần gọi AI 20 giây); quá thì đóng stream. */
    static final long STREAM_TIMEOUT_MS = 60_000;

    private final ExecutorService streams = Executors.newVirtualThreadPerTaskExecutor();
    private final CoachService coach;
    private final CurrentUserService currentUser;

    public CoachController(CoachService coach, CurrentUserService currentUser) {
        this.coach = coach;
        this.currentUser = currentUser;
    }

    /** Gửi tin cho coach. Hết lượt hôm nay: 429 COACH_LIMIT. Thẻ hành động chỉ là đề xuất, chưa sửa kế hoạch. */
    @PostMapping("/coach/messages")
    public CoachViews.SendResponse send(@Valid @RequestBody CoachViews.SendRequest request) {
        return coach.send(currentUser.require(), request.text());
    }

    /**
     * Như POST /coach/messages nhưng trả Server-Sent Events: "delta" {text} khi AI đang viết, rồi "done" với đúng
     * body của POST /coach/messages (bản đã kiểm tra, đã lưu), hoặc "error" {code}. Hết lượt: error COACH_LIMIT.
     * Người dùng lấy từ token ở luồng request, phần gọi AI chạy ở virtual thread.
     */
    @PostMapping(value = "/coach/messages/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter stream(@Valid @RequestBody CoachViews.SendRequest request) {
        User user = currentUser.require();
        SseEmitter emitter = new SseEmitter(STREAM_TIMEOUT_MS);
        streams.execute(() -> {
            AtomicBoolean clientGone = new AtomicBoolean();
            try {
                CoachViews.SendResponse done = coach.send(user, request.text(), text -> {
                    if (!clientGone.get()) {
                        try {
                            emitter.send(SseEmitter.event().name("delta").data(Map.of("text", text)));
                        } catch (IOException | IllegalStateException e) {
                            clientGone.set(true);           // app đóng kết nối: vẫn lưu tin như bình thường
                        }
                    }
                });
                emitter.send(SseEmitter.event().name("done").data(done, MediaType.APPLICATION_JSON));
                emitter.complete();
            } catch (ResponseStatusException e) {
                sendError(emitter, e.getReason() == null ? "ERROR" : e.getReason());
            } catch (IOException | IllegalStateException e) {
                emitter.completeWithError(e);
            } catch (RuntimeException e) {
                log.warn("Coach stream lỗi: {}", e.toString());
                sendError(emitter, "INTERNAL_ERROR");
            }
        });
        return emitter;
    }

    private static void sendError(SseEmitter emitter, String code) {
        try {
            emitter.send(SseEmitter.event().name("error").data(Map.of("code", code)));
            emitter.complete();
        } catch (IOException | IllegalStateException e) {
            emitter.completeWithError(e);
        }
    }

    /** Lịch sử chat, mới nhất trước. before: thời điểm ISO (lấy từ nextBefore của trang trước). */
    @GetMapping("/coach/messages")
    public CoachViews.HistoryResponse history(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant before,
            @RequestParam(defaultValue = "20") int limit) {
        return coach.history(currentUser.require(), before, limit);
    }

    /** "Dùng buổi này": áp dụng thẻ hành động của tin coach, trả kế hoạch đã cập nhật. */
    @PostMapping("/coach/messages/{messageId}/actions/apply")
    public PlanView apply(@PathVariable String messageId) {
        return coach.apply(currentUser.require(), messageId);
    }
}
