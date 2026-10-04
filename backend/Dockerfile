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
# Máy nhỏ (Render free 512 MB): heap một nửa RAM, phần còn lại cho metaspace, code cache, thread;
# GC đơn luồng tốn ít bộ nhớ. Vượt 512 MB là bị kill nên giới hạn cả metaspace và code cache.
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=50 -XX:MaxMetaspaceSize=160m -XX:ReservedCodeCacheSize=48m -XX:+UseSerialGC -Xss512k -XX:TieredStopAtLevel=1"
# Cloud Run / Render tự đặt PORT; application.yaml đọc server.port=${PORT:8080}
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
