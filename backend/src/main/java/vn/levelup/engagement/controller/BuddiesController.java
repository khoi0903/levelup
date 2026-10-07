package vn.levelup.engagement.controller;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;
import vn.levelup.engagement.dto.ActionRequest;
import vn.levelup.engagement.dto.ActionResponse;
import vn.levelup.engagement.dto.BuddyTodayResponse;
import vn.levelup.engagement.dto.InviteResponse;
import vn.levelup.engagement.dto.JoinRequest;
import vn.levelup.engagement.dto.PairResponse;
import vn.levelup.engagement.service.BuddyService;
import vn.levelup.identity.service.CurrentUserService;

@RestController
public class BuddiesController {

    private final BuddyService buddies;
    private final CurrentUserService currentUser;

    public BuddiesController(BuddyService buddies, CurrentUserService currentUser) {
        this.buddies = buddies;
        this.currentUser = currentUser;
    }

    /** Tạo mã mời 6 ký tự (hạn 7 ngày); đã có mã còn hạn thì trả lại mã đó. 409 ALREADY_PAIRED. */
    @PostMapping("/buddies/invites")
    public InviteResponse invite() {
        return buddies.invite(currentUser.require());
    }

    /**
     * Nhập mã để ghép cặp. 404 INVITE_NOT_FOUND, 410 INVITE_EXPIRED / INVITE_USED,
     * 400 OWN_INVITE, 409 ALREADY_PAIRED.
     */
    @PostMapping("/buddies/join")
    public PairResponse join(@Valid @RequestBody JoinRequest request) {
        return buddies.join(currentUser.require(), request.code());
    }

    /** Trạng thái hôm nay của buddy, chỉ những gì buddy cho phép chia sẻ. 404 NO_BUDDY. */
    @GetMapping("/buddies/today")
    public BuddyTodayResponse today() {
        return buddies.today(currentUser.require());
    }

    /**
     * Nhắc (nudge) hoặc cổ vũ (cheer), mỗi loại 1 lần/ngày. 404 PAIR_NOT_FOUND,
     * 409 ALREADY_NUDGED / ALREADY_CHEERED / BUDDY_DONE (buddy đã tập hôm nay thì không nhắc).
     */
    @PostMapping("/buddies/{pairId}/actions")
    public ActionResponse act(@PathVariable String pairId, @Valid @RequestBody ActionRequest request) {
        return buddies.act(currentUser.require(), pairId, request);
    }

    /** Rời cặp hiện tại. 404 NO_BUDDY. */
    @DeleteMapping("/buddies/pair")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void leave() {
        buddies.leave(currentUser.require());
    }
}
