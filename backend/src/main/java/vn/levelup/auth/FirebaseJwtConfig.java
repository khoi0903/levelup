package vn.levelup.auth;

import java.time.Instant;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.jwt.BadJwtException;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtClaimNames;
import org.springframework.security.oauth2.jwt.JwtClaimValidator;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;

/**
 * Kiểm tra Firebase ID token (header "Authorization: Bearer ...").
 * Không cần Firebase Admin SDK: token là JWT, kiểm tra chữ ký bằng khóa công khai của Google,
 * rồi kiểm tra issuer và audience theo project Firebase.
 */
@Configuration
public class FirebaseJwtConfig {

    private static final Logger log = LoggerFactory.getLogger(FirebaseJwtConfig.class);
    private static final String FIREBASE_JWKS =
        "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

    @Bean
    @ConditionalOnProperty(name = "levelup.auth.dev-tokens", havingValue = "false", matchIfMissing = true)
    JwtDecoder firebaseJwtDecoder(@Value("${levelup.firebase.project-id}") String projectId) {
        NimbusJwtDecoder decoder = NimbusJwtDecoder.withJwkSetUri(FIREBASE_JWKS).build();
        OAuth2TokenValidator<Jwt> issuer =
            JwtValidators.createDefaultWithIssuer("https://securetoken.google.com/" + projectId);
        OAuth2TokenValidator<Jwt> audience = new JwtClaimValidator<List<String>>(
            JwtClaimNames.AUD, aud -> aud != null && aud.contains(projectId));
        decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(issuer, audience));
        return decoder;
    }

    /** Chỉ dùng khi phát triển (profile dev): token dạng "dev-<uid>", không kiểm tra chữ ký. */
    @Bean
    @ConditionalOnProperty(name = "levelup.auth.dev-tokens", havingValue = "true")
    JwtDecoder devJwtDecoder() {
        log.warn("ĐANG BẬT TOKEN DEV: chỉ dùng trên máy phát triển, không bao giờ bật trên server thật");
        return token -> {
            if (token == null || !token.startsWith("dev-") || token.length() <= 4) {
                throw new BadJwtException("Token dev phải có dạng dev-<uid>");
            }
            String uid = token.substring(4);
            Instant now = Instant.now();
            return Jwt.withTokenValue(token)
                .header("alg", "none")
                .subject(uid)
                .claim("user_id", uid)
                .issuedAt(now)
                .expiresAt(now.plusSeconds(3600))
                .build();
        };
    }
}
