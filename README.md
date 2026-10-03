# LevelUp

App fitness có AI coach cho người Việt. Quy ước làm việc: xem [AGENTS.md](AGENTS.md).

## Cấu trúc
- `app/` – Flutter
- `backend/` – Java 21 + Spring Boot
- `mongo/` – MongoDB chạy bằng Docker (cổng 27018)
- `docs/` – flow, kế hoạch, database, luồng backend, wireframe

## Chạy trên máy
1. Bật Docker Desktop, rồi `cd mongo && docker compose up -d`
2. Chép `.env.example` thành `.env`, điền key
3. Backend (chế độ dev, cổng 8081): `cd backend && ./mvnw spring-boot:run "-Dspring-boot.run.profiles=dev"`
   rồi mở http://localhost:8081/swagger-ui.html, bấm Authorize, nhập `dev-<tên bất kỳ>`
4. App: `cd app && flutter run`
