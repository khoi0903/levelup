# Trang công khai LevelUp (Firebase Hosting)

Tên miền: https://levelup-pro.web.app (project Firebase `levelup-pro`).

| Đường dẫn | File | Dùng cho |
|---|---|---|
| `/privacy` | `public/privacy.html` | Chính sách quyền riêng tư (CH Play, app) |
| `/delete-account` | `public/delete-account.html` | Hướng dẫn xoá tài khoản (CH Play) |
| `/reset` | `public/reset.html` | Đặt lại mật khẩu, xác minh email (Firebase action URL) |
| `/invite?code=...` | `public/invite.html` | Link mời bạn (`levelup.referral.link-base`) |

Triển khai (lần đầu cần `npx firebase-tools login`):

```
cd web
npx firebase-tools deploy --only hosting
```

Backend vẫn giữ bản cũ trong `backend/src/main/resources/static/` cho các bản app cũ; sửa nội dung thì sửa cả hai.
