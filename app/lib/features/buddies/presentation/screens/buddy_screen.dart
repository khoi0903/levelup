import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_palette.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../controllers/buddy_controller.dart';
import '../../domain/models/buddy_models.dart';

/// Màn hình Bạn đồng hành (Buddy - F5).
class BuddyScreen extends ConsumerStatefulWidget {
  const BuddyScreen({super.key});

  @override
  ConsumerState<BuddyScreen> createState() => _BuddyScreenState();
}

class _BuddyScreenState extends ConsumerState<BuddyScreen> {
  final _joinCodeController = TextEditingController();

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(buddyTodayFutureProvider);
    final buddyState = ref.watch(buddyControllerProvider);
    final notifier = ref.read(buddyControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bạn đồng hành (Buddy)',
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
          child: todayAsync.when(
            data: (today) => today != null
                ? _buildPairedView(context, today, buddyState, notifier)
                : _buildUnpairedView(context, buddyState, notifier),
            loading: () => Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(context.colors.primary),
              ),
            ),
            error: (err, _) => _buildUnpairedView(context, buddyState, notifier),
          ),
        ),
      ),
    );
  }

  Widget _buildPairedView(
    BuildContext context,
    BuddyTodayResponse today,
    BuddyState state,
    BuddyNotifier notifier,
  ) {
    final buddy = today.buddy;
    final actions = today.myActionsToday;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      children: [
        if (state.actionSuccessMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.colors.successBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.successBorder, width: 1),
            ),
            child: Text(
              state.actionSuccessMessage!,
              key: const ValueKey('buddy-success-banner'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.successText,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        if (state.error != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.colors.errorBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.errorBorder, width: 1),
            ),
            child: Text(
              mapErrorMessage(state.error),
              key: const ValueKey('buddy-error-banner'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.errorText,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Main buddy card
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.colors.primaryLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.colors.border, width: 1),
                    ),
                    child: Icon(Icons.person, color: context.colors.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          buddy.displayName,
                          key: const ValueKey('buddy-name-text'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.local_fire_department_rounded,
                                size: 16, color: context.colors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Streak ${buddy.streakWeeks} tuần',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.colors.accentLink,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(buddy.status),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: context.colors.border, height: 1),
              const SizedBox(height: 14),

              // Trạng thái hôm nay
              Text(
                'Hôm nay của bạn ấy:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatBuddyTodayStatus(buddy),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),

              if (buddy.week != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Tiến độ tuần: ${buddy.week!.completedSessions}/${buddy.week!.targetSessions} buổi',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],

              if (today.shared != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.colors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      if (today.shared!.weightKg != null) ...[
                        Expanded(
                          child: Text(
                            'Cân nặng: ${today.shared!.weightKg} kg',
                            style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                          ),
                        ),
                      ],
                      if (today.shared!.mealsKcalToday != null) ...[
                        Expanded(
                          child: Text(
                            'Đã nạp: ${today.shared!.mealsKcalToday} kcal',
                            style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Action buttons: Nudge & Cheer
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: actions.cheered ? 'Đã cổ vũ' : 'Cổ vũ 🔥',
                height: 46,
                onPressed: (actions.cheered || state.isActionLoading)
                    ? null
                    : () => notifier.sendCheer(today.pairId),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SecondaryButton(
                label: actions.nudged
                    ? 'Đã nhắc'
                    : (buddy.isDone ? 'Đã xong buổi' : 'Nhắc bạn tập ⏰'),
                height: 46,
                onPressed: (actions.nudged || buddy.isDone || state.isActionLoading)
                    ? null
                    : () => notifier.sendNudge(today.pairId),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Rời cặp
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.link_off_rounded, color: Colors.redAccent, size: 18),
            label: const Text(
              'Rời khỏi cặp đồng hành',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            onPressed: () => _confirmLeavePair(context, notifier),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case 'done':
        bg = context.colors.successBg;
        fg = context.colors.successText;
        text = 'Đã tập';
        break;
      case 'planned':
        bg = context.colors.primaryLight;
        fg = context.colors.primary;
        text = 'Chờ tập';
        break;
      case 'rest':
        bg = context.colors.mutedBg;
        fg = Colors.grey;
        text = 'Nghỉ';
        break;
      default:
        bg = context.colors.mutedBg;
        fg = context.colors.textSecondary;
        text = 'Chưa lên lịch';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  String _formatBuddyTodayStatus(BuddyInfo buddy) {
    if (buddy.isDone) {
      return 'Đã hoàn thành buổi tập hôm nay! 🎉';
    }
    if (buddy.isPlanned) {
      final time = buddy.scheduledTime != null ? 'lúc ${buddy.scheduledTime}' : 'hôm nay';
      final title = buddy.sessionTitle ?? 'Buổi tập';
      return 'Dự kiến tập $time · $title';
    }
    if (buddy.isRest) {
      return 'Hôm nay là ngày nghỉ ngơi phục hồi.';
    }
    return 'Hôm nay không có lịch tập.';
  }

  void _confirmLeavePair(BuildContext context, BuddyNotifier notifier) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Rời khỏi cặp đồng hành?'),
        content: const Text(
          'Bạn sẽ không còn thấy tiến độ tập luyện của nhau nữa. Bạn có thể ghép cặp lại bất cứ lúc nào.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await notifier.leavePair();
            },
            child: const Text(
              'Rời cặp',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnpairedView(
    BuildContext context,
    BuddyState state,
    BuddyNotifier notifier,
  ) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (state.error != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.colors.errorBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.errorBorder, width: 1),
            ),
            child: Text(
              mapErrorMessage(state.error),
              key: const ValueKey('buddy-unpaired-error'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.errorText,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Header Card
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            children: [
              Icon(Icons.people_outline_rounded, size: 48, color: context.colors.primary),
              SizedBox(height: 10),
              Text(
                'Tập luyện cùng bạn bè',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Người dùng có buddy cùng tập có tỉ lệ giữ thói quen lâu hơn 60%. Cùng nhắc nhở và cổ vũ nhau mỗi ngày!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Card 1: Tạo mã mời
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Mời một người bạn',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tạo mã mời gửi qua Zalo / Messenger để bạn bè cùng ghép cặp.',
                style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
              ),
              const SizedBox(height: 12),
              if (state.currentInvite != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: context.colors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.primary, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Text(
                        state.currentInvite!.code,
                        key: const ValueKey('buddy-invite-code-text'),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          color: context.colors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mã có hiệu lực trong 7 ngày',
                        style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SecondaryButton(
                  label: 'Sao chép tin nhắn mời',
                  height: 42,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: state.currentInvite!.shareText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã sao chép tin nhắn mời vào clipboard!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ] else ...[
                PrimaryButton(
                  label: state.isLoading ? 'Đang tạo...' : 'Tạo mã mời của bạn',
                  height: 44,
                  onPressed: state.isLoading ? null : () => notifier.createInvite(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Card 2: Nhập mã mời
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bạn có mã từ bạn bè?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Nhập mã 6 ký tự để ghép cặp với bạn đồng hành ngay lập tức.',
                style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _joinCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Ví dụ: LV8899',
                  hintStyle: TextStyle(fontSize: 14, color: context.colors.textSecondary),
                  filled: true,
                  fillColor: context.colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.colors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: state.isLoading ? 'Đang ghép cặp...' : 'Ghép cặp ngay',
                height: 44,
                onPressed: state.isLoading
                    ? null
                    : () async {
                        final code = _joinCodeController.text.trim();
                        if (code.isNotEmpty) {
                          await notifier.joinInvite(code);
                        }
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
