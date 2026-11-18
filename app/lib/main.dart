import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'app/theme_mode.dart';
import 'core/api/api_client.dart';
import 'core/constants/app_strings.dart';
import 'core/constants/auth_constants.dart';
import 'features/notifications/presentation/controllers/notifications_controller.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/body/presentation/widgets/anatomy_license.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Giấy phép MIT của hình giải phẫu dùng trong bản đồ cơ.
  registerAnatomyArtLicense();

  // Khởi tạo Firebase nếu không chạy ở chế độ dev
  if (!AuthConstants.isDevMode) {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase.initializeApp error/warning: $e');
    }
  }

  final savedThemeMode = await loadSavedThemeMode();

  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith(
          (ref) => ThemeModeNotifier(savedThemeMode),
        ),
        // Xử lý khi nhận mã lỗi 401 từ backend: tự động đăng xuất và về màn đăng nhập
        unauthorizedHandlerProvider.overrideWith((ref) {
          return () async {
            await appSignOutRef(ref);
            appRouter.go('/login');
          };
        }),
      ],
      child: const LevelUpApp(),
    ),
  );
}

class LevelUpApp extends ConsumerStatefulWidget {
  const LevelUpApp({super.key});

  @override
  ConsumerState<LevelUpApp> createState() => _LevelUpAppState();
}

class _LevelUpAppState extends ConsumerState<LevelUpApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationCoordinatorProvider).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppStrings.appName,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider),
      // Icon thanh trạng thái sáng/tối theo theme ở cả màn không có AppBar
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: child ?? const SizedBox.shrink(),
      ),
      routerConfig: appRouter,
    );
  }
}
