# Image chạy backend trên Cloud Run / Render. Build:  docker build -t levelup-backend backend
# Biến môi trường cần khi chạy: xem docs/deploy.md

# 1. Build jar (bỏ qua test: test cần MongoDB, đã chạy trên máy dev trước khi deploy)
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -q -B dependency:go-offline
COPY src ./src
RUN mvn -q -B -DskipTests package && cp target/backend-*.jar app.jar

# 2. Chạy bằng JRE gọn
FROM eclipse-temurin:21-jre
WORKDIR /app
RUN useradd --system --uid 1001 levelup
COPY --from=build /app/app.jar app.jar
USER levelup
# Máy nhỏ (512 MB–1 GB): giới hạn heap theo RAM của container, GC đơn luồng tốn ít bộ nhớ
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=70 -XX:+UseSerialGC -Xss512k -XX:TieredStopAtLevel=1"
# Cloud Run / Render tự đặt PORT; application.yaml đọc server.port=${PORT:8080}
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
