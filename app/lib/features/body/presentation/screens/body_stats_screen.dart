import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_palette.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../controllers/body_controller.dart';
import '../widgets/body_stats_view.dart';

/// Màn "Chỉ số của bạn" mở từ tab Tôi (GET /me/body).
class BodyStatsScreen extends ConsumerWidget {
  const BodyStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(bodyStatsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chỉ số của bạn',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.colors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: GradientBackground(
        child: SafeArea(
          child: stats.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ErrorView(
              message: mapErrorMessage(error),
              onRetry: () => ref.invalidate(bodyStatsProvider),
            ),
            data: (data) => SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: BodyStatsView(stats: data),
            ),
          ),
        ),
      ),
    );
  }
}
