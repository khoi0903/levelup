package vn.levelup.engagement.controller;
import jakarta.validation.Valid;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;
import vn.levelup.engagement.dto.ReferralDtos;
import vn.levelup.engagement.service.ReferralService;
import vn.levelup.identity.service.CurrentUserService;
@RestController
@RequestMapping("/referrals")
public class ReferralsController {
    private final CurrentUserService current;
    private final ReferralService referrals;
    public ReferralsController(CurrentUserService current, ReferralService referrals) { this.current = current; this.referrals = referrals; }
    @GetMapping("/me") public ReferralDtos.View me() { return referrals.me(current.require(), ServletUriComponentsBuilder.fromCurrentContextPath().build().toUriString()); }
    @PostMapping("/redeem")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void redeem(@Valid @RequestBody ReferralDtos.Redeem request) {
        try { referrals.redeem(current.require(), request.code()); }
        catch (DuplicateKeyException duplicate) { throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "ALREADY_REDEEMED"); }
    }
}
