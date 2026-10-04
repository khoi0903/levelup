# Đưa backend lên mạng

Backend chạy bằng Docker (`backend/Dockerfile`), database là **MongoDB Atlas M0** (miễn phí).
Hai nơi chạy backend, chọn một:

- **Cloud Run** (Google): khởi động lại nhanh (~10–15 giây), chung tài khoản Google với Firebase,
  có Cloud Scheduler gọi job. Cần bật billing (gắn thẻ); dùng trong gói miễn phí thì không mất tiền.
- **Render**: miễn phí, không cần thẻ. Gói free ngủ sau 15 phút, gọi lại mất ~1 phút; dùng cron-job.org
  gọi `/jobs/tick` mỗi 15 phút thì gần như không ngủ.

Không dùng Vercel: Vercel không chạy server Java.

## 1. MongoDB Atlas (làm cho cả hai cách)

1. Vào https://www.mongodb.com/cloud/atlas → tạo tài khoản → **Create cluster** → chọn **M0 (Free)**,
   provider **Google Cloud** hoặc **AWS**, region **Singapore**. Tên cluster: `levelup`.
2. **Database Access** → Add user, ví dụ `levelup-app`, mật khẩu tự sinh (lưu lại, không dán vào chat).
   Quyền: *Read and write to any database*.
3. **Network Access** → Add IP Address → `0.0.0.0/0` (Cloud Run và Render không có IP cố định;
   database vẫn cần user + mật khẩu).
4. **Connect → Drivers** → copy chuỗi `mongodb+srv://...`, thêm tên database `fitness` sau `.net/`:
   `mongodb+srv://levelup-app:<mật khẩu>@levelup.xxxxx.mongodb.net/fitness?retryWrites=true&w=majority`
5. Tạo collection + nạp dữ liệu mẫu (Docker đang chạy):
   ```powershell
   cd D:\fitness-app\mongo
   .\setup-atlas.ps1 "<chuỗi kết nối ở bước 4>"
   ```
   Thấy `Đã tạo 22 collection.` và số bài tập, món ăn đã nạp là xong.

Atlas là replica set nên transaction chạy như MongoDB trên máy.

## 2. Biến môi trường của backend

| Biến | Giá trị |
|---|---|
| `MONGODB_URI` | chuỗi kết nối Atlas ở trên |
| `LEVELUP_AI_PROVIDER` | `gemini` |
| `GEMINI_API_KEY` | key Gemini (**key mới**, key cũ đã lộ trong chat) |
| `FIREBASE_PROJECT_ID` | `levelup-pro` |
| `FIREBASE_CREDENTIALS` | đường dẫn file service account **trong container** (xem từng nơi bên dưới) |
| `JOB_SECRET` | chuỗi ngẫu nhiên dài, tạo bằng lệnh dưới; Cloud Scheduler / cron-job.org gửi trong header `X-Job-Secret` |

Không đặt profile `dev` trên server (profile dev nhận token giả `dev-<uid>`).

Tạo `JOB_SECRET` (PowerShell):
```powershell
-join ((48..57 + 65..90 + 97..122) | Get-Random -Count 40 | ForEach-Object { [char]$_ })
```

## 3a. Cloud Run

Cần: Google Cloud SDK (`gcloud`), project `levelup-pro` đã bật billing
(Firebase console → ⚙ → Usage and billing → Modify plan → Blaze; đặt **budget alert** ví dụ 1 USD).

