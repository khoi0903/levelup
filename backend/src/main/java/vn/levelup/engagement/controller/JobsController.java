package vn.levelup.engagement.controller;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;
import vn.levelup.engagement.service.JobService;

/**
 * Cloud Scheduler gọi mỗi 15 phút. Cần header X-Job-Secret bằng biến môi trường JOB_SECRET
 * (levelup.jobs.secret; chưa cấu hình thì luôn từ chối).
 * Endpoint vẫn nằm sau SecurityConfig (cần Bearer token): khi phát triển dùng token dev bất kỳ.
 * TODO: trên server thật mở /jobs/tick trong SecurityConfig và kiểm tra OIDC token của Cloud Scheduler.
 */
@RestController
public class JobsController {

    private final JobService jobs;
    private final byte[] secret;

    public JobsController(JobService jobs, @Value("${levelup.jobs.secret:}") String secret) {
        this.jobs = jobs;
        this.secret = secret.getBytes(StandardCharsets.UTF_8);
    }

    @PostMapping("/jobs/tick")
    public JobService.TickResult tick(@RequestHeader(name = "X-Job-Secret", required = false) String header) {
        if (secret.length == 0 || header == null
                || !MessageDigest.isEqual(secret, header.getBytes(StandardCharsets.UTF_8))) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "FORBIDDEN");
        }
        return jobs.tick();
    }
}
