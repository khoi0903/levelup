package vn.levelup.shared.config;

import java.time.Clock;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.mongodb.MongoDatabaseFactory;
import org.springframework.data.mongodb.MongoTransactionManager;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;

@Configuration
public class AppConfig {

    /** Đồng hồ dùng chung, để test giả lập được thời gian (chốt ngày, chốt tuần). */
    @Bean
    Clock clock() {
        return Clock.systemUTC();
    }

    /** Transaction cho các thao tác ghi nhiều collection, ví dụ lưu buổi tập. Cần MongoDB replica set. */
    @Bean
    MongoTransactionManager transactionManager(MongoDatabaseFactory factory) {
        return new MongoTransactionManager(factory);
    }

    /** Tài liệu API tại /swagger-ui.html, app Flutter sinh client từ /v3/api-docs. */
    @Bean
    OpenAPI levelUpOpenApi() {
        return new OpenAPI()
            .info(new Info().title("LevelUp API").version("v1"))
            .addSecurityItem(new SecurityRequirement().addList("bearer"))
            .components(new Components().addSecuritySchemes("bearer",
                new SecurityScheme().type(SecurityScheme.Type.HTTP).scheme("bearer").bearerFormat("JWT")));
    }
}
