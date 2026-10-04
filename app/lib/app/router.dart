import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_colors.dart';
import '../core/widgets/error_view.dart';
import '../core/widgets/gradient_background.dart';
import '../features/auth/presentation/screens/bootstrap_screen.dart';
import '../features/buddies/presentation/screens/buddy_screen.dart';
import '../features/checkins/presentation/screens/checkin_screen.dart';
import '../features/coach/presentation/screens/coach_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/onboarding/presentation/screens/ob_body_screen.dart';
import '../features/onboarding/presentation/screens/ob_coach_screen.dart';
import '../features/onboarding/presentation/screens/ob_goal_screen.dart';
import '../features/onboarding/presentation/screens/ob_notify_screen.dart';
import '../features/onboarding/presentation/screens/ob_plan_screen.dart';
import '../features/onboarding/presentation/screens/ob_schedule_screen.dart';
import '../features/onboarding/presentation/screens/ob_start_screen.dart';
import '../features/onboarding/presentation/screens/ob_training_screen.dart';
import '../features/onboarding/presentation/screens/ob_why_screen.dart';
import '../features/reviews/presentation/screens/review_screen.dart';
import '../features/shell/presentation/screens/app_shell_screen.dart';
import '../features/shell/presentation/screens/nutrition_placeholder_screen.dart';
import '../features/skip_report/presentation/screens/skip_report_screen.dart';
import '../features/streak/presentation/screens/streak_screen.dart';
import '../features/users/presentation/screens/achievements_screen.dart';
import '../features/users/presentation/screens/profile_screen.dart';
import '../features/workout/presentation/screens/camera_set_screen.dart';
import '../features/workout/presentation/screens/workout_active_screen.dart';
import '../features/workout/presentation/screens/workout_finish_screen.dart';
import '../features/workout/presentation/screens/workout_result_screen.dart';
import '../features/workout/presentation/screens/workout_start_screen.dart';

GoRouter createAppRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Không tìm thấy trang',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
    body: GradientBackground(
      child: SafeArea(
        child: ErrorView(
          code: '404',
          title: 'Không tìm thấy trang (404)',
          message: 'Trang bạn yêu cầu (${state.uri.path}) không tồn tại hoặc đã được chuyển đi.',
          retryLabel: 'Về trang chủ',
          onRetry: () => context.go('/home'),
        ),
      ),
    ),
  ),
  routes: [
    // Màn khởi động kiểm tra phiên đăng nhập
    GoRoute(
      path: '/',
      name: 'bootstrap',
      builder: (context, state) => const BootstrapScreen(),
    ),

    // Các màn Onboarding
    GoRoute(
      path: '/onboarding/goal',
      name: 'ob_goal',
      builder: (context, state) => const ObGoalScreen(),
    ),
    GoRoute(
      path: '/onboarding/body',
      name: 'ob_body',
      builder: (context, state) => const ObBodyScreen(),
    ),
    GoRoute(
      path: '/onboarding/training',
      name: 'ob_training',
      builder: (context, state) => const ObTrainingScreen(),
    ),
    GoRoute(
      path: '/onboarding/schedule',
      name: 'ob_schedule',
      builder: (context, state) => const ObScheduleScreen(),
    ),
    GoRoute(
      path: '/onboarding/why',
      name: 'ob_why',
      builder: (context, state) => const ObWhyScreen(),
    ),
    GoRoute(
      path: '/onboarding/coach',
      name: 'ob_coach',
      builder: (context, state) => const ObCoachScreen(),
    ),
    GoRoute(
      path: '/onboarding/plan',
      name: 'ob_plan',
      builder: (context, state) => const ObPlanScreen(),
    ),
    GoRoute(
      path: '/onboarding/notify',
      name: 'ob_notify',
      builder: (context, state) => const ObNotifyScreen(),
    ),
    GoRoute(
      path: '/onboarding/start',
      name: 'ob_start',
      builder: (context, state) => const ObStartScreen(),
    ),

    // Khung ứng dụng chính với 5 nhánh tab điều hướng dưới
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShellScreen(navigationShell: navigationShell),
      branches: [
        // Tab 0: Trang chủ
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),

        // Tab 1: Tập
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/workout',
              name: 'workout',
              builder: (context, state) => WorkoutStartScreen(
                quick5: state.uri.queryParameters['quick5'] == 'true',
              ),
            ),
          ],
        ),

        // Tab 2: Coach
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/coach',
              name: 'coach',
              builder: (context, state) => const CoachScreen(),
            ),
          ],
        ),

        // Tab 3: Dinh dưỡng (tạm thời trỏ tới placeholder, Codex làm màn)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/nutrition',
              name: 'nutrition',
              builder: (context, state) => const NutritionPlaceholderScreen(),
            ),
          ],
        ),

        // Tab 4: Tôi (Hồ sơ + Cài đặt)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              name: 'profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),

    // Các màn chức năng độc lập / chi tiết
    GoRoute(
      path: '/checkin',
      name: 'checkin',
      builder: (context, state) => const CheckinScreen(),
    ),
    GoRoute(
      path: '/streak',
      name: 'streak',
      builder: (context, state) => const StreakScreen(),
    ),
    GoRoute(
      path: '/skip-report',
      name: 'skip_report',
      builder: (context, state) => SkipReportScreen(
        sessionId: state.uri.queryParameters['sessionId'],
      ),
    ),
    GoRoute(
      path: '/buddy',
      name: 'buddy',
      builder: (context, state) => const BuddyScreen(),
    ),
    GoRoute(
      path: '/reviews/latest',
      name: 'reviews_latest',
      builder: (context, state) => const ReviewScreen(),
    ),
    GoRoute(
      path: '/achievements',
      name: 'achievements',
      builder: (context, state) => const AchievementsScreen(),
    ),

    // Luồng tập luyện trực tiếp (toàn màn hình, không hiện thanh điều hướng dưới)
    GoRoute(
      path: '/workout/active',
      name: 'workout_active',
      builder: (context, state) => const WorkoutActiveScreen(),
    ),
    GoRoute(
      path: '/workout/camera',
      name: 'workout_camera',
      builder: (context, state) =>
          CameraSetScreen(args: state.extra! as CameraSetArgs),
    ),
    GoRoute(
      path: '/workout/finish',
      name: 'workout_finish',
      builder: (context, state) => const WorkoutFinishScreen(),
    ),
    GoRoute(
      path: '/workout/result',
      name: 'workout_result',
      builder: (context, state) => const WorkoutResultScreen(),
    ),
    GoRoute(
      path: '/workout/:sessionId',
      name: 'workout_session',
      builder: (context, state) => WorkoutStartScreen(
        sessionId: state.pathParameters['sessionId'],
        quick5: state.uri.queryParameters['quick5'] == 'true',
      ),
    ),
  ],
);

final appRouter = createAppRouter();
