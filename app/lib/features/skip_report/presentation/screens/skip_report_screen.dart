import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_palette.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../home/presentation/controllers/home_controller.dart';
import '../controllers/skip_report_controller.dart';

/// Màn hình báo Bỏ buổi tập / Điều chỉnh lịch (F3).
class SkipReportScreen extends ConsumerStatefulWidget {
  final String? sessionId;

  const SkipReportScreen({super.key, this.sessionId});

  @override
  ConsumerState<SkipReportScreen> createState() => _SkipReportScreenState();
}

class _SkipReportScreenState extends ConsumerState<SkipReportScreen> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(skipReportControllerProvider(widget.sessionId));
    final notifier = ref.read(
      skipReportControllerProvider(widget.sessionId).notifier,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Không tập được hôm nay',
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
          child: state.response != null || state.patchedPlan != null
              ? _buildResultView(context, state)
              : _buildFormView(context, state, notifier),
        ),
      ),
    );
  }

  Widget _buildFormView(
    BuildContext context,
    SkipReportState state,
    SkipReportNotifier notifier,
  ) {
    final isPain = state.reason == 'pain';

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      children: [
        Text(
          'Đừng lo! Lắng nghe cơ thể là một phần của hành trình.',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Hãy cho coach biết lý do, coach sẽ điều chỉnh kế hoạch để bạn duy trì streak mà không bị quá tải.',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        const SizedBox(height: 18),

        // Lịch chỉ để nhắc nên không dời buổi; chỉ cho nghỉ hôm nay
        if (widget.sessionId != null) ...[
          _buildActionTile(
            icon: Icons.hotel_rounded,
            title: 'Nghỉ hôm nay',
            onTap: () async {
              final res = await notifier.restSession(
                sessionId: widget.sessionId!,
              );
              if (res != null) {
                ref.invalidate(homePlanProvider);
              }
            },
          ),
          const SizedBox(height: 18),
        ],

        Text(
          'Lý do chính',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        _buildReasonOption(
          label: 'Bận đột xuất',
          desc: 'Công việc hoặc việc gia đình cần ưu tiên',
          reasonKey: 'busy',
          icon: '⏳',
          selectedReason: state.reason,
          onTap: () => notifier.setReason('busy'),
        ),
        const SizedBox(height: 8),
        _buildReasonOption(
          label: 'Quá mệt mỏi',
          desc: 'Thiếu ngủ, kiệt sức sau một ngày dài',
          reasonKey: 'tired',
          icon: '😴',
          selectedReason: state.reason,
          onTap: () => notifier.setReason('tired'),
        ),
        const SizedBox(height: 8),
        _buildReasonOption(
          label: 'Đau / Khó chịu vùng cơ thể',
          desc: 'Coach sẽ đổi sang bài an toàn cho vùng đau',
          reasonKey: 'pain',
          icon: '🩹',
          selectedReason: state.reason,
          onTap: () => notifier.setReason('pain'),
        ),
        const SizedBox(height: 8),
        _buildReasonOption(
          label: 'Cảm thấy chán / Nản',
          desc: 'Coach sẽ đổi động tác mới để tạo hứng thú',
          reasonKey: 'bored',
          icon: '🎈',
          selectedReason: state.reason,
          onTap: () => notifier.setReason('bored'),
        ),
        const SizedBox(height: 8),
        _buildReasonOption(
          label: 'Quên lịch tập',
          desc: 'Coach sẽ nhắc bạn trước giờ tập',
          reasonKey: 'forgot',
          icon: '⏰',
          selectedReason: state.reason,
          onTap: () => notifier.setReason('forgot'),
        ),
        const SizedBox(height: 8),
        _buildReasonOption(
          label: 'Lý do khác',
          desc: 'Ghi chú cho coach biết thêm',
          reasonKey: 'other',
          icon: '📝',
          selectedReason: state.reason,
          onTap: () => notifier.setReason('other'),
        ),

        // Vùng đau nếu reason == pain
        if (isPain) ...[
          const SizedBox(height: 18),
          Text(
            'Chọn vùng bị đau / khó chịu',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildAreaChip(
                'Lưng dưới',
                'lower_back',
                state.bodyArea,
                notifier,
              ),
              _buildAreaChip('Khớp gối', 'knee', state.bodyArea, notifier),
              _buildAreaChip('Khớp vai', 'shoulder', state.bodyArea, notifier),
              _buildAreaChip('Cổ', 'neck', state.bodyArea, notifier),
              _buildAreaChip('Cổ tay', 'wrist', state.bodyArea, notifier),
              _buildAreaChip('Cổ chân', 'ankle', state.bodyArea, notifier),
              _buildAreaChip('Khớp háng/hông', 'hip', state.bodyArea, notifier),
              _buildAreaChip('Khác', 'other', state.bodyArea, notifier),
            ],
          ),
        ],

        const SizedBox(height: 18),
        Text(
          'Ghi chú thêm (không bắt buộc)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _noteController,
          maxLines: 2,
          onChanged: (text) =>
              notifier.setNote(text.trim().isEmpty ? null : text.trim()),
          decoration: InputDecoration(
            hintText: 'Nhập ghi chú hoặc cảm nhận của bạn...',
            hintStyle: TextStyle(
              fontSize: 13,
              color: context.colors.textSecondary,
            ),
            filled: true,
            fillColor: context.colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: context.colors.primary,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),

        const SizedBox(height: 20),

        if (state.error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.errorBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.errorBorder, width: 1),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mapErrorMessage(state.error),
                    key: const ValueKey('skip-report-error-text'),
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.errorText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        PrimaryButton(
          label: state.isSubmitting
              ? 'Đang gửi...'
              : 'Gửi cho Coach & Điều chỉnh kế hoạch',
          onPressed: (state.isSubmitting || (isPain && state.bodyArea == null))
              ? null
              : () async {
                  final res = await notifier.submitReport();
                  if (res != null) {
                    ref.invalidate(homePlanProvider);
                  }
                },
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: context.colors.primaryLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border, width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: context.colors.primary, size: 24),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.colors.accentLink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonOption({
    required String label,
    required String desc,
    required String reasonKey,
    required String icon,
    required String selectedReason,
    required VoidCallback onTap,
  }) {
    final isSelected = reasonKey == selectedReason;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusCard),
      child: GlassCard(
        isSelected: isSelected,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? context.colors.buttonFill : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? context.colors.buttonFill
                      : context.colors.radioUnselectedBorder,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaChip(
    String label,
    String value,
    String? currentArea,
    SkipReportNotifier notifier,
  ) {
    final isSelected = value == currentArea;
    return InkWell(
      onTap: () => notifier.setBodyArea(isSelected ? null : value),
      borderRadius: BorderRadius.circular(AppColors.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.buttonFill : context.colors.surface,
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
          border: Border.all(
            color: isSelected ? context.colors.buttonFill : context.colors.border,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : context.colors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildResultView(BuildContext context, SkipReportState state) {
    final response = state.response;
    final message =
        response?.message ??
        (state.patchedPlan != null
            ? 'Kế hoạch buổi tập đã được cập nhật thành công!'
            : 'Đã ghi nhận yêu cầu của bạn.');

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: context.colors.primaryLight,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.smart_toy_outlined,
            size: 36,
            color: context.colors.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Coach đã tiếp nhận!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 18,
                    color: context.colors.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Lời nhắn từ Coach',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.colors.accentLink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                message,
                key: const ValueKey('skip-report-coach-message'),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Về trang chủ',
          onPressed: () => context.go('/home'),
        ),
      ],
    );
  }
}
