package vn.levelup.engagement.controller;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;
import vn.levelup.engagement.service.SkipReportService;
import vn.levelup.identity.service.CurrentUserService;

@RestController
public class SkipReportsController {

    private final SkipReportService skipReports;
    private final CurrentUserService currentUser;

    public SkipReportsController(SkipReportService skipReports, CurrentUserService currentUser) {
        this.skipReports = skipReports;
        this.currentUser = currentUser;
    }

    /** F3: lý do bỏ buổi (busy, tired, pain, bored, forgot, other), trả kế hoạch đã chỉnh và tin coach. */
    @PostMapping("/skip-reports")
    public SkipReportService.SkipReportResponse report(@Valid @RequestBody SkipReportService.SkipReportRequest request) {
        return skipReports.report(currentUser.require(), request);
    }
}
