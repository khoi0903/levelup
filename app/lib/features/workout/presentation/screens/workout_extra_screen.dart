import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../onboarding/domain/models/plan_models.dart';
import '../../../onboarding/presentation/controllers/onboarding_controller.dart';
import '../../../users/domain/models/me_response.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../../domain/models/exercise_response.dart';
import '../../domain/models/extra_workout_builder.dart';
import '../../domain/models/workout_session_state.dart';
import '../controllers/workout_controller.dart';
import '../widgets/workout_widgets.dart';

/// Màn hình "Tập thêm" (/workout/extra):
/// - Chọn buổi gợi ý nhanh (5 phút nhanh, Toàn thân, Chân & mông, Tay & vai, Bụng)
/// - Tập lại buổi hôm nay (nếu có buổi hoàn thành trong lịch)
/// - Tự chọn bài tập (tìm kiếm không dấu, lọc nhóm cơ, chỉnh hiệp và số lần/giây)
class WorkoutExtraScreen extends ConsumerStatefulWidget {
  const WorkoutExtraScreen({super.key});

  @override
  ConsumerState<WorkoutExtraScreen> createState() => _WorkoutExtraScreenState();
}

class _WorkoutExtraScreenState extends ConsumerState<WorkoutExtraScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedMuscleFilter = 'all';
  int? _selectedDuration;

  // Lưu cấu hình bài tập tự chọn: exerciseId -> {sets, reps, durationSec}
  final Map<String, ({int sets, int? reps, int? durationSec})>
  _customSelections = {};

  /// Tải một lần; chọn bài (setState) không được gọi lại API, nếu không màn hình nháy về vòng tải.
  late Future<(List<ExerciseResponse>, PlanView)> _data;

  Future<(List<ExerciseResponse>, PlanView)> _load() =>
      Future.wait([
        ref.read(workoutRepositoryProvider).getExercises(),
        ref.read(planRepositoryProvider).getCurrentPlan(),
      ]).then(
        (values) =>
            (values[0] as List<ExerciseResponse>, values[1] as PlanView),
      );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _data = _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _startSetup(WorkoutSetup setup) {
    ref.read(extraWorkoutSetupProvider.notifier).state = setup;
    context.push('/workout/${setup.session.id}');
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userStatusFutureProvider);

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: FutureBuilder<(List<ExerciseResponse>, PlanView)>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: WorkoutIconButton(
                          icon: Icons.close_rounded,
                          onTap: _close,
                        ),
                      ),
                      const Spacer(),
                      const ErrorBanner(
                        message:
                            'Không tải được danh sách bài tập. Thử lại sau.',
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Thử lại',
                        onPressed: () => setState(() => _data = _load()),
                      ),
                      const Spacer(),
                    ],
                  ),
                );
              }

              final (allExercises, plan) = snapshot.data!;
              final user = userAsync.valueOrNull;
              final location = user?.profile?.location;
              final equipment = user?.profile?.equipment ?? const [];
              final activeInjuries = user?.activeInjuryAreas ?? const [];
              final todayCheckin = user?.todayCheckin;
              final todayStr = user?.localDate ?? localDateString(DateTime.now());

              final lastSaved = ref.watch(lastSavedWorkoutRequestProvider);
              final hasPainFollowUp = user != null && user.painFollowUps.isNotEmpty;
              final hasSharpToday = lastSaved != null &&
                  lastSaved.painType == 'sharp' &&
                  lastSaved.painAreas.isNotEmpty;
              final hasPain = hasPainFollowUp || hasSharpToday;

              String painLabel = '';
              if (hasPainFollowUp) {
                painLabel = user.painFollowUps.map((p) => p.label).join(', ');
              } else if (hasSharpToday) {
                painLabel = lastSaved.painAreas
                    .map((a) => a.labelVi.toLowerCase())
                    .join(', ');
              }

              final effectiveInjuries = <String>{
                ...activeInjuries,
                if (hasSharpToday) ...lastSaved.painAreas.map((a) => a.json),
                if (hasPainFollowUp) ...user.painFollowUps.map((p) => p.bodyArea),
              }.toList();

              // Tìm buổi hôm nay đã hoàn thành nếu có
              final todayDoneSession = plan.sessions
                  .cast<SessionView?>()
                  .firstWhere(
                    (s) =>
                        s != null &&
                        s.scheduledDate == todayStr &&
                        s.status == 'completed',
                    orElse: () => null,
                  );

              // Lọc bài tập an toàn theo nơi tập, dụng cụ, chấn thương
              final safeExercises = filterExercisesForUser(
                exercises: allExercises,
                location: location,
                userEquipment: equipment,
                activeInjuries: effectiveInjuries,
              );

              return Column(
                children: [
                  // App Bar / Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        WorkoutIconButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: _close,
                          tooltip: 'Quay lại',
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tập thêm',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Chọn buổi gợi ý hoặc tự chọn bài tập',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Dòng nhắc nhẹ khi đang đau
                  if (hasPain) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Container(
                        key: const ValueKey('pain-reminder-banner'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.placeholder,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bạn đang đau $painLabel. Nghỉ cũng là một phần của tập luyện; nếu vẫn muốn tập, mình đã bỏ bài tác động vào vùng này.',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    key: const ValueKey('extra-pain-other-part-btn'),
                                    onPressed: () => _tabController.animateTo(1),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      side: const BorderSide(color: AppColors.primary),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Tập phần khác',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    key: const ValueKey('extra-pain-light10-btn'),
                                    onPressed: () {
                                      _startSetup(
                                        buildSuggestedWorkoutSetup(
                                          exercises: allExercises,
                                          type: SuggestedWorkoutType.light10,
                                          location: location,
                                          userEquipment: equipment,
                                          activeInjuries: effectiveInjuries,
                                          durationMin: 10,
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Bản nhẹ 10 phút',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Tabs: Gợi ý / Tự chọn
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.placeholder,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: Colors.white,
                        unselectedLabelColor: AppColors.textSecondary,
                        indicator: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        tabs: const [
                          Tab(text: 'Buổi gợi ý'),
                          Tab(text: 'Tự chọn bài'),
                        ],
                      ),
                    ),
                  ),

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Buổi gợi ý & Tập lại
                        _buildSuggestedTab(
                          safeExercises: safeExercises,
                          todayDoneSession: todayDoneSession,
                          allExercises: allExercises,
                          location: location,
                          equipment: equipment,
                          activeInjuries: effectiveInjuries,
                          todayCheckin: todayCheckin,
                          hasPain: hasPain,
                        ),

                        // Tab 2: Tự chọn bài
                        _buildCustomTab(
                          allExercises: allExercises,
                          location: location,
                          equipment: equipment,
                          activeInjuries: effectiveInjuries,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // TAB 1: Buổi gợi ý & Tập lại hôm nay
  // ---------------------------------------------------------------------------
  Widget _buildSuggestedTab({
    required List<ExerciseResponse> safeExercises,
    required SessionView? todayDoneSession,
    required List<ExerciseResponse> allExercises,
    required String? location,
    required List<String> equipment,
    required List<String> activeInjuries,
    required TodayCheckin? todayCheckin,
    bool hasPain = false,
  }) {
    final isLow = todayCheckin?.isLow == true;
    final isEnergized = todayCheckin?.isEnergized == true;
    final effectiveDuration = _selectedDuration ?? (isLow ? 5 : 15);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        // Dòng gợi ý check-in trên đầu
        if (todayCheckin != null && isLow) ...[
          const TipBox(
            icon: Icons.info_outline_rounded,
            child: Text('Sáng nay bạn thấy mệt nên buổi gợi ý nhẹ hơn'),
          ),
          const SizedBox(height: 14),
        ] else if (todayCheckin != null && isEnergized) ...[
          const TipBox(
            icon: Icons.bolt_rounded,
            child: Text('Bạn đang sung sức, thử buổi đầy đủ nhé'),
          ),
          const SizedBox(height: 14),
        ] else if (todayCheckin == null) ...[
          TipBox(
            icon: Icons.wb_sunny_outlined,
            child: Row(
              children: [
                const Expanded(
                  child: Text('Check-in để buổi tập hợp thể trạng'),
                ),
                TextButton(
                  key: const ValueKey('extra-checkin-btn'),
                  onPressed: () => context.push('/checkin'),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Check-in',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 1c: "Tập lại buổi hôm nay"
        if (todayDoneSession != null) ...[
          _buildRedoCard(todayDoneSession, allExercises),
          const SizedBox(height: 18),
        ],

        // Tiêu đề phần gợi ý
        const Text(
          'Gợi ý nhanh theo nhóm cơ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Đã lọc theo nơi tập và dụng cụ của bạn',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),

        // Mức thời lượng
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildDurationChip(5, '5 phút', enabled: true, selected: effectiveDuration == 5),
              _buildDurationChip(10, '10 phút', enabled: true, selected: effectiveDuration == 10),
              _buildDurationChip(15, '15 phút', enabled: true, selected: effectiveDuration == 15),
              _buildDurationChip(20, '20 phút', enabled: !isLow, selected: effectiveDuration == 20),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (hasPain) ...[
          _buildSuggestedCard(
            type: SuggestedWorkoutType.light10,
            subtitle: '3 bài tập · 10 phút · Cường độ nhẹ nhàng, bảo vệ vùng đau',
            icon: Icons.spa_rounded,
            iconColor: const Color(0xFF059669),
            bgColor: const Color(0xFFD1FAE5),
            safeExercises: safeExercises,
            location: location,
            equipment: equipment,
            activeInjuries: activeInjuries,
            isLowCheckin: false,
            durationMin: 10,
          ),
          const SizedBox(height: 10),
        ],

        // 5 thẻ gợi ý
        _buildSuggestedCard(
          type: SuggestedWorkoutType.quick5,
          subtitle: '3 bài tập · 5 phút · Khởi động nhanh, nhẹ nhàng',
          icon: Icons.bolt_rounded,
          iconColor: const Color(0xFFD97706),
          bgColor: const Color(0xFFFEF3C7),
          safeExercises: safeExercises,
          location: location,
          equipment: equipment,
          activeInjuries: activeInjuries,
          isLowCheckin: isLow,
          durationMin: 5,
        ),
        const SizedBox(height: 10),
        _buildSuggestedCard(
          type: SuggestedWorkoutType.fullBody,
          subtitle: '4 bài tập · $effectiveDuration phút · Cân bằng toàn bộ cơ thể',
          icon: Icons.accessibility_new_rounded,
          iconColor: AppColors.primary,
          bgColor: AppColors.primaryLight,
          safeExercises: safeExercises,
          location: location,
          equipment: equipment,
          activeInjuries: activeInjuries,
          isLowCheckin: isLow,
          durationMin: effectiveDuration,
        ),
        const SizedBox(height: 10),
        _buildSuggestedCard(
          type: SuggestedWorkoutType.legsGlutes,
          subtitle: '4 bài tập · $effectiveDuration phút · Đùi, bắp chân và mông săn chắc',
          icon: Icons.directions_run_rounded,
          iconColor: const Color(0xFF059669),
          bgColor: const Color(0xFFD1FAE5),
          safeExercises: safeExercises,
          location: location,
          equipment: equipment,
          activeInjuries: activeInjuries,
          isLowCheckin: isLow,
          durationMin: effectiveDuration,
        ),
        const SizedBox(height: 10),
        _buildSuggestedCard(
          type: SuggestedWorkoutType.armsShoulders,
          subtitle: '4 bài tập · $effectiveDuration phút · Tay trước, tay sau và vai',
          icon: Icons.fitness_center_rounded,
          iconColor: const Color(0xFF7C3AED),
          bgColor: const Color(0xFFEDE9FE),
          safeExercises: safeExercises,
          location: location,
          equipment: equipment,
          activeInjuries: activeInjuries,
          isLowCheckin: isLow,
          durationMin: effectiveDuration,
        ),
        const SizedBox(height: 10),
        _buildSuggestedCard(
          type: SuggestedWorkoutType.coreAbs,
          subtitle: '4 bài tập · ${effectiveDuration == 5 ? 5 : 10} phút · Cơ trọng tâm và múi bụng',
          icon: Icons.shield_rounded,
          iconColor: const Color(0xFFEA580C),
          bgColor: const Color(0xFFFFEDD5),
          safeExercises: safeExercises,
          location: location,
          equipment: equipment,
          activeInjuries: activeInjuries,
          isLowCheckin: isLow,
          durationMin: effectiveDuration == 5 ? 5 : 10,
        ),
      ],
    );
  }

  Widget _buildDurationChip(
    int minutes,
    String label, {
    required bool enabled,
    required bool selected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected && enabled,
        onSelected: enabled
            ? (_) => setState(() => _selectedDuration = minutes)
            : null,
        selectedColor: AppColors.primaryLight,
        backgroundColor: AppColors.surface,
        disabledColor: AppColors.placeholder.withValues(alpha: 0.3),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: selected && enabled ? FontWeight.w700 : FontWeight.w500,
          color: !enabled
              ? AppColors.textSecondary.withValues(alpha: 0.4)
              : (selected ? AppColors.primary : AppColors.textSecondary),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected && enabled ? AppColors.primary : AppColors.border,
            width: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildRedoCard(
    SessionView todaySession,
    List<ExerciseResponse> allExercises,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.replay_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tập lại buổi hôm nay',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${todaySession.title} · ${todaySession.durationMin} phút · ${todaySession.items.length} bài',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Tập lại buổi này',
            icon: const Icon(
              Icons.play_arrow_rounded,
              color: AppColors.surface,
              size: 20,
            ),
            height: 44,
            onPressed: () {
              final exercisesById = {for (final e in allExercises) e.id: e};
              final setup = buildRedoWorkoutSetup(
                originalSession: todaySession,
                exercisesById: exercisesById,
              );
              _startSetup(setup);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedCard({
    required SuggestedWorkoutType type,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required List<ExerciseResponse> safeExercises,
    required String? location,
    required List<String> equipment,
    required List<String> activeInjuries,
    required bool isLowCheckin,
    required int durationMin,
  }) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: InkWell(
        onTap: () {
          final setup = buildSuggestedWorkoutSetup(
            exercises: safeExercises,
            type: type,
            location: location,
            userEquipment: equipment,
            activeInjuries: activeInjuries,
            isLowCheckin: isLowCheckin,
            durationMin: durationMin,
          );
          _startSetup(setup);
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // TAB 2: Tự chọn bài
  // ---------------------------------------------------------------------------
  Widget _buildCustomTab({
    required List<ExerciseResponse> allExercises,
    required String? location,
    required List<String> equipment,
    required List<String> activeInjuries,
  }) {
    // 4. Tab "Tự chọn bài": liệt kê ĐỦ bài isActive
    final activeExercises = allExercises.where((e) => e.isActive).toList();

    // Lọc theo tìm kiếm không dấu
    final queryNorm = removeVietnameseDiacritics(_searchQuery);
    var filtered = activeExercises.where((e) {
      if (queryNorm.isNotEmpty) {
        final nameNorm = removeVietnameseDiacritics(e.nameVi);
        if (!nameNorm.contains(queryNorm)) return false;
      }

      if (_selectedMuscleFilter == 'all') return true;
      if (_selectedMuscleFilter == 'legs_glutes') {
        return e.primaryMuscle == 'legs' || e.primaryMuscle == 'glutes';
      }
      if (_selectedMuscleFilter == 'arms_shoulders') {
        return e.primaryMuscle == 'arms' || e.primaryMuscle == 'shoulders';
      }
      if (_selectedMuscleFilter == 'chest_back') {
        return e.primaryMuscle == 'chest' || e.primaryMuscle == 'back';
      }
      if (_selectedMuscleFilter == 'core') {
        return e.primaryMuscle == 'core';
      }
      if (_selectedMuscleFilter == 'cardio') {
        return e.primaryMuscle == 'cardio';
      }
      return true;
    }).toList();

    final isGym = location == 'gym';
    final injurySet = activeInjuries.toSet();
    final equipSet = equipment.toSet();

    // Sắp xếp: bài phù hợp trước, bài cần dụng cụ sau, bài chống chỉ định cuối
    int rankOf(ExerciseResponse e) {
      final isContra = e.contraindications.any(injurySet.contains);
      if (isContra) return 2; // chống chỉ định cuối

      if (!isGym) {
        final missing =
            e.equipment.where((eq) => eq != 'mat' && !equipSet.contains(eq));
        if (missing.isNotEmpty) return 1; // cần dụng cụ sau
      }

      return 0; // phù hợp trước
    }

    filtered.sort((a, b) => rankOf(a).compareTo(rankOf(b)));

    final selectedCount = _customSelections.length;

    return Column(
      children: [
        // Ô tìm kiếm bài tập không dấu
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1.0),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                    decoration: const InputDecoration(
                      hintText: 'Tìm bài tập (không dấu)...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Icon(
                      Icons.cancel_rounded,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Filter chips nhóm cơ
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterChip('all', 'Tất cả'),
              _buildFilterChip('legs_glutes', 'Chân & mông'),
              _buildFilterChip('arms_shoulders', 'Tay & vai'),
              _buildFilterChip('chest_back', 'Ngực & lưng'),
              _buildFilterChip('core', 'Bụng'),
              _buildFilterChip('cardio', 'Cardio'),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Danh sách bài
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'Không tìm thấy bài tập phù hợp.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final exercise = filtered[index];
                    final isSelected = _customSelections.containsKey(
                      exercise.id,
                    );
                    final matchingInjuries = exercise.contraindications
                        .where(injurySet.contains)
                        .toList();
                    final isContraindicated = matchingInjuries.isNotEmpty;
                    final missingEquipment = isGym
                        ? <String>[]
                        : exercise.equipment
                            .where(
                              (eq) => eq != 'mat' && !equipSet.contains(eq),
                            )
                            .toList();
                    final isMissingEquipment =
                        !isContraindicated && missingEquipment.isNotEmpty;

                    return _buildExerciseSelectableTile(
                      exercise,
                      isSelected,
                      isContraindicated: isContraindicated,
                      contraindicatedArea: matchingInjuries.isNotEmpty
                          ? _formatBodyAreaVi(matchingInjuries.first)
                          : null,
                      isMissingEquipment: isMissingEquipment,
                      missingEquipmentLabel: isMissingEquipment
                          ? _formatMissingEquipmentVi(missingEquipment)
                          : null,
                    );
                  },
                ),
        ),

        // Nút "Bắt đầu (n bài)" cố định ở đáy
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.border, width: 1.0),
            ),
          ),
          child: PrimaryButton(
            key: const ValueKey('start-custom-workout-button'),
            label: selectedCount == 0
                ? 'Chọn ít nhất 1 bài tập'
                : 'Bắt đầu ($selectedCount bài)',
            icon: const Icon(
              Icons.play_arrow_rounded,
              color: AppColors.surface,
            ),
            onPressed: selectedCount == 0
                ? null
                : () {
                    final items = <WorkoutPlanItem>[];
                    for (final entry in _customSelections.entries) {
                      final ex = allExercises.firstWhere(
                        (e) => e.id == entry.key,
                      );
                      final cfg = entry.value;
                      items.add(
                        WorkoutPlanItem(
                          exerciseId: ex.id,
                          nameVi: ex.nameVi,
                          sets: cfg.sets,
                          reps: cfg.reps,
                          durationSec: cfg.durationSec,
                          restSec: 30,
                          exercise: ex,
                        ),
                      );
                    }

                    final setup = buildCustomWorkoutSetup(selectedItems: items);
                    _startSetup(setup);
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedMuscleFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedMuscleFilter = key),
        selectedColor: AppColors.primaryLight,
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseSelectableTile(
    ExerciseResponse exercise,
    bool isSelected, {
    required bool isContraindicated,
    required String? contraindicatedArea,
    required bool isMissingEquipment,
    required String? missingEquipmentLabel,
  }) {
    final isDuration = exercise.tracking == 'duration';
    final hasCamera = exercise.camera != null;

    final config = _customSelections[exercise.id];
    final sets = config?.sets ?? 3;
    final reps = config?.reps ?? (isDuration ? null : 12);
    final durationSec = config?.durationSec ?? (isDuration ? 30 : null);

    final card = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        isSelected: isSelected && !isContraindicated,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            InkWell(
              onTap: isContraindicated
                  ? null
                  : () {
                      setState(() {
                        if (isSelected) {
                          _customSelections.remove(exercise.id);
                        } else {
                          _customSelections[exercise.id] = (
                            sets: 3,
                            reps: isDuration ? null : 12,
                            durationSec: isDuration ? 30 : null,
                          );
                        }
                      });
                    },
              child: Row(
                children: [
                  Icon(
                    isContraindicated
                        ? Icons.block_rounded
                        : (isSelected
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded),
                    color: isContraindicated
                        ? AppColors.textSecondary.withValues(alpha: 0.35)
                        : (isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ExerciseImage(
                      slug: exercise.slug,
                      thumbnailUrl: exercise.thumbnailUrl,
                      width: 44,
                      height: 44,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.nameVi,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              isDuration
                                  ? 'Tính theo thời gian'
                                  : 'Tính theo lần',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (hasCamera) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.videocam_outlined,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ],
                          ],
                        ),
                        if (isContraindicated && contraindicatedArea != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Không hợp với chấn thương $contraindicatedArea',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ] else if (isMissingEquipment && missingEquipmentLabel != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              missingEquipmentLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Controls chỉnh hiệp và lần/giây khi đã tích chọn
            if (isSelected && !isContraindicated) ...[
              const Divider(height: 16, color: AppColors.border),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Hiệp
                  Row(
                    children: [
                      const Text(
                        'Hiệp: ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      _stepperButton(
                        icon: Icons.remove,
                        onTap: () {
                          if (sets > 1) {
                            setState(() {
                              _customSelections[exercise.id] = (
                                sets: sets - 1,
                                reps: reps,
                                durationSec: durationSec,
                              );
                            });
                          }
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$sets',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _stepperButton(
                        icon: Icons.add,
                        onTap: () {
                          if (sets < 10) {
                            setState(() {
                              _customSelections[exercise.id] = (
                                sets: sets + 1,
                                reps: reps,
                                durationSec: durationSec,
                              );
                            });
                          }
                        },
                      ),
                    ],
                  ),

                  // Lần hoặc Giây
                  Row(
                    children: [
                      Text(
                        isDuration ? 'Giây: ' : 'Lần: ',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      _stepperButton(
                        icon: Icons.remove,
                        onTap: () {
                          if (isDuration) {
                            if ((durationSec ?? 30) > 10) {
                              setState(() {
                                _customSelections[exercise.id] = (
                                  sets: sets,
                                  reps: reps,
                                  durationSec: (durationSec ?? 30) - 5,
                                );
                              });
                            }
                          } else {
                            if ((reps ?? 12) > 1) {
                              setState(() {
                                _customSelections[exercise.id] = (
                                  sets: sets,
                                  reps: (reps ?? 12) - 2,
                                  durationSec: durationSec,
                                );
                              });
                            }
                          }
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          isDuration
                              ? '${durationSec ?? 30}s'
                              : '${reps ?? 12}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _stepperButton(
                        icon: Icons.add,
                        onTap: () {
                          if (isDuration) {
                            if ((durationSec ?? 30) < 300) {
                              setState(() {
                                _customSelections[exercise.id] = (
                                  sets: sets,
                                  reps: reps,
                                  durationSec: (durationSec ?? 30) + 5,
                                );
                              });
                            }
                          } else {
                            if ((reps ?? 12) < 100) {
                              setState(() {
                                _customSelections[exercise.id] = (
                                  sets: sets,
                                  reps: (reps ?? 12) + 2,
                                  durationSec: durationSec,
                                );
                              });
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    return isContraindicated ? Opacity(opacity: 0.45, child: card) : card;
  }

  Widget _stepperButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.placeholder,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border, width: 1.0),
        ),
        child: Icon(icon, size: 16, color: AppColors.textPrimary),
      ),
    );
  }
}

String _formatBodyAreaVi(String area) {
  switch (area.toLowerCase()) {
    case 'lower_back':
      return 'lưng dưới';
    case 'knee':
      return 'gối';
    case 'shoulder':
      return 'vai';
    case 'neck':
      return 'cổ';
    case 'wrist':
      return 'cổ tay';
    case 'ankle':
      return 'cổ chân';
    case 'hip':
      return 'hông';
    case 'other':
      return 'khác';
    default:
      return area;
  }
}

String _formatMissingEquipmentVi(List<String> missing) {
  final names = missing.map((eq) {
    switch (eq) {
      case 'dumbbell':
        return 'tạ đơn';
      case 'resistance_band':
        return 'dây kháng lực';
      case 'pullup_bar':
        return 'xà đơn';
      default:
        return eq;
    }
  }).toList();
  return 'Cần ${names.join(', ')}';
}
