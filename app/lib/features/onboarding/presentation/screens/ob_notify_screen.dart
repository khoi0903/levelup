import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_palette.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';
import '../controllers/onboarding_controller.dart';

class ObNotifyScreen extends ConsumerWidget {
  const ObNotifyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onboardingControllerProvider.notifier);

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      controller.setPushEnabled(false);
                      context.push('/onboarding/start');
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 10,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text(AppStrings.btnSkip),
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Mock notifications preview container
                        GlassCard(
                          padding: const EdgeInsets.all(16),
                          borderRadius: AppColors.radiusCard,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Notification Card 1 (Active)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colors.cardSelectedBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: context.colors.cardSelectedBorder,
                                    width: 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.colors.cardSelectedShadow,
                                      blurRadius: 16,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: context.colors.buttonFill,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.notifications_active,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            AppStrings.notifyMockTitle1,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: context.colors.textPrimary,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            AppStrings.notifyMockBody1,
                                            style: TextStyle(
                                              fontSize: 14,
                                              height: 1.45,
                                              color: context.colors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Notification Card 2 (Faded)
                              Opacity(
                                opacity: 0.7,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: context.colors.border,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: context.colors.primaryLight,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.chat_bubble,
                                          color: context.colors.primary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              AppStrings.notifyMockTitle2,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: context.colors.textPrimary,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              AppStrings.notifyMockBody2,
                                              style: TextStyle(
                                                fontSize: 14,
                                                height: 1.45,
                                                color: context.colors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          AppStrings.notifyTitle,
                          style: TextStyle(
                            fontSize: 26,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.notifySubtitle,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3 cam kết
                        _NotifyFeatureItem(text: AppStrings.notifyPoint1),
                        const SizedBox(height: 12),
                        _NotifyFeatureItem(text: AppStrings.notifyPoint2),
                        const SizedBox(height: 12),
                        _NotifyFeatureItem(text: AppStrings.notifyPoint3),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                PrimaryButton(
                  label: AppStrings.btnEnableNotification,
                  onPressed: () async {
                    final pushService = ref.read(pushServiceProvider);
                    final granted = await pushService.requestPermission();
                    controller.setPushEnabled(granted);
                    if (context.mounted) {
                      context.push('/onboarding/start');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotifyFeatureItem extends StatelessWidget {
  final String text;

  const _NotifyFeatureItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.check_circle, color: context.colors.accent, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: context.colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
