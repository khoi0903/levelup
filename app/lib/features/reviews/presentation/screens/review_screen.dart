import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_palette.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../home/presentation/controllers/home_controller.dart';
import '../controllers/review_controller.dart';
import '../../domain/models/review_models.dart';

/// Màn hình Tổng kết tuần & Kế hoạch tuần tới (F6).
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewAsync = ref.watch(latestReviewFutureProvider);
    final decisionState = ref.watch(reviewDecisionControllerProvider);
    final decisionNotifier = ref.read(reviewDecisionControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tổng kết tuần',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.colors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: reviewAsync.when(
            data: (review) =>
                _buildContent(context, ref, review, decisionState, decisionNotifier),
            loading: () => Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(context.colors.primary),
              ),
            ),
            error: (err, _) {
              final msg = mapErrorMessage(err);
              if (msg.contains('Chưa có tổng kết tuần') ||
                  err.toString().contains('NO_REVIEW')) {
                return EmptyView(
                  icon: Icons.calendar_today_rounded,
                  title: 'Chưa có tổng kết tuần',
                  subtitle:
                      'Hệ thống sẽ tự động tổng kết sau khi bạn kết thúc tuần tập luyện.',
                  actionLabel: 'Về trang chủ',
                  onAction: () => context.go('/home'),
                );
              }
              return ErrorView(
                message: msg,
                onRetry: () => ref.invalidate(latestReviewFutureProvider),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    WeeklyReviewView review,
    ReviewDecisionState decisionState,
    ReviewDecisionNotifier decisionNotifier,
  ) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      children: [
        if (decisionState.error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.errorBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.errorBorder, width: 1),
            ),
            child: Text(
              mapErrorMessage(decisionState.error),
              key: const ValueKey('review-error-banner'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.errorText,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Overview stats card
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tuần bắt đầu ${review.weekStart}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Hoàn thành ${review.sessionsDone}/${review.sessionsTarget} buổi (${review.completionPct}%)',
                key: const ValueKey('review-completion-text'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatItem(context, 'Tổng thời gian', '${review.totalMinutes} phút'),
                  if (review.avgRpe != null) ...[
                    const SizedBox(width: 16),
                    _buildStatItem(context, 'Độ mệt trung bình', 'RPE ${review.avgRpe!.toStringAsFixed(1)}/10'),
                  ],
                  if (review.weightChangeKg != null) ...[
                    const SizedBox(width: 16),
                    _buildStatItem(context, 
                      'Cân nặng',
                      '${review.weightChangeKg! > 0 ? '+' : ''}${review.weightChangeKg} kg',
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Wins card
        if (review.win != null || review.wins.isNotEmpty) ...[
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events_rounded, color: context.colors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Điểm sáng tuần qua',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (review.win != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    review.win!,
                    key: const ValueKey('review-win-text'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
                for (final w in review.wins) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 16, color: context.colors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          w.label,
                          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Suggestions / Improvement
        if (review.improvement != null) ...[
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, color: context.colors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Gợi ý từ Coach',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  review.improvement!,
                  key: const ValueKey('review-improvement-text'),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Next week recommendation card
        GlassCard(
          isSelected: true,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: context.colors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Đề xuất kế hoạch tuần tới',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                review.nextWeekSummary ??
                    (review.recommendation == 'increase'
                        ? 'Tăng nhẹ số buổi hoặc thời lượng để tiếp tục bứt phá.'
                        : 'Duy trì nhịp độ hiện tại để củng cố thói quen.'),
                key: const ValueKey('review-next-week-summary'),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: context.colors.accentLink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Action decisions
        if (review.isPending && decisionState.activePlan == null) ...[
          PrimaryButton(
            label: decisionState.isSubmitting ? 'Đang xác nhận...' : 'Đồng ý kế hoạch đề xuất',
            onPressed: decisionState.isSubmitting
                ? null
                : () async {
                    final res = await decisionNotifier.acceptReview(review.id);
                    if (res != null) {
                      ref.invalidate(homePlanProvider);
                    }
                  },
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Tự điều chỉnh số buổi & thời gian',
            onPressed: decisionState.isSubmitting
                ? null
                : () => _showAdjustDialog(context, review.id, decisionNotifier, ref),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.successBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.successBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, color: context.colors.successText, size: 20),
                SizedBox(width: 8),
                Text(
                  'Đã xác nhận kế hoạch tuần tới!',
                  key: ValueKey('review-accepted-badge'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.successText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Về trang chủ',
            onPressed: () => context.go('/home'),
          ),
        ],
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _showAdjustDialog(
    BuildContext context,
    String reviewId,
    ReviewDecisionNotifier notifier,
    WidgetRef ref,
  ) {
    int sessions = 3;
    int minutes = 15;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Điều chỉnh kế hoạch tuần tới',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Số buổi trong tuần:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: sessions > 1 ? () => setState(() => sessions--) : null,
                          ),
                          Text(
                            '$sessions buổi',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: sessions < 7 ? () => setState(() => sessions++) : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Thời lượng mỗi buổi:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: minutes > 5 ? () => setState(() => minutes -= 5) : null,
                          ),
                          Text(
                            '$minutes phút',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: minutes < 60 ? () => setState(() => minutes += 5) : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Áp dụng kế hoạch này',
                    onPressed: () async {
                      Navigator.pop(bottomSheetCtx);
                      final res = await notifier.adjustReview(
                        reviewId,
                        sessionsPerWeek: sessions,
                        sessionMinutes: minutes,
                      );
                      if (res != null) {
                        ref.invalidate(homePlanProvider);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
