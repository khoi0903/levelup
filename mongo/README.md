# MongoDB cho app fitness

## Cần có
- Docker Desktop (đang chạy)
- MongoDB Compass (không bắt buộc, để xem dữ liệu)

## Bật database
Trong thư mục này:

```bash
docker compose up -d
```

Lần đầu mất khoảng 1 phút để tải image và tạo database `fitness` với 22 collection.
Kiểm tra đã tạo xong:

```bash
docker logs fitness-mongo-init
```

Thấy dòng `Đã tạo 22 collection.` là xong.

## Kết nối
- Compass hoặc API: `mongodb://localhost:27018/fitness?replicaSet=rs0`
- Chạy ở cổng **27018**, không đụng MongoDB khác đang chạy ở 27017.
- Là replica set 1 node nên dùng được transaction.

## Gửi dữ liệu cho người khác
Người gửi:

```powershell
.\export-db.ps1
```

Gửi file `fitness-....archive.gz` vừa tạo. Người nhận bật database như trên rồi chạy:

```powershell
.\import-db.ps1 .\fitness-....archive.gz
```

## Tắt, xóa
```bash
docker compose down      # tắt, giữ dữ liệu
docker compose down -v   # tắt và xóa hết dữ liệu
```
