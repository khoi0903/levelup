import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    // Đẩy AAB lên Google Play qua Play Developer API (scripts/publish-play.ps1, docs/play-publish.md)
    id("com.github.triplet.play")
}

// Optional local release credentials; never commit this file or the keystore.
// See docs/release-signing.md and https://docs.flutter.dev/deployment/android.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword").forEach { name ->
        require(!keystoreProperties.getProperty(name).isNullOrBlank()) {
            "android/key.properties must define $name for release signing"
        }
    }
    require(rootProject.file(keystoreProperties.getProperty("storeFile")).isFile) {
        "Release keystore referenced by android/key.properties does not exist"
    }
}

android {
    namespace = "vn.levelup.app"
    // permission_handler_android bản mới yêu cầu compile với API 37 (Flutter mặc định 36)
    compileSdk = maxOf(flutter.compileSdkVersion, 37)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications cần desugaring (API java.time trên Android cũ)
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "vn.levelup.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Camera requires API 24; this also satisfies ML Kit's API 21 minimum.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Máy dev/CI không có key.properties vẫn build được bằng khóa debug.
            // Trước khi phát hành, cấu hình khóa release theo docs/release-signing.md.
            signingConfig = signingConfigs.getByName(
                if (keystorePropertiesFile.exists()) "release" else "debug"
            )
            // Tắt rút gọn code (R8): bật lên thì app thoát ngay khi mở vì R8 bỏ class mà
            // camera / ML Kit / Firebase / WorkManager (Room) tạo qua reflection. Thử lại ở PR #9
            // (nhánh feat/app-r8) chỉ giảm ~6 MB nên để tắt; giảm dung lượng bằng --split-per-abi.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// Khoá service account để ngoài git (android/play-service-account.json, đã có trong .gitignore).
// Track mặc định "alpha" (test kín); đổi bằng --track=internal|beta|production khi chạy publishBundle.
play {
    serviceAccountCredentials.set(rootProject.file("play-service-account.json"))
    track.set("alpha")
    defaultToAppBundles.set(true)
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
