package vn.levelup.shared.config;

import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

/**
 * Mọi endpoint đều cần token, trừ health check, tài liệu API và POST /jobs/tick (dùng X-Job-Secret).
 * Token được kiểm tra bởi JwtDecoder trong {@link vn.levelup.identity.config.FirebaseJwtConfig}.
 * CORS chỉ mở cho các origin trong levelup.cors.allowed-origin-patterns (profile dev: localhost, cho Flutter web).
 */
@Configuration
public class SecurityConfig {

    @Bean
    @org.springframework.core.annotation.Order(0)
    SecurityFilterChain billingSecurity(HttpSecurity http) throws Exception {
        // RevenueCat's Authorization is its configured secret, not a Firebase JWT.
        return http.securityMatcher("/billing/revenuecat/webhook")
            .csrf(csrf -> csrf.disable())
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(a -> a.anyRequest().permitAll()).build();
    }

    @Bean
    SecurityFilterChain apiSecurity(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .cors(Customizer.withDefaults())
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers(
                    "/actuator/health/**", "/actuator/info",
                    "/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html"
                ).permitAll()
                // Cloud Scheduler / cron-job.org không có Firebase token: JobsController tự kiểm tra
                // header X-Job-Secret (so sánh hằng thời gian; JOB_SECRET trống thì luôn 403)
                .requestMatchers(HttpMethod.POST, "/jobs/tick").permitAll()
                // Trang tĩnh cho Google Play: chính sách quyền riêng tư, hướng dẫn xoá tài khoản
                .requestMatchers(HttpMethod.GET, "/privacy.html", "/delete-account.html", "/referral.html").permitAll()
                .anyRequest().authenticated())
            .oauth2ResourceServer(o -> o.jwt(Customizer.withDefaults()));
        return http.build();
    }

    @Bean
    CorsConfigurationSource corsConfigurationSource(
            @Value("${levelup.cors.allowed-origin-patterns:}") List<String> originPatterns) {
        CorsConfiguration cors = new CorsConfiguration();
        cors.setAllowedOriginPatterns(originPatterns);
        cors.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        cors.setAllowedHeaders(List.of("Authorization", "Content-Type", "Accept"));
        cors.setMaxAge(3600L);
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", cors);
        return source;
    }
}