```powershell
gcloud auth login
gcloud config set project levelup-pro
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com secretmanager.googleapis.com cloudscheduler.googleapis.com

# Khóa và mật khẩu để trong Secret Manager, không đặt thẳng vào biến môi trường
gcloud secrets create firebase-sa --data-file=D:\secrets\levelup-pro-firebase.json
"<chuỗi Atlas>" | gcloud secrets create mongodb-uri --data-file=-
"<key Gemini mới>" | gcloud secrets create gemini-key --data-file=-
"<JOB_SECRET>" | gcloud secrets create job-secret --data-file=-

# Cho service account mặc định của Cloud Run đọc secret
$num = gcloud projects describe levelup-pro --format="value(projectNumber)"
gcloud projects add-iam-policy-binding levelup-pro --member="serviceAccount:$num-compute@developer.gserviceaccount.com" --role="roles/secretmanager.secretAccessor"

# Build bằng Cloud Build (không tốn RAM máy mình) và deploy
cd D:\fitness-app\backend
gcloud run deploy levelup-backend --source . --region asia-southeast1 --allow-unauthenticated `
  --memory 1Gi --cpu 1 --min-instances 0 --max-instances 2 `
  --set-env-vars "LEVELUP_AI_PROVIDER=gemini,FIREBASE_PROJECT_ID=levelup-pro,FIREBASE_CREDENTIALS=/secrets/firebase/sa.json" `
  --set-secrets "MONGODB_URI=mongodb-uri:latest,GEMINI_API_KEY=gemini-key:latest,JOB_SECRET=job-secret:latest,/secrets/firebase/sa.json=firebase-sa:latest"
```

`--allow-unauthenticated` chỉ cho phép gọi tới server; mọi API vẫn cần Firebase ID token.
Lệnh in ra URL dạng `https://levelup-backend-xxxxx.asia-southeast1.run.app`.

Job mỗi 15 phút:
```powershell
gcloud scheduler jobs create http levelup-tick --location asia-southeast1 --schedule "*/15 * * * *" `
  --uri "https://<URL Cloud Run>/jobs/tick" --http-method POST --headers "X-Job-Secret=<JOB_SECRET>"
```

Muốn demo không phải chờ khởi động: tạm đặt `--min-instances 1` trước buổi demo (tốn tiền khi bật lâu),
xong demo đặt lại `0`.

## 3b. Render (đang dùng)

Cấu hình nằm trong `render.yaml` ở gốc repo (Docker, gói free, Singapore, health check `/actuator/health`).

1. https://render.com → đăng nhập bằng GitHub → cho Render quyền đọc repo `levelup` (private).
2. **New → Blueprint** → chọn repo → Render đọc `render.yaml`, hỏi 3 giá trị bí mật:
   `MONGODB_URI` (chuỗi Atlas), `GEMINI_API_KEY` (key mới), `JOB_SECRET` (chuỗi tạo ở mục 2).
3. Sau khi tạo: vào service `levelup-backend` → **Environment → Secret Files → Add** → tên `firebase-sa.json`,
   dán nội dung file `D:\secrets\levelup-pro-firebase.json` → Save → **Manual Deploy → Deploy latest commit**.
4. Lần đầu build mất khoảng 5–10 phút. Log có `Push: gửi thật qua FCM` và `Started LevelupBackendApplication`
   là chạy. URL dạng `https://levelup-backend.onrender.com`.
5. https://cron-job.org (miễn phí) → Create cronjob: URL `https://<URL Render>/jobs/tick`, **mỗi 10 phút**
   **Advanced → Request method** POST, **Headers** thêm `X-Job-Secret` = `<JOB_SECRET>`.
   (Render ngủ sau 15 phút không có request; 10 phút để chắc chắn). Job này vừa chạy nhắc nhở / tổng kết tuần, vừa giữ server không ngủ. Gói free 750 giờ/tháng đủ chạy liên tục.

Gói free có 512 MB RAM và CPU yếu: khởi động mất khoảng 1–2 phút. Nếu log báo hết bộ nhớ
(`OOMKilled` / `Exited with status 137`) thì báo Claude Code chỉnh lại `JAVA_TOOL_OPTIONS` trong Dockerfile.

## 4. Kiểm tra và build app

```powershell
curl https://<URL>/actuator/health     # {"status":"UP"}
cd D:\fitness-app\app
flutter run -d <id điện thoại> --dart-define=API_BASE_URL=https://<URL>
```

Bản build để cài cho người khác: `flutter build apk --release --dart-define=API_BASE_URL=https://<URL>`
(cần thêm SHA-1 của khóa release vào Firebase để đăng nhập Google chạy được).
