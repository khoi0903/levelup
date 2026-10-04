import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_exceptions.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../controllers/auth_controller.dart';

class BootstrapScreen extends ConsumerWidget {
  const BootstrapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepo = ref.watch(authRepositoryProvider);

    // Luồng mở app: chưa đăng nhập → chuyển về màn đăng nhập
    if (authRepo.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/login');
        }
      });
      return Scaffold(
        body: GradientBackground(
          child: SafeArea(
            child: _buildLoadingWidget(),
          ),
        ),
      );
    }

    // Đã đăng nhập → gọi GET /me để kiểm tra trạng thái onboarding
    final statusAsync = ref.watch(userStatusFutureProvider);

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: statusAsync.when(
            data: (me) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  context.go('/home');
                }
              });
              return _buildLoadingWidget();
            },
            loading: () => _buildLoadingWidget(),
            error: (error, stack) {
              // 401 Unauthorized từ backend → tự động đăng xuất và quay về màn đăng nhập
              if (error is ApiException && error.statusCode == 401) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    ref.read(authRepositoryProvider).signOut();
                    ref.invalidate(userStatusFutureProvider);
                    ref.invalidate(currentUserProvider);
                    context.go('/login');
                  }
                });
                return _buildLoadingWidget();
              }

              // 404 ONBOARDING_REQUIRED → chuyển tiếp vào luồng Onboarding
              if (error is ApiException && error.isOnboardingRequired) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    context.go('/onboarding/goal');
                  }
                });
                return _buildLoadingWidget();
              }

              final bool isNetworkError =
                  error is ApiException && error.isNetworkError;

              final String errorTitle;
              final String errorSubtitle;
              final IconData errorIcon;

              if (isNetworkError) {
                errorTitle = 'Không kết nối được máy chủ';
                errorSubtitle =
                    'Vui lòng kiểm tra lại kết nối mạng hoặc đảm bảo máy chủ backend đang hoạt động.';
                errorIcon = Icons.cloud_off_rounded;
              } else {
                final errorCode = error is ApiException
                    ? (error.statusCode?.toString() ?? error.code)
                    : 'ERROR';
                errorTitle = 'Có lỗi xảy ra ($errorCode)';
                errorSubtitle =
                    'Đã xảy ra lỗi trong quá trình tải dữ liệu. Vui lòng thử lại sau.';
                errorIcon = Icons.error_outline_rounded;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: GlassCard(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          errorIcon,
                          size: 64,
                          color: AppColors.accent,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          errorTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          errorSubtitle,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: 160,
                          child: PrimaryButton(
                            label: 'Thử lại',
                            onPressed: () {
                              ref.invalidate(userStatusFutureProvider);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text(
            'LevelUp',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 24),
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ],
      ),
    );
  }
}
