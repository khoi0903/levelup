import '../../../product/presentation/widgets/product_widgets.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../home/presentation/controllers/home_controller.dart';
import '../controllers/coach_controller.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../../domain/models/coach_models.dart';

/// Màn hình Chat với AI Coach (Tab Coach).
class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    final draft = ref.read(coachDraftMessageProvider);
    if (draft != null && draft.isNotEmpty) {
      _textController.text = draft;
      Future.microtask(() {
        if (mounted) ref.read(coachDraftMessageProvider.notifier).state = null;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      ref.read(coachChatProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSend([String? preset]) async {
    final text = (preset ?? _textController.text).trim();
    if (text.isEmpty) return;

    _textController.clear();
    final ok = await ref.read(coachChatProvider.notifier).sendMessage(text);
    if (!ok && mounted && _textController.text.isEmpty) {
      _textController.text = text; // gửi lỗi: trả lại chữ để gửi lại
    }
    if (ok && _scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(coachDraftMessageProvider, (prev, next) {
      if (next != null && next.isNotEmpty) {
        _textController.text = next;
        ref.read(coachDraftMessageProvider.notifier).state = null;
      }
    });

    final state = ref.watch(coachChatProvider);
    final notifier = ref.read(coachChatProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              'AI Coach',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Còn ${state.remainingToday} lượt hôm nay',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              if (state.error != null) ...[
                ProLimitAction(error: state.error),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFFCA5A5), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mapErrorMessage(state.error),
                          key: const ValueKey('coach-error-banner'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF991B1B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              ReloadingIndicator(
                isReloading: state.isLoading && state.messages.isNotEmpty,
              ),
              Expanded(
                child: (state.isLoading && state.messages.isEmpty)
                    ? const CoachScreenSkeleton()
                    : Builder(
                        builder: (context) {
                          final showTyping =
                              state.isSending && !state.hasStreamingReply;
                          // Câu chào luôn ở đầu cuộc trò chuyện (khi đã tải tới tin cũ nhất)
                          final showWelcome =
                              state.nextBefore == null && !state.isLoadingMore;
                          // Ít tin thì xếp từ trên xuống (shrinkWrap + Align top), nhiều tin thì cuộn như cũ
                          return Align(
                            alignment: Alignment.topCenter,
                            child: ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                16,
                              ),
                              itemCount:
                                  state.messages.length +
                                  (showTyping ? 1 : 0) +
                                  (state.isLoadingMore ? 1 : 0) +
                                  (showWelcome ? 1 : 0),
                              itemBuilder: (context, index) {
                                // Danh sách đảo ngược: index 0 là dưới cùng
                                if (showTyping) {
                                  if (index == 0) return _buildTyping();
                                  index -= 1;
                                }
                                if (showWelcome &&
                                    index == state.messages.length) {
                                  return _buildWelcome(state);
                                }
                                if (index == state.messages.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                final msg = state.messages[index];
                                return _buildMessageItem(
                                  context,
                                  msg,
                                  notifier,
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
              _buildInputBar(state),
            ],
          ),
        ),
      ),
    );
  }

  /// Câu chào của coach ở đầu cuộc trò chuyện (không lưu vào lịch sử). Chưa có tin nào thì kèm gợi ý.
  Widget _buildWelcome(CoachChatState state) {
    final name = ref.watch(currentUserProvider)?.displayName ?? '';
    final greeting = name.isEmpty ? 'Chào bạn!' : 'Chào $name!';
    const suggestions = [
      'Hôm nay mình nên tập gì?',
      'Mình mệt, có nên nghỉ buổi hôm nay không?',
      'Tối nay ăn gì để đủ đạm?',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMessageItem(
          context,
          CoachMessageView(
            id: 'welcome',
            role: 'coach',
            content:
                '$greeting Mình là coach của bạn. Bạn có thể hỏi mình về buổi tập, '
                'đổi lịch khi bận, hay ăn gì cho hợp mục tiêu.'
                '${state.messages.isEmpty ? ' Bắt đầu bằng một câu dưới đây nhé:' : ''}',
          ),
          ref.read(coachChatProvider.notifier),
        ),
        if (state.messages.isEmpty && !state.isSending) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map(
                  (q) => ActionChip(
                    key: ValueKey('coach-suggestion-$q'),
                    label: Text(q),
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.border),
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                    onPressed: state.isSending ? null : () => _handleSend(q),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTyping() {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'Coach đang trả lời…',
          key: ValueKey('coach-typing'),
          style: TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem(
    BuildContext context,
    CoachMessageView msg,
    CoachChatNotifier notifier,
  ) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isUser
                          ? const Radius.circular(16)
                          : const Radius.circular(4),
                      bottomRight: isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                    ),
                    border: isUser
                        ? null
                        : Border.all(color: AppColors.border, width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: isUser
                            ? AppColors.btnShadow
                            : AppColors.cardNormalShadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: isUser ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (msg.card != null) ...[
            const SizedBox(height: 8),
            _buildActionCard(context, msg, msg.card!, notifier),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    CoachMessageView msg,
    CoachCardView card,
    CoachChatNotifier notifier,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 40),
      child: GlassCard(
        isSelected: card.isProposed,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.fitness_center_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    card.change ?? 'Đề xuất điều chỉnh buổi tập',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (card.fromExerciseName != null &&
                card.toExerciseName != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        card.fromExerciseName!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        card.toExerciseName!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (card.reason != null) ...[
              const SizedBox(height: 6),
              Text(
                'Lý do: ${card.reason}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (card.isProposed) ...[
              PrimaryButton(
                label: 'Dùng buổi này',
                height: 38,
                onPressed: () async {
                  final ok = await notifier.applyAction(msg.id);
                  if (ok) {
                    ref.invalidate(homePlanProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã cập nhật kế hoạch buổi tập!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
              ),
            ] else ...[
              Row(
                children: const [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Đã áp dụng vào kế hoạch',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(CoachChatState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
              decoration: InputDecoration(
                hintText: 'Nhắn cho Coach...',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.primaryLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.btnShadow,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: state.isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
              onPressed: state.isSending ? null : _handleSend,
            ),
          ),
        ],
      ),
    );
  }
}
