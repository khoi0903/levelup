import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../controllers/user_controller.dart';
import '../../domain/models/me_response.dart';
import '../../domain/models/settings_request.dart';

/// Màn hình Hồ sơ & Cài đặt (Tab Tôi).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  String _selectedCoachStyle = 'supportive';
  int _sessionMinutes = 15;
  bool _notificationsEnabled = true;
  bool _quietHoursEnabled = true;
  int _maxPerDay = 2;
  bool _shareWeight = false;
  bool _shareMeasurements = false;
  bool _sharePhotos = false;
  bool _shareMeals = false;
  final Set<int> _activeWeekdays = {};
  bool _isInitialized = false;

  void _initFields(MeResponse me) {
    if (_isInitialized) return;
    _nameController.text = me.displayName;
    _selectedCoachStyle = me.profile?.coachStyle ?? 'supportive';
    _sessionMinutes = me.profile?.sessionMinutes ?? 15;

    final notif = me.settings.notifications;
    _notificationsEnabled = notif.pushEnabled;
    _quietHoursEnabled = notif.quietStart == '22:00' && notif.quietEnd == '07:00';
    _maxPerDay = notif.maxPerDay;

    final sharing = me.settings.sharing;
    _shareWeight = sharing.weight;
    _shareMeasurements = sharing.measurements;
    _sharePhotos = sharing.photos;
    _shareMeals = sharing.meals;

    _activeWeekdays.clear();
    for (final slot in me.settings.availability) {
      _activeWeekdays.add(slot.weekday);
    }
    if (_activeWeekdays.isEmpty) {
      _activeWeekdays.addAll([1, 3, 5]); // Mặc định T2, T4, T6
    }

    _isInitialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userStatusFutureProvider);
    final settingsState = ref.watch(settingsControllerProvider);
    final settingsNotifier = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hồ sơ & Cài đặt',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: userAsync.when(
            data: (me) {
              _initFields(me);
              return _buildSettingsList(context, me, settingsState, settingsNotifier);
            },
            loading: () => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  mapErrorMessage(err),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
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
        if (state.successMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF86EFAC), width: 1),
            ),
            child: Text(
              state.successMessage!,
              key: const ValueKey('settings-success-banner'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF166534),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        if (state.error != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
            ),
            child: Text(
              mapErrorMessage(state.error),
              key: const ValueKey('settings-error-banner'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF991B1B),
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
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mục tiêu: ${_formatGoal(me.profile?.goal)}',
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
        const SizedBox(height: 20),

        // 1. Tên hiển thị
        const Text(
          'Tên hiển thị',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'Nhập tên của bạn...',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 20),

        // 2. Phong cách coach
        const Text(
          'Phong cách Coach',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
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

        // 3. Thời lượng mỗi buổi tập
        const Text(
          'Thời lượng mỗi buổi tập',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildMinutesChip(10, '10–15 phút')),
            const SizedBox(width: 8),
            Expanded(child: _buildMinutesChip(20, '20 phút')),
            const SizedBox(width: 8),
            Expanded(child: _buildMinutesChip(30, '30 phút')),
          ],
        ),
        const SizedBox(height: 20),

        // 4. Lịch rảnh trong tuần
        const Text(
          'Lịch rảnh trong tuần',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đổi lịch rảnh chỉ áp dụng từ tuần sau.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildWeekdaySelector(),
        const SizedBox(height: 20),

        // 5. Cài đặt thông báo
        const Text(
          'Cài đặt thông báo',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Bật thông báo nhắc tập',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Nhắc trước giờ tập đã hẹn',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                value: _notificationsEnabled,
                activeThumbColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _notificationsEnabled = val),
              ),
              const Divider(color: AppColors.border, height: 1),
              SwitchListTile(
                title: const Text('Giờ yên lặng (22:00 – 07:00)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Không gửi thông báo trong thời gian này',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                value: _quietHoursEnabled,
                activeThumbColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _quietHoursEnabled = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 6. Chia sẻ với buddy
        const Text(
          'Chia sẻ với bạn đồng hành (Buddy)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Cân nặng hiện tại',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                value: _shareWeight,
                activeThumbColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _shareWeight = val),
              ),
              const Divider(color: AppColors.border, height: 1),
              SwitchListTile(
                title: const Text('Số đo cơ thể',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                value: _shareMeasurements,
                activeThumbColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _shareMeasurements = val),
              ),
              const Divider(color: AppColors.border, height: 1),
              SwitchListTile(
                title: const Text('Ảnh chụp tiến độ',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                value: _sharePhotos,
                activeThumbColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _sharePhotos = val),
              ),
              const Divider(color: AppColors.border, height: 1),
              SwitchListTile(
                title: const Text('Lượng calo đã nạp hôm nay',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                value: _shareMeals,
                activeThumbColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _shareMeals = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Nút Lưu cài đặt (PATCH /me)
        PrimaryButton(
          label: state.isSaving ? 'Đang lưu...' : 'Lưu cài đặt',
          onPressed: state.isSaving
              ? null
              : () {
                  final newName = _nameController.text.trim();
                  final availabilityList = _activeWeekdays.map((w) {
                    return UserAvailabilitySlot(weekday: w, slot: 'evening');
                  }).toList()
                    ..sort((a, b) => a.weekday.compareTo(b.weekday));

                  notifier.saveSettings(
                    displayName: newName.isNotEmpty ? newName : null,
                    coachStyle: _selectedCoachStyle,
                    sessionMinutes: _sessionMinutes,
                    availability: availabilityList.isNotEmpty ? availabilityList : null,
                    notifications: NotificationsUpdate(
                      pushEnabled: _notificationsEnabled,
                      quietStart: _quietHoursEnabled ? '22:00' : '00:00',
                      quietEnd: _quietHoursEnabled ? '07:00' : '00:00',
                      maxPerDay: _maxPerDay,
                    ),
                    sharing: SharingUpdate(
                      weight: _shareWeight,
                      measurements: _shareMeasurements,
                      photos: _sharePhotos,
                      meals: _shareMeals,
                    ),
                  );
                },
        ),
        const SizedBox(height: 20),

        // Đăng xuất (xóa token dev)
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
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
                    }
                  } else {
                    _activeWeekdays.add(weekday);
                  }
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
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
      onTap: () => setState(() => _selectedCoachStyle = value),
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
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
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
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinutesChip(int minutes, String label) {
    final isSelected = _sessionMinutes == minutes;
    return InkWell(
      onTap: () => setState(() => _sessionMinutes = minutes),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
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
}
