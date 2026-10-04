package vn.levelup.notifications;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;

/**
 * Chọn bộ gửi push: có levelup.fcm.credentials (FIREBASE_CREDENTIALS = đường dẫn file service account,
 * để NGOÀI repo) thì gửi thật qua FCM; không có thì LogPushSender chỉ ghi log (dev, test).
 */
@Configuration
public class PushConfig {

    private static final Logger log = LoggerFactory.getLogger(PushConfig.class);

    @Bean
    PushSender pushSender(@Value("${levelup.fcm.credentials:}") String credentialsPath,
                          @Value("${levelup.firebase.project-id}") String projectId) throws IOException {
        if (credentialsPath == null || credentialsPath.isBlank()) {
            log.info("Push: chỉ ghi log (chưa đặt FIREBASE_CREDENTIALS)");
            return new LogPushSender();
        }
        Path path = Path.of(credentialsPath);
        if (!Files.isReadable(path)) {
            throw new IllegalStateException("FIREBASE_CREDENTIALS không đọc được: " + credentialsPath);
        }
        try (InputStream in = new FileInputStream(path.toFile())) {
            FirebaseOptions options = FirebaseOptions.builder()
                .setCredentials(GoogleCredentials.fromStream(in))
                .setProjectId(projectId)
                .build();
            FirebaseApp app = FirebaseApp.getApps().stream()
                .filter(a -> a.getName().equals("levelup-fcm")).findFirst()
                .orElseGet(() -> FirebaseApp.initializeApp(options, "levelup-fcm"));
            log.info("Push: gửi thật qua FCM (project {})", projectId);
            return new FcmPushSender(app);
        }
    }
}
