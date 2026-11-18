import '../../../product/presentation/widgets/product_widgets.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme_mode.dart';
import '../../../../core/api/api_client.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_palette.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/day_times_editor.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/selection_chip.dart';

import 'package:fitness_app/features/notifications/presentation/controllers/notifications_controller.dart';

import '../../../../core/voice/voice_commands.dart';
import '../../../../core/voice/voice_models.dart';
import '../../../../core/voice/voice_provider.dart';
import '../../../home/presentation/controllers/home_controller.dart';
import '../../../workout/data/camera/auto_camera_setting.dart';
import '../../../body/presentation/widgets/body_profile_section.dart';
import '../controllers/user_controller.dart';
import '../../domain/models/me_response.dart';
import '../../domain/models/settings_request.dart';
import '../../../shell/presentation/controllers/shell_controller.dart';

/// Màn hình Hồ sơ & Cài đặt (Tab Tôi).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  /// Bật điều khiển giọng nói: xin quyền micro trước, không được thì giữ tắt.
  Future<void> _setVoiceCommands(bool enabled) async {
    final notifier = ref.read(voiceSettingsProvider.notifier);
    if (!enabled) {
      await notifier.setVoiceCommands(false);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(voiceCommandListenerProvider).init();
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Không dùng được micro hoặc máy chưa có nhận dạng giọng nói. '
            'Hãy cho phép LevelUp dùng micro trong Cài đặt.',
          ),
        ),
      );
      return;
    }
    await notifier.setVoiceCommands(true);
  }

  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  String _lastSavedName = '';

  String _selectedCoachStyle = 'supportive';
  String _goal = 'get_healthier';
  int _sessionMinutes = 15;
  String _location = 'home';
  final Set<String> _equipment = {};

  bool _notificationsEnabled = true;
  bool _quietHoursEnabled = true;
  int _maxPerDay = 2;
  bool _waterReminder = false;
  bool _shareWeight = false;
  bool _shareMeasurements = false;
  bool _sharePhotos = false;
  bool _shareMeals = false;
  final Set<int> _activeWeekdays = {};
  String _slot = 'evening';

  /// Giờ riêng theo thứ, chỉ những ngày đã đổi khỏi giờ mặc định của khung.
  final Map<int, String> _dayTimes = {};

  Timer? _scheduleDebounceTimer;
  bool _isSavingSchedule = false;

  MeResponse? _lastServerMe;
  bool _isSwitchingTab = false;

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus && !_isSwitchingTab) {
        _saveName(_nameController.text);
      }
    });
  }

  void _initFields(MeResponse me) {
    _lastServerMe = me;
    _nameController.text = me.displayName;
    _lastSavedName = me.displayName;
    _selectedCoachStyle = me.profile?.coachStyle ?? 'supportive';
    _goal = me.profile?.goal ?? 'get_healthier';
    final minutes = me.profile?.sessionMinutes ?? 15;
    _sessionMinutes = minutes <= 15 ? 15 : minutes;

    _location = me.profile?.location ?? 'home';
    _equipment.clear();
    _equipment.addAll(me.profile?.equipment ?? const []);

    final notif = me.settings.notifications;
    _notificationsEnabled = notif.pushEnabled;
    _quietHoursEnabled =
        notif.quietStart == '22:00' && notif.quietEnd == '07:00';
    _maxPerDay = notif.maxPerDay;
    _waterReminder = notif.waterReminder;

    final sharing = me.settings.sharing;
    _shareWeight = sharing.weight;
    _shareMeasurements = sharing.measurements;
    _sharePhotos = sharing.photos;
    _shareMeals = sharing.meals;

    _activeWeekdays.clear();
    _dayTimes.clear();
    for (final slot in me.settings.availability) {
      _activeWeekdays.add(slot.weekday);
      if (slot.time != null) _dayTimes[slot.weekday] = slot.time!;
    }
    if (me.settings.availability.isNotEmpty) {
      _slot = me.settings.availability.first.slot;
    }
    if (_activeWeekdays.isEmpty) {
      _activeWeekdays.addAll([1, 3, 5]);
    }
  }

  @override
  void dispose() {
    _scheduleDebounceTimer?.cancel();
    _nameFocusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _nameController.text = _lastSavedName;
      return;
    }
    if (trimmed == _lastSavedName) return;

    final previousName = _lastSavedName;
    _lastSavedName = trimmed;
    final success = await ref
        .read(settingsControllerProvider.notifier)
        .patchSettings(SettingsRequest(displayName: trimmed));
    if (!success && mounted) {
      _nameController.text = previousName;
      _lastSavedName = previousName;
    }
  }

  Future<void> _patch({
    required SettingsRequest request,
    required VoidCallback onRollback,
  }) async {
    final success = await ref
        .read(settingsControllerProvider.notifier)
        .patchSettings(request);
    if (!success && mounted) {
      setState(onRollback);
    }
  }

  Future<void> _selectGoal(String newGoal) async {
    if (_goal == newGoal) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Đổi mục tiêu?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Mục tiêu calo sẽ tính lại từ hôm nay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            key: const ValueKey('confirm-goal-change'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Xác nhận',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: context.colors.primary,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final old = _goal;
      setState(() => _goal = newGoal);
      _patch(
        request: SettingsRequest(goal: newGoal),
        onRollback: () => _goal = old,
      );
    }
  }

  void _triggerScheduleAutosave() {
    _scheduleDebounceTimer?.cancel();
    _scheduleDebounceTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        _saveSchedule();
      }
    });
  }

  Future<void> _saveSchedule() async {
    _scheduleDebounceTimer?.cancel();
    if (_activeWeekdays.isEmpty) return;
    setState(() => _isSavingSchedule = true);
    final availabilityList = _activeWeekdays.map((w) {
      return UserAvailabilitySlot(weekday: w, slot: _slot, time: _dayTimes[w]);
    }).toList()..sort((a, b) => a.weekday.compareTo(b.weekday));

    final oldWeekdays = Set<int>.from(_activeWeekdays);
    final oldSlot = _slot;
    final oldDayTimes = Map<int, String>.from(_dayTimes);

    final success = await ref
        .read(settingsControllerProvider.notifier)
        .patchSettings(SettingsRequest(availability: availabilityList));
    if (mounted) {
      setState(() => _isSavingSchedule = false);
      if (!success) {
        setState(() {
          _activeWeekdays.clear();
          _activeWeekdays.addAll(oldWeekdays);
          _slot = oldSlot;
          _dayTimes
            ..clear()
            ..addAll(oldDayTimes);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userStatusFutureProvider);
    final settingsState = ref.watch(settingsControllerProvider);
    final settingsNotifier = ref.read(settingsControllerProvider.notifier);
    ref.watch(appShellCurrentBranchProvider);

    ref.listen<int>(appShellCurrentBranchProvider, (previous, next) {
      if (previous == 4 && next != 4) {
        // Rời tab profile -> hủy bỏ các thay đổi tên chưa lưu & hoàn tác về giá trị đã lưu
        _isSwitchingTab = true;
        if (_nameFocusNode.hasFocus) {
          _nameFocusNode.unfocus();
        }
        _nameController.text = _lastSavedName;
        _isSwitchingTab = false;
        _lastServerMe = null;
      } else if (next == 4) {
        // Quay lại tab profile -> hoàn tác text field về giá trị đã lưu
        _nameController.text = _lastSavedName;
        _lastServerMe = null;
      }
    });

    final me = userAsync.valueOrNull ?? ref.watch(currentUserProvider);

    ref.listen<AsyncValue<MeResponse>>(userStatusFutureProvider, (prev, next) {
      if (next.hasError && me != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(mapErrorMessage(next.error)),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    });

    ref.listen<SettingsState>(settingsControllerProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                mapErrorMessage(next.error),
                key: const ValueKey('settings-error-banner'),
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
      }
      final message = next.successMessage;
      if (message == null || message == prev?.successMessage) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              message,
              key: const ValueKey('settings-success-banner'),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      settingsNotifier.clearSuccess();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hồ sơ & Cài đặt',
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
          child: me == null
              ? (userAsync.hasError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          mapErrorMessage(userAsync.error),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.colors.textSecondary),
                        ),
                      ),
                    )
                  : const ProfileScreenSkeleton())
              : Builder(
                  builder: (context) {
                    if (_lastServerMe == null || _lastServerMe != me) {
                      _initFields(me);
                    }
                    final isReloading = userAsync.isLoading;
                    return Column(
                      children: [
                        ReloadingIndicator(isReloading: isReloading),
                        Expanded(
                          child: RefreshIndicator(
                            color: context.colors.primary,
                            onRefresh: () async {
                              ref.invalidate(userStatusFutureProvider);
                            },
                            child: _buildSettingsList(
                              context,
                              me,
                              settingsState,
                              settingsNotifier,
                            ),
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

  Widget _buildSettingsList(
    BuildContext context,
    MeResponse me,
    SettingsState state,
    SettingsNotifier notifier,
  ) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
      children: [
        const ProductProfileCards(),
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
              key: const ValueKey('settings-error-banner'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.errorText,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // User avatar header
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.colors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: context.colors.primary,
                  size: 34,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      me.displayName,
                      key: const ValueKey('profile-display-name'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mục tiêu: ${_formatGoal(me.profile?.goal)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick navigation shortcuts
        Row(
          children: [
            Expanded(
              child: _buildNavTile(
                icon: Icons.military_tech_rounded,
                label: 'Huy hiệu',
                onTap: () => context.push('/achievements'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildNavTile(
                icon: Icons.local_fire_department_rounded,
                label: 'Streak',
                onTap: () => context.push('/streak'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildNavTile(
                icon: Icons.analytics_outlined,
                label: 'Tổng kết',
                onTap: () => context.push('/reviews/latest'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const BodyProfileCards(),
        const SizedBox(height: 20),

        // Vùng đang đau / chấn thương (ẩn nếu rỗng)
        if (me.activeInjuries.isNotEmpty) ...[
          Text(
            'Vùng đang đau / chấn thương',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            key: const ValueKey('active-injuries-card'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                for (int i = 0; i < me.activeInjuries.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: context.colors.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _capitalizeFirst(me.activeInjuries[i].label),
                            key: ValueKey(
                              'injury-label-${me.activeInjuries[i].bodyArea}',
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          key: ValueKey(
                            'injury-recovered-${me.activeInjuries[i].bodyArea}',
                          ),
                          onPressed: () => _confirmRecovered(
                            context,
                            ref,
                            me.activeInjuries[i],
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: context.colors.primary,
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('Đã khỏi'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // 1. Tên hiển thị
        Text(
          'Tên hiển thị',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          textInputAction: TextInputAction.done,
          onSubmitted: (val) => _saveName(val),
          decoration: InputDecoration(
            hintText: 'Nhập tên của bạn...',
            filled: true,
            fillColor: context.colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.colors.border),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Cơ thể: chiều cao, cân nặng, vóc dáng, nhóm cơ ưu tiên, xem lại hướng dẫn
        BodySettingsCard(me: me),
        const SizedBox(height: 20),

        // Mục tiêu: đạt rồi thì đổi mục tiêu mới, calo tính lại từ hôm nay
        Text(
          'Mục tiêu',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Đổi mục tiêu thì mục tiêu calo tính lại từ hôm nay, kế hoạch tập theo mục tiêu mới từ tuần sau.',
          style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['lose_fat', 'build_muscle', 'get_healthier', 'maintain']
              .map((g) {
                final isSelected = _goal == g;
                return ChoiceChip(
                  key: ValueKey('settings-goal-$g'),
                  label: Text(_formatGoal(g)),
                  selected: isSelected,
                  showCheckmark: false,
                  selectedColor: context.colors.primaryLight,
                  backgroundColor: context.colors.surface,
                  side: BorderSide(
                    color: isSelected ? context.colors.primary : context.colors.border,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? context.colors.primary
                        : context.colors.textPrimary,
                  ),
                  onSelected: (_) => _selectGoal(g),
                );
              })
              .toList(),
        ),
        const SizedBox(height: 20),

        // 2. Phong cách coach
        Text(
          'Phong cách Coach',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        _buildCoachStyleTile(
          title: 'Động viên',
          desc: 'Nhẹ nhàng, thấu hiểu, khích lệ từng tiến bộ nhỏ',
          value: 'supportive',
        ),
        const SizedBox(height: 6),
        _buildCoachStyleTile(
          title: 'Nghiêm khắc',
          desc: 'Trực diện, kỷ luật, nhắc nhở nghiêm túc khi lười',
          value: 'strict',
        ),
        const SizedBox(height: 6),
        _buildCoachStyleTile(
          title: 'Hài hước',
          desc: 'Vui vẻ, hóm hỉnh, tạo cảm giác thoải mái khi tập',
          value: 'funny',
        ),
        const SizedBox(height: 20),

        // Mục mới: Nơi tập & dụng cụ
        _buildLocationAndEquipmentSection(),
        const SizedBox(height: 20),

        // 3. Thời lượng mỗi buổi tập
        Text(
          'Thời lượng mỗi buổi tập',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Cùng mốc với onboarding (15/20/30/45)
            Expanded(child: _buildMinutesChip(15, '10–15 phút')),
            const SizedBox(width: 6),
            Expanded(child: _buildMinutesChip(20, '20 phút')),
            const SizedBox(width: 6),
            Expanded(child: _buildMinutesChip(30, '30 phút')),
            const SizedBox(width: 6),
            Expanded(child: _buildMinutesChip(45, '45+ phút')),
          ],
        ),
        const SizedBox(height: 20),

        // 4. Lịch rảnh trong tuần
        Text(
          'Lịch rảnh trong tuần',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.colors.primaryLight.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: context.colors.primary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Áp dụng ngay cho các ngày còn lại của tuần này.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildWeekdaySelector(),
        const SizedBox(height: 12),
        Text(
          'Giờ tập',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        _buildSlotSelector(),
        const SizedBox(height: 10),
        DayTimesEditor(
          weekdays: _activeWeekdays.toList(),
          slot: _slot,
          times: _dayTimes,
          onChanged: (day, time) {
            setState(() {
              if (time == null) {
                _dayTimes.remove(day);
              } else {
                _dayTimes[day] = time;
              }
            });
            _triggerScheduleAutosave();
          },
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          key: const ValueKey('save-schedule-button'),
          label: _isSavingSchedule ? 'Đang lưu...' : 'Lưu lịch tập',
          onPressed: _isSavingSchedule ? null : _saveSchedule,
        ),
        const SizedBox(height: 20),

        // Giao diện: theo hệ thống / sáng / tối (lưu trên máy)
        Text(
          'Giao diện',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildThemeChip(ThemeMode.system, 'Theo hệ thống')),
            const SizedBox(width: 6),
            Expanded(child: _buildThemeChip(ThemeMode.light, 'Sáng')),
            const SizedBox(width: 6),
            Expanded(child: _buildThemeChip(ThemeMode.dark, 'Tối')),
          ],
        ),
        const SizedBox(height: 20),

        // 5. Cài đặt thông báo
        Text(
          'Cài đặt thông báo',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text(
                  'Bật thông báo nhắc tập',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Nhắc trước giờ tập đã hẹn',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
                value: _notificationsEnabled,
                activeThumbColor: context.colors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) async {
                  if (val) {
                    final pushService = ref.read(pushServiceProvider);
                    final hasPermission = await pushService.hasPermission();
                    if (!context.mounted) return;
                    if (!hasPermission) {
                      final granted = await pushService.requestPermission();
                      if (!context.mounted) return;
                      if (!granted) {
                        setState(() => _notificationsEnabled = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Vui lòng mở Cài đặt điện thoại để cho phép LevelUp gửi thông báo.',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                    }
                  }
                  final old = _notificationsEnabled;
                  setState(() => _notificationsEnabled = val);
                  _patch(
                    request: SettingsRequest(
                      notifications: NotificationsUpdate(pushEnabled: val),
                    ),
                    onRollback: () => _notificationsEnabled = old,
                  );
                },
              ),
              Divider(color: context.colors.border, height: 1),
              SwitchListTile(
                title: const Text(
                  'Giờ yên lặng (22:00 – 07:00)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Không gửi thông báo trong thời gian này',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
                value: _quietHoursEnabled,
                activeThumbColor: context.colors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  final old = _quietHoursEnabled;
                  setState(() => _quietHoursEnabled = val);
                  _patch(
                    request: SettingsRequest(
                      notifications: NotificationsUpdate(
                        quietStart: val ? '22:00' : '00:00',
                        quietEnd: val ? '07:00' : '00:00',
                      ),
                    ),
                    onRollback: () => _quietHoursEnabled = old,
                  );
                },
              ),
              Divider(color: context.colors.border, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Số thông báo tối đa mỗi ngày',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Nhắc tập, nhắc tập bù, tin buddy…',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('settings-max-per-day-minus'),
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      color: context.colors.primary,
                      onPressed: _maxPerDay > 1
                          ? () => _updateMaxPerDay(_maxPerDay - 1)
                          : null,
                    ),
                    Text(
                      '$_maxPerDay',
                      key: const ValueKey('settings-max-per-day'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('settings-max-per-day-plus'),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      color: context.colors.primary,
                      onPressed: _maxPerDay < 5
                          ? () => _updateMaxPerDay(_maxPerDay + 1)
                          : null,
                    ),
                  ],
                ),
              ),
              Divider(color: context.colors.border, height: 1),
              SwitchListTile(
                key: const ValueKey('settings-water-reminder'),
                title: const Text(
                  'Nhắc uống nước',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Trưa và chiều nếu bạn uống chưa đủ. Tối đa 2 lần/ngày, không tính vào số thông báo ở trên',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
                value: _waterReminder,
                activeThumbColor: context.colors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  final old = _waterReminder;
                  setState(() => _waterReminder = val);
                  _patch(
                    request: SettingsRequest(
                      notifications: NotificationsUpdate(waterReminder: val),
                    ),
                    onRollback: () => _waterReminder = old,
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 6. Chia sẻ với buddy
        Text(
          'Chia sẻ với bạn đồng hành (Buddy)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text(
                  'Cân nặng hiện tại',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                value: _shareWeight,
                activeThumbColor: context.colors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  final old = _shareWeight;
                  setState(() => _shareWeight = val);
                  _patch(
                    request: SettingsRequest(
                      sharing: SharingUpdate(weight: val),
                    ),
                    onRollback: () => _shareWeight = old,
                  );
                },
              ),
              Divider(color: context.colors.border, height: 1),
              SwitchListTile(
                title: const Text(
                  'Số đo cơ thể',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                value: _shareMeasurements,
                activeThumbColor: context.colors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  final old = _shareMeasurements;
                  setState(() => _shareMeasurements = val);
                  _patch(
                    request: SettingsRequest(
                      sharing: SharingUpdate(measurements: val),
                    ),
                    onRollback: () => _shareMeasurements = old,
                  );
                },
              ),
              Divider(color: context.colors.border, height: 1),
              SwitchListTile(
                title: const Text(
                  'Ảnh chụp tiến độ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                value: _sharePhotos,
                activeThumbColor: context.colors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  final old = _sharePhotos;
                  setState(() => _sharePhotos = val);
                  _patch(
                    request: SettingsRequest(
                      sharing: SharingUpdate(photos: val),
                    ),
                    onRollback: () => _sharePhotos = old,
                  );
                },
              ),
              Divider(color: context.colors.border, height: 1),
              SwitchListTile(
                title: const Text(
                  'Lượng calo đã nạp hôm nay',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                value: _shareMeals,
                activeThumbColor: context.colors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  final old = _shareMeals;
                  setState(() => _shareMeals = val);
                  _patch(
                    request: SettingsRequest(
                      sharing: SharingUpdate(meals: val),
                    ),
                    onRollback: () => _shareMeals = old,
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 7. Giọng đọc khi tập (lưu SharedPreferences cục bộ)
        _buildVoiceSettingsSection(context),
        const SizedBox(height: 24),

        // Đăng xuất (xóa token dev)
        Center(
          child: TextButton.icon(
            icon: const Icon(
              Icons.logout_rounded,
              color: Colors.redAccent,
              size: 20,
            ),
            label: const Text(
              'Đăng xuất',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            onPressed: () async {
              await notifier.logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        Divider(color: context.colors.border, height: 1),
        const SizedBox(height: 12),

        // Xoá tài khoản (tách khỏi các cài đặt khác)
        Center(
          child: TextButton.icon(
            key: const ValueKey('delete-account-button'),
            icon: const Icon(
              Icons.delete_forever,
              color: Color(0xFFDC2626),
              size: 20,
            ),
            label: const Text(
              'Xoá tài khoản',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            onPressed: () => _showDeleteAccountDialogs(context),
          ),
        ),
        const SizedBox(height: 16),

        // Link nhỏ "Chính sách quyền riêng tư"
        Center(
          child: TextButton(
            key: const ValueKey('privacy-policy-link'),
            onPressed: () => _openPrivacyPolicy(context),
            child: Text(
              'Chính sách quyền riêng tư',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _updateMaxPerDay(int newVal) {
    final old = _maxPerDay;
    setState(() => _maxPerDay = newVal);
    _patch(
      request: SettingsRequest(
        notifications: NotificationsUpdate(maxPerDay: newVal),
      ),
      onRollback: () => _maxPerDay = old,
    );
  }

  void _selectCoachStyle(String value) {
    if (_selectedCoachStyle == value) return;
    final old = _selectedCoachStyle;
    setState(() => _selectedCoachStyle = value);
    _patch(
      request: SettingsRequest(coachStyle: value),
      onRollback: () => _selectedCoachStyle = old,
    );
  }

  void _selectSessionMinutes(int minutes) {
    if (_sessionMinutes == minutes) return;
    final old = _sessionMinutes;
    setState(() => _sessionMinutes = minutes);
    _patch(
      request: SettingsRequest(sessionMinutes: minutes),
      onRollback: () => _sessionMinutes = old,
    );
  }

  Widget _buildLocationAndEquipmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nơi tập & dụng cụ',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Lịch tuần này giữ nguyên, tuần sau xếp theo dụng cụ mới.',
          style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
        ),
        const SizedBox(height: 10),
        Text(
          'Nơi tập',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ('home', AppStrings.locationHome),
            ('gym', AppStrings.locationGym),
            ('outdoor', AppStrings.locationOutdoor),
          ].map((item) {
            final (val, label) = item;
            final isSelected = _location == val;
            return SelectionChip(
              key: ValueKey('settings-location-$val'),
              label: label,
              isSelected: isSelected,
              onTap: () {
                if (_location == val) return;
                final old = _location;
                setState(() => _location = val);
                _patch(
                  request: SettingsRequest(location: val),
                  onRollback: () => _location = old,
                );
              },
            );
          }).toList(),
        ),
        if (_location == 'gym') ...[
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('gym-equipment-note'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.colors.primaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.fitness_center_rounded,
                  color: context.colors.primary,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Phòng gym có đủ dụng cụ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 14),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 14, color: context.colors.textPrimary),
              children: [
                TextSpan(
                  text: AppStrings.equipmentLabel,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: AppStrings.equipmentMultipleHint,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              (null, AppStrings.equipmentNone),
              ('dumbbell', AppStrings.equipmentDumbbell),
              ('mat', AppStrings.equipmentMat),
              ('resistance_band', AppStrings.equipmentBand),
              ('pullup_bar', AppStrings.equipmentPullupBar),
            ].map((item) {
              final (key, label) = item;
              final isNone = key == null;
              final isSelected =
                  isNone ? _equipment.isEmpty : _equipment.contains(key);
              return SelectionChip(
                key: ValueKey(
                  isNone
                      ? 'settings-equipment-none'
                      : 'settings-equipment-$key',
                ),
                label: label,
                isSelected: isSelected,
                onTap: () {
                  final old = Set<String>.from(_equipment);
                  setState(() {
                    if (isNone) {
                      _equipment.clear();
                    } else {
                      if (_equipment.contains(key)) {
                        _equipment.remove(key);
                      } else {
                        _equipment.add(key);
                      }
                    }
                  });
                  _patch(
                    request: SettingsRequest(equipment: _equipment.toList()),
                    onRollback: () {
                      _equipment.clear();
                      _equipment.addAll(old);
                    },
                  );
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildWeekdaySelector() {
    final days = [
      (1, 'T2'),
      (2, 'T3'),
      (3, 'T4'),
      (4, 'T5'),
      (5, 'T6'),
      (6, 'T7'),
      (7, 'CN'),
    ];

    return Row(
      children: days.map((day) {
        final (weekday, label) = day;
        final isSelected = _activeWeekdays.contains(weekday);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    if (_activeWeekdays.length > 1) {
                      _activeWeekdays.remove(weekday);
                      _dayTimes.remove(weekday);
                    }
                  } else {
                    _activeWeekdays.add(weekday);
                  }
                });
                _triggerScheduleAutosave();
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? context.colors.buttonFill : context.colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? context.colors.buttonFill : context.colors.border,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : context.colors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSlotSelector() {
    const slots = [
      (
        'early_morning',
        AppStrings.slotEarlyMorningTitle,
        AppStrings.slotEarlyMorningTime,
      ),
      ('noon', AppStrings.slotNoonTitle, AppStrings.slotNoonTime),
      ('evening', AppStrings.slotEveningTitle, AppStrings.slotEveningTime),
      (
        'late_evening',
        AppStrings.slotLateEveningTitle,
        AppStrings.slotLateEveningTime,
      ),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((slot) {
        final (value, title, time) = slot;
        final isSelected = _slot == value;
        return ChoiceChip(
          key: ValueKey('settings-slot-$value'),
          label: Text('$title · $time'),
          selected: isSelected,
          showCheckmark: false,
          selectedColor: context.colors.primaryLight,
          backgroundColor: context.colors.surface,
          side: BorderSide(
            color: isSelected ? context.colors.primary : context.colors.border,
          ),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? context.colors.primary : context.colors.textPrimary,
          ),
          onSelected: (_) {
            setState(() => _slot = value);
            _triggerScheduleAutosave();
          },
        );
      }).toList(),
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: context.colors.primary, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachStyleTile({
    required String title,
    required String desc,
    required String value,
  }) {
    final isSelected = _selectedCoachStyle == value;
    return InkWell(
      onTap: () => _selectCoachStyle(value),
      borderRadius: BorderRadius.circular(AppColors.radiusCard),
      child: GlassCard(
        isSelected: isSelected,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? context.colors.primary : context.colors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? context.colors.primary
                          : context.colors.textPrimary,
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
          ],
        ),
      ),
    );
  }

  Widget _buildThemeChip(ThemeMode mode, String label) {
    final isSelected = ref.watch(themeModeProvider) == mode;
    return InkWell(
      key: ValueKey('theme-${mode.name}'),
      onTap: () => ref.read(themeModeProvider.notifier).set(mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primaryLight : context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? context.colors.primary : context.colors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? context.colors.primary : context.colors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildMinutesChip(int minutes, String label) {
    final isSelected = _sessionMinutes == minutes;
    return InkWell(
      onTap: () => _selectSessionMinutes(minutes),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primaryLight : context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? context.colors.primary : context.colors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? context.colors.primary : context.colors.textPrimary,
          ),
        ),
      ),
    );
  }

  String _formatGoal(String? goal) {
    switch (goal) {
      case 'lose_fat':
        return 'Giảm mỡ';
      case 'build_muscle':
        return 'Tăng cơ';
      case 'get_healthier':
        return 'Khỏe mạnh hơn';
      case 'maintain':
        return 'Duy trì vóc dáng';
      default:
        return 'Tập luyện';
    }
  }

  Widget _buildVoiceSettingsSection(BuildContext context) {
    final voiceSettings = ref.watch(voiceSettingsProvider);
    final voiceNotifier = ref.read(voiceSettingsProvider.notifier);
    final voiceCoach = ref.read(voiceCoachProvider);
    final styles = voiceCoach.styles;

    final allStyles = [
      (
        'coach',
        'Theo phong cách coach',
        'Tự động theo huấn luyện viên (${_selectedCoachStyle == 'strict' ? 'Nghiêm khắc' : _selectedCoachStyle == 'funny' ? 'Hài hước' : 'Động viên'})',
      ),
      for (final id in [
        'supportive',
        'strict',
        'funny',
        'calm',
        'hype',
        'genz',
        'minimal',
      ])
        (
          id,
          styles[id]?.nameVi ?? id,
          styles[id]?.descriptionVi ?? '',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: SwitchListTile(
            key: const ValueKey('settings-auto-camera'),
            title: const Text('Tự mở camera khi bắt đầu hiệp',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
                'Bài đếm được bằng camera sẽ mở camera ngay, không cần bấm "Đếm bằng camera"',
                style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
            value: ref.watch(autoCameraProvider),
            activeThumbColor: context.colors.primary,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => ref.read(autoCameraProvider.notifier).set(v),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Giọng đọc khi tập',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                key: const ValueKey('settings-voice-enabled'),
                title: const Text(
                  'Giọng đọc khi tập',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Đếm số lần, đếm lùi, nhắc tư thế và động viên khi tập',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
                value: voiceSettings.enabled,
                activeThumbColor: context.colors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => voiceNotifier.setEnabled(val),
              ),
              if (voiceSettings.enabled) ...[
                Divider(color: context.colors.border, height: 1),
                const SizedBox(height: 12),
                Text(
                  'Giọng huấn luyện viên',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildVoiceGenderCard(
                        gender: VoiceGender.female,
                        title: 'Giọng Nữ',
                        subtitle: 'Hoài My • Truyền cảm',
                        isSelected: voiceSettings.gender == VoiceGender.female,
                        onTap: () {
                          voiceNotifier.setGender(VoiceGender.female);
                          voiceCoach.speakLine(
                            VoiceLineKey.go,
                            interrupt: true,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildVoiceGenderCard(
                        gender: VoiceGender.male,
                        title: 'Giọng Nam',
                        subtitle: 'Nam Minh • Mạnh mẽ',
                        isSelected: voiceSettings.gender == VoiceGender.male,
                        onTap: () {
                          voiceNotifier.setGender(VoiceGender.male);
                          voiceCoach.speakLine(
                            VoiceLineKey.go,
                            interrupt: true,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: context.colors.border, height: 1),
                const SizedBox(height: 12),
                Text(
                  'Phong cách giọng',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                for (final styleItem in allStyles) ...[
                  _buildVoiceStyleTile(
                    id: styleItem.$1,
                    title: styleItem.$2,
                    desc: styleItem.$3,
                    isSelected: voiceSettings.selectedStyleId == styleItem.$1,
                    onSelect: () => voiceNotifier.setStyle(styleItem.$1),
                    onPreview: () {
                      if (styleItem.$1 == 'coach') {
                        // Phong cách mặc định dùng giọng thu sẵn nam/nữ đang chọn
                        voiceCoach.speakLine(VoiceLineKey.go, interrupt: true);
                        return;
                      }
                      final targetStyle =
                          styles[styleItem.$1] ?? styles['supportive']!;
                      final sample =
                          voiceCoach.pickLine(styleItem.$1, VoiceLineKey.go) ??
                          'Bắt đầu nào!';
                      final rate = (targetStyle.rate *
                              voiceSettings.speed.multiplier)
                          .clamp(0.1, 1.0);
                      voiceCoach.speakText(
                        sample,
                        rate: rate,
                        pitch: targetStyle.pitch,
                        interrupt: true,
                      );
                    },
                    hint: styleItem.$1 == 'minimal'
                        ? 'Phù hợp người mắt kém: chỉ đọc số và lệnh ngắn'
                        : null,
                  ),
                  const SizedBox(height: 6),
                ],
                const SizedBox(height: 8),
                Divider(color: context.colors.border, height: 1),
                const SizedBox(height: 12),
                Text(
                  'Tốc độ đọc',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: VoiceSpeed.values.map((speed) {
                    final isSelected = voiceSettings.speed == speed;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          key: ValueKey('settings-voice-speed-${speed.name}'),
                          label: Text(speed.labelVi),
                          selected: isSelected,
                          showCheckmark: false,
                          selectedColor: context.colors.primaryLight,
                          backgroundColor: context.colors.surface,
                          side: BorderSide(
                            color: isSelected
                                ? context.colors.primary
                                : context.colors.border,
                          ),
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? context.colors.primary
                                : context.colors.textPrimary,
                          ),
                          onSelected: (_) => voiceNotifier.setSpeed(speed),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Divider(color: context.colors.border, height: 1),
                const SizedBox(height: 4),
                SwitchListTile(
                  key: const ValueKey('settings-voice-start-tip'),
                  title: const Text(
                    'Đọc mẹo kỹ thuật đầu bài',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Đọc điểm kỹ thuật quan trọng khi chuyển sang bài mới',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  value: voiceSettings.readStartTip,
                  activeThumbColor: context.colors.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => voiceNotifier.setReadStartTip(val),
                ),
                SwitchListTile(
                  key: const ValueKey('settings-voice-commands'),
                  title: const Text(
                    'Điều khiển bằng giọng nói (thử nghiệm)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Khi đếm bằng camera: vẫy tay hoặc khi coach hỏi, nói "bỏ bài", '
                    '"tập tiếp", "tạm dừng", "xong hiệp". Cần quyền micro; máy dùng '
                    'dịch vụ nhận dạng giọng nói của Google, chỉ nghe vài giây sau mỗi lần hỏi.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  value: voiceSettings.voiceCommands,
                  activeThumbColor: context.colors.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => _setVoiceCommands(val),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceStyleTile({
    required String id,
    required String title,
    required String desc,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onPreview,
    String? hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? context.colors.primaryLight.withValues(alpha: 0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? context.colors.primary : context.colors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: ValueKey('settings-voice-style-$id'),
            onTap: onSelect,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: isSelected
                        ? context.colors.primary
                        : context.colors.textSecondary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            desc,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Semantics(
                    label: 'Nghe thử phong cách $title',
                    button: true,
                    child: IconButton(
                      key: ValueKey('preview-voice-$id'),
                      icon: const Icon(Icons.play_circle_fill_rounded),
                      color: context.colors.primary,
                      iconSize: 30,
                      tooltip: 'Nghe thử',
                      onPressed: onPreview,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Text(
                hint,
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: context.colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVoiceGenderCard({
    required VoiceGender gender,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? context.colors.primaryLight.withValues(alpha: 0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? context.colors.primary : context.colors.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        key: ValueKey('settings-voice-gender-${gender.code}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(
                gender == VoiceGender.female
                    ? Icons.record_voice_over_rounded
                    : Icons.mic_external_on_rounded,
                size: 20,
                color: isSelected ? context.colors.primary : context.colors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? context.colors.primary
                            : context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: context.colors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final baseUrl = ref.read(apiBaseUrlProvider);
    final url = '$baseUrl/privacy.html';
    bool opened = false;
    try {
      if (!kIsWeb) {
        if (Platform.isWindows) {
          final res = await Process.run('cmd', ['/c', 'start', '', url]);
          opened = res.exitCode == 0;
        } else if (Platform.isMacOS) {
          final res = await Process.run('open', [url]);
          opened = res.exitCode == 0;
        } else if (Platform.isLinux) {
          final res = await Process.run('xdg-open', [url]);
          opened = res.exitCode == 0;
        }
      }
    } catch (_) {}

    if (!opened && context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Chính sách quyền riêng tư'),
          content: SelectableText(url),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showDeleteAccountDialogs(BuildContext context) async {
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
          'Xoá tài khoản?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: context.colors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Khi xoá tài khoản, toàn bộ dữ liệu sau sẽ bị xoá vĩnh viễn:\n'
              '• Hồ sơ\n'
              '• Lịch sử tập\n'
              '• Bữa ăn\n'
              '• Tin nhắn coach\n'
              '• Streak\n'
              '• Bạn tập\n\n'
              'Không thể hoàn tác.',
              style: TextStyle(
                fontSize: 14,
                color: context.colors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('delete-dialog1-cancel'),
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            key: const ValueKey('delete-dialog1-continue'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );

    if (shouldProceed != true || !context.mounted) return;

    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountConfirmDialog(),
    );

    if (deleted == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      context.go('/login');
      messenger.showSnackBar(
        const SnackBar(
          key: ValueKey('delete-account-success-snackbar'),
          content: Text('Đã xoá tài khoản'),
        ),
      );
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Future<void> _confirmRecovered(
    BuildContext context,
    WidgetRef ref,
    ActiveInjury injury,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Đã khỏi ${injury.label}?'),
        content: Text(
          'Bạn đã khỏi đau vùng ${injury.label} và sẵn sàng tập lại bình thường?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Chưa'),
          ),
          ElevatedButton(
            key: ValueKey('injury-confirm-recovered-${injury.bodyArea}'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.buttonFill,
              foregroundColor: Colors.white,
            ),
            child: const Text('Đã khỏi'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final res = await ref.read(userRepositoryProvider).answerPainFollowUp(
        injury.bodyArea,
        'gone',
      );
      ref.invalidate(userStatusFutureProvider);
      ref.invalidate(homePlanProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(res.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(mapErrorMessage(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}

class _DeleteAccountConfirmDialog extends ConsumerStatefulWidget {
  const _DeleteAccountConfirmDialog();

  @override
  ConsumerState<_DeleteAccountConfirmDialog> createState() =>
      _DeleteAccountConfirmDialogState();
}

class _DeleteAccountConfirmDialogState
    extends ConsumerState<_DeleteAccountConfirmDialog> {
  final _controller = TextEditingController();
  bool _isDeleting = false;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_checkInput);
  }

  void _checkInput() {
    final text = _controller.text.trim().toUpperCase();
    final valid = text == 'XOÁ' || text == 'XÓA' || text == 'XOA';
    if (valid != _canDelete) {
      setState(() => _canDelete = valid);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDeletePressed() async {
    if (!_canDelete || _isDeleting) return;

    setState(() => _isDeleting = true);

    try {
      await ref.read(settingsControllerProvider.notifier).deleteAccount();
      if (!mounted) return;
      setState(() => _isDeleting = false);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      Navigator.of(context).pop(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mapErrorMessage(e)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDeleting,
      child: AlertDialog(
        title: Text(
          'Xác nhận xoá vĩnh viễn',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: context.colors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Để xác nhận, vui lòng gõ chữ XOÁ vào ô bên dưới:',
              style: TextStyle(
                fontSize: 14,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('delete-account-input'),
              controller: _controller,
              enabled: !_isDeleting,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Nhập XOÁ hoặc XOA',
                border: OutlineInputBorder(),
              ),
            ),
            if (_isDeleting) ...[
              const SizedBox(height: 16),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        key: ValueKey('delete-account-loading-indicator'),
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Đang xoá tài khoản...',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('delete-dialog2-cancel'),
            onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            key: const ValueKey('delete-account-confirm-btn'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              disabledBackgroundColor:
                  const Color(0xFFDC2626).withValues(alpha: 0.3),
            ),
            onPressed: (_canDelete && !_isDeleting) ? _onDeletePressed : null,
            child: const Text('Xoá vĩnh viễn'),
          ),
        ],
      ),
    );
  }
}
