import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/api/api_client.dart';
import 'core/constants/app_strings.dart';
import 'core/constants/auth_constants.dart';
import 'features/notifications/presentation/controllers/notifications_controller.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase nếu không chạy ở chế độ dev
  if (!AuthConstants.isDevMode) {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase.initializeApp error/warning: $e');
    }
  }

  runApp(
    ProviderScope(
      overrides: [
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
      routerConfig: appRouter,
    );
  }
}
