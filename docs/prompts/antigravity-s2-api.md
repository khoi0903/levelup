# Prompt cho Antigravity – Sprint 2: nối app với backend

Mở **`D:\levelup-worktrees\app-api`** trong Antigravity (nhánh `feat/app-s2-api`), dán phần dưới.

---

Bạn đang ở nhánh `feat/app-s2-api`, không chuyển nhánh. Đọc `AGENTS.md` trước.
Chỉ sửa trong `app/`, không đụng `app/lib/features/camera_counter/`, `backend/`, `mongo/`.

Mục tiêu: thay các repository giả bằng bản gọi API thật, để đi hết onboarding trên app thì dữ liệu
lưu vào MongoDB và màn Home hiển thị kế hoạch thật.

## Backend đang có (chạy local)
- Chạy: `cd backend; .\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=dev"`
- Địa chỉ: `http://localhost:8081` (máy ảo Android dùng `http://10.0.2.2:8081`)
- Tài liệu API (OpenAPI): `http://localhost:8081/v3/api-docs`, xem trực quan ở `/swagger-ui.html`
- Xác thực khi dev: header `Authorization: Bearer dev-<uid>` (uid bất kỳ, chưa cần Firebase)
- Endpoint:
  - `GET /me` → hồ sơ; **404 với body `{"code":"ONBOARDING_REQUIRED"}`** nếu chưa onboarding
  - `POST /onboarding` → body xem `OnboardingRequest` trong OpenAPI; trả `nutritionTarget` + `plan`
  - `GET /plans/current` → kế hoạch tuần, có sẵn `nameVi` của từng bài
  - `GET /exercises` → thư viện đã lọc theo người dùng
- Lỗi luôn có dạng `{"code": "...", "fields": {"tênTrường": "lý do"}}`

## Việc cần làm
1. Thêm package `dio`. Tạo `lib/core/api/api_client.dart`:
   - base URL đọc từ `--dart-define=API_BASE_URL=...`, mặc định `http://localhost:8081`
   - interceptor gắn header `Authorization: Bearer dev-<uid>`; uid dev đọc từ
     `--dart-define=DEV_UID=...`, mặc định `dev-local`. Viết sao cho sau này đổi sang token
     Firebase chỉ sửa một chỗ.
   - chuyển lỗi HTTP thành `ApiException(code, fields, statusCode)`
2. Model Dart cho response (`MeResponse`, `PlanView`, `ExerciseResponse`, `NutritionTarget`),
   tên trường khớp đúng JSON của OpenAPI. Không thêm thư viện sinh code, viết tay `fromJson`.
3. `ApiPlanRepository`, `ApiOnboardingRepository` thay cho bản giả qua Riverpod provider.
   Giữ bản giả để dùng trong test.
4. Chuyển `OnboardingState` thành body `POST /onboarding`:
   - `weightKg` lấy từ cân nặng hiện tại; `availability` = mỗi ngày đã chọn kèm khung giờ đã chọn
   - enum gửi đúng tên: `lose_fat`, `dumbbell`, `lower_back`, `early_morning`...
   - `displayName`: tạm thời thêm ô nhập tên ở màn đầu onboarding nếu chưa có
5. Luồng khi mở app: gọi `GET /me`.
   - 404 `ONBOARDING_REQUIRED` → vào onboarding
   - 200 → vào Home
   - lỗi mạng → màn báo "Không kết nối được máy chủ" kèm nút Thử lại
6. Màn OB-Plan và Home hiển thị kế hoạch thật từ API (ngày, giờ, tên buổi, tên bài).
   Lỗi 400 từ `POST /onboarding` thì hiện thông báo đúng trường bị sai.
7. Test: dùng repository giả, kiểm tra 3 nhánh khi mở app (404 / 200 / lỗi mạng) và việc chuyển
   `OnboardingState` thành JSON đúng tên trường và giá trị enum.

## Kiểm tra trước khi báo xong
- `flutter analyze` sạch, `flutter test` đạt
- Chạy backend + `flutter run -d chrome`, đi hết onboarding với uid mới
  (`--dart-define=DEV_UID=test1`), rồi mở Compass kiểm tra có document trong `users` và
  `training_plans`. Ghi lại kết quả trong báo cáo.
- Không merge vào `main`.
