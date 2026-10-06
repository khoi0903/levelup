import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../onboarding/domain/models/plan_models.dart';
import '../../../onboarding/presentation/controllers/onboarding_controller.dart';
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

  // Lưu cấu hình bài tập tự chọn: exerciseId -> {sets, reps, durationSec}
  final Map<String, ({int sets, int? reps, int? durationSec})>
      _customSelections = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    final workoutRepo = ref.watch(workoutRepositoryProvider);
    final userAsync = ref.watch(userStatusFutureProvider);
    final planRepo = ref.watch(planRepositoryProvider);

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: FutureBuilder<(List<ExerciseResponse>, PlanView)>(
            future: Future.wait([
              workoutRepo.getExercises(),
              planRepo.getCurrentPlan(),
            ]).then((values) => (
                  values[0] as List<ExerciseResponse>,
                  values[1] as PlanView,
                )),
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
                        message: 'Không tải được danh sách bài tập. Thử lại sau.',
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Thử lại',
                        onPressed: () => setState(() {}),
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
              final todayStr = localDateString(DateTime.now());

              // Tìm buổi hôm nay đã hoàn thành nếu có
              final todayDoneSession = plan.sessions.cast<SessionView?>().firstWhere(
                    (s) =>
                        s != null &&
                        s.scheduledDate == todayStr &&
                        s.status == 'completed',
                    orElse: () => null,
                  );

              // Lọc bài tập an toàn theo nơi tập, dụng cụ
              final safeExercises = filterExercisesForUser(
                exercises: allExercises,
                location: location,
                userEquipment: equipment,
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

                  // Tabs: Gợi ý / Tự chọn
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
                        ),

                        // Tab 2: Tự chọn bài
                        _buildCustomTab(
                          safeExercises: safeExercises,
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
  // TAB 1: Buổi gợi ý & Tập lại hôm nay
  // ---------------------------------------------------------------------------
  Widget _buildSuggestedTab({
    required List<ExerciseResponse> safeExercises,
    required SessionView? todayDoneSession,
    required List<ExerciseResponse> allExercises,
    required String? location,
    required List<String> equipment,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
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
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),

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
        ),
        const SizedBox(height: 10),
        _buildSuggestedCard(
          type: SuggestedWorkoutType.fullBody,
          subtitle: '4 bài tập · 15 phút · Cân bằng toàn bộ cơ thể',
          icon: Icons.accessibility_new_rounded,
          iconColor: AppColors.primary,
          bgColor: AppColors.primaryLight,
          safeExercises: safeExercises,
          location: location,
          equipment: equipment,
        ),
        const SizedBox(height: 10),
        _buildSuggestedCard(
          type: SuggestedWorkoutType.legsGlutes,
          subtitle: '4 bài tập · 15 phút · Đùi, bắp chân và mông săn chắc',
          icon: Icons.directions_run_rounded,
          iconColor: const Color(0xFF059669),
          bgColor: const Color(0xFFD1FAE5),
          safeExercises: safeExercises,
          location: location,
          equipment: equipment,
        ),
        const SizedBox(height: 10),
        _buildSuggestedCard(
          type: SuggestedWorkoutType.armsShoulders,
          subtitle: '4 bài tập · 15 phút · Tay trước, tay sau và vai',
          icon: Icons.fitness_center_rounded,
          iconColor: const Color(0xFF7C3AED),
          bgColor: const Color(0xFFEDE9FE),
          safeExercises: safeExercises,
          location: location,
          equipment: equipment,
        ),
        const SizedBox(height: 10),
        _buildSuggestedCard(
          type: SuggestedWorkoutType.coreAbs,
          subtitle: '4 bài tập · 10 phút · Cơ trọng tâm và múi bụng',
          icon: Icons.shield_rounded,
          iconColor: const Color(0xFFEA580C),
          bgColor: const Color(0xFFFFEDD5),
          safeExercises: safeExercises,
          location: location,
          equipment: equipment,
        ),
      ],
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
              final exercisesById = {
                for (final e in allExercises) e.id: e,
              };
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
  // TAB 2: Tự chọn bài
  // ---------------------------------------------------------------------------
  Widget _buildCustomTab({
    required List<ExerciseResponse> safeExercises,
  }) {
    // Lọc theo tìm kiếm không dấu
    final queryNorm = removeVietnameseDiacritics(_searchQuery);
    var filtered = safeExercises.where((e) {
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
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
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
                    final isSelected = _customSelections.containsKey(exercise.id);
                    return _buildExerciseSelectableTile(exercise, isSelected);
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
                      final ex = safeExercises.firstWhere((e) => e.id == entry.key);
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

                    final setup = buildCustomWorkoutSetup(
                      selectedItems: items,
                    );
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
    bool isSelected,
  ) {
    final isDuration = exercise.tracking == 'duration';
    final hasCamera = exercise.camera != null;

    final config = _customSelections[exercise.id];
    final sets = config?.sets ?? 3;
    final reps = config?.reps ?? (isDuration ? null : 12);
    final durationSec = config?.durationSec ?? (isDuration ? 30 : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        isSelected: isSelected,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            InkWell(
              onTap: () {
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
                    isSelected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    size: 24,
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
                              isDuration ? 'Tính theo thời gian' : 'Tính theo lần',
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
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Controls chỉnh hiệp và lần/giây khi đã tích chọn
            if (isSelected) ...[
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
                          isDuration ? '${durationSec ?? 30}s' : '${reps ?? 12}',
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
  }

  Widget _stepperButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
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
