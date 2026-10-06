package vn.levelup.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Mức HIGH: thông báo bật xuống từ đầu màn hình (heads-up). Android không cho đổi mức của kênh
            // đã tạo, nên dùng id mới và xóa kênh cũ "levelup_reminders" (mức mặc định, chỉ nằm im trong thanh).
            val channel = NotificationChannel(
                "levelup_alerts",
                "Nhắc tập & thói quen",
                NotificationManager.IMPORTANCE_HIGH
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
            manager?.deleteNotificationChannel("levelup_reminders")
        }
    }
}
