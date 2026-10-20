import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_palette.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/onboarding_header.dart';
import '../../../../core/widgets/missing_hint.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/models/onboarding_models.dart';
import '../controllers/onboarding_controller.dart';

class ObGoalScreen extends ConsumerStatefulWidget {
  const ObGoalScreen({super.key});

  @override
  ConsumerState<ObGoalScreen> createState() => _ObGoalScreenState();
}

class _ObGoalScreenState extends ConsumerState<ObGoalScreen> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(onboardingControllerProvider);
    _nameController = TextEditingController(text: state.displayName);
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    ref
        .read(onboardingControllerProvider.notifier)
        .setDisplayName(_nameController.text);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    String? userEmail;
    try {
      userEmail = ref.watch(authRepositoryProvider).currentUser?.email;
    } catch (_) {
      userEmail = null;
    }

    final goalOptions = [
      (
        UserGoal.lose_fat,
        AppStrings.goalLoseFatTitle,
        AppStrings.goalLoseFatDesc,
      ),
      (
        UserGoal.build_muscle,
        AppStrings.goalBuildMuscleTitle,
        AppStrings.goalBuildMuscleDesc,
      ),
      (
        UserGoal.get_healthier,
        AppStrings.goalGetHealthierTitle,
        AppStrings.goalGetHealthierDesc,
      ),
      (
        UserGoal.maintain,
        AppStrings.goalMaintainTitle,
        AppStrings.goalMaintainDesc,
      ),
    ];

    final String? missing = state.displayName.trim().isEmpty
        ? 'Nhập tên bạn muốn được gọi'
        : state.goal == null
        ? 'Chọn một mục tiêu để tiếp tục'
        : null;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const OnboardingHeader(currentStep: 1),
                const SizedBox(height: 20),
                Text(
                  AppStrings.goalTitle,
                  style: TextStyle(
                    fontSize: 28,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppStrings.goalSubtitle,
                  style: TextStyle(
                    fontSize: 15,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tên hiển thị của bạn',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  borderRadius: AppColors.radiusButton,
                  child: TextField(
                    controller: _nameController,
                    onChanged: (val) => controller.setDisplayName(val),
                    style: TextStyle(
                      fontSize: 16,
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                      border: InputBorder.none,
                      hintText: 'Nhập tên của bạn (vd: Minh)',
                      hintStyle: TextStyle(
                        fontSize: 15,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: goalOptions.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = goalOptions[index];
                      final isSelected = state.goal == item.$1;
                      return GlassCard(
                        isSelected: isSelected,
                        onTap: () => controller.selectGoal(item.$1),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.$2,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: context.colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.$3,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: context.colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            GlassRadio(isSelected: isSelected),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                MissingHint(missing),
                PrimaryButton(
                  label: AppStrings.btnContinue,
                  onPressed:
                      (state.goal != null &&
                          state.displayName.trim().isNotEmpty)
                      ? () {
                          controller.setDisplayName(
                            _nameController.text.trim(),
                          );
                          context.push('/onboarding/body');
                        }
                      : null,
                ),
                const SizedBox(height: 14),
                if (userEmail != null && userEmail.isNotEmpty) ...[
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Đang đăng nhập: $userEmail · ',
                        key: const ValueKey('ob-logged-in-email-text'),
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.textSecondary,
                        ),
                      ),
                      InkWell(
                        key: const ValueKey('ob-change-account-button'),
                        onTap: () async {
                          await appSignOut(ref);
                          if (context.mounted) {
                            context.go('/login');
                          }
                        },
                        child: Text(
                          'Đổi tài khoản',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.colors.accentLink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        AppStrings.alreadyHaveAccount,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.colors.textSecondary,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          if (context.mounted) {
                            context.go('/login');
                          }
                        },
                        child: Text(
                          AppStrings.logIn,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.colors.accentLink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
