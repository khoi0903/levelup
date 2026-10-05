# LevelUp: conservative native-plugin retention after the previous release crashed
# on startup with R8. README links identify the plugins/packages; broad keeps below
# are this app's safety policy, not rules claimed to be required by each README.
# Keep dependency consumer rules enabled; do not suppress all R8 warnings.

# Flutter engine finds GeneratedPluginRegistrant by name; retain plugin classes
# and members, including plugins added transitively (e.g. path_provider).
# Source: Flutter SDK packages/flutter_tools/gradle/flutter_proguard_rules.pro
# and https://github.com/flutter/flutter/issues/154580
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }

# google_mlkit_pose_detection + google_mlkit_commons: native pose detectors,
# component discovery, and their platform-channel bridges.
# Sources: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_pose_detection/README.md
# https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/README.md
-keep class com.google_mlkit_pose_detection.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_** { *; }

# camera 0.12.x uses camera_android_camerax; retain both Android backends so the
# legacy package rule does not accidentally omit the current CameraX plugin.
# Source: https://github.com/flutter/packages/blob/main/packages/camera/camera_android_camerax/README.md
-keep class io.flutter.plugins.camera.** { *; }
-keep class io.flutter.plugins.camerax.** { *; }

# firebase_core / firebase_auth / firebase_messaging: native component registrars,
# messaging services, background-engine entry points, and Flutter bridges.
# Sources: https://github.com/firebase/flutterfire/blob/main/packages/firebase_core/firebase_core/README.md
# https://github.com/firebase/flutterfire/blob/main/packages/firebase_auth/firebase_auth/README.md
# https://github.com/firebase/flutterfire/blob/main/packages/firebase_messaging/firebase_messaging/README.md
-keep class com.google.firebase.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }

# google_sign_in_android: Google authentication SDK and its Flutter bridge.
# Source: https://github.com/flutter/packages/blob/main/packages/google_sign_in/google_sign_in_android/README.md
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }
-keep class io.flutter.plugins.googlesignin.** { *; }

# permission_handler_android: permission/activity-result callbacks.
# Source: https://github.com/Baseflow/flutter-permission-handler/blob/main/permission_handler_android/README.md
-keep class com.baseflow.permissionhandler.** { *; }

# shared_preferences_android: Pigeon channels and legacy serialized preferences.
# Source: https://github.com/flutter/packages/blob/main/packages/shared_preferences/shared_preferences_android/README.md
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# image_picker_android and transitive path_provider_android (google_fonts):
# activity results, file-provider paths, and compatibility with older backends.
# Sources: https://github.com/flutter/packages/blob/main/packages/image_picker/image_picker_android/README.md
# https://github.com/flutter/packages/blob/main/packages/path_provider/path_provider_android/README.md
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }

# Current path_provider_android 2.3.1 uses jni/jni_flutter. Their consumer rules
# already retain these packages; repeat explicitly to document native JNI lookup.
# Sources: https://github.com/dart-lang/native/blob/main/pkgs/jni/android/consumer-rules.pro
# https://github.com/dart-lang/native/blob/main/pkgs/jni_flutter/android/consumer-rules.pro
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }

# Remaining pubspec dependencies are Dart-only (or framework assets); they have
# no Android plugin package to keep. Add targeted -dontwarn only for verified
# optional classes listed in build/app/outputs/mapping/release/missing_rules.txt.
