import 'package:go_router/go_router.dart';
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
import '../features/workout/presentation/screens/workout_screen.dart';

GoRouter createAppRouter({String initialLocation = '/onboarding/goal'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
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
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/workout',
      name: 'workout',
      builder: (context, state) {
        final quick5 = state.uri.queryParameters['quick5'] == 'true';
        return WorkoutScreen(isQuick5: quick5);
      },
    ),
  ],
);

final appRouter = createAppRouter();
