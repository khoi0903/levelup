import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_palette.dart';
import 'glass_card.dart';

/// Giờ mặc định của từng khung giờ, giống backend:
/// early_morning 06:00, noon 12:00, evening 18:30, late_evening 20:30.
String slotDefaultTime(String? slot) => switch (slot) {
  'early_morning' => '06:00',
  'noon' => '12:00',
  'late_evening' => '20:30',
  _ => '18:30',
};

const List<String> kWeekdayNames = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ Nhật',
];

/// "HH:mm" hợp lệ thì trả TimeOfDay, không thì null.
TimeOfDay? parseHhMm(String? v) {
  if (v == null) return null;
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return TimeOfDay(hour: h, minute: min);
}

String formatHhMm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Phần thu gọn "Giờ riêng từng ngày": mỗi ngày đã chọn hiện giờ tập
/// (mặc định theo khung giờ), chạm để đổi bằng đồng hồ 24 giờ.
/// [times] chỉ chứa những ngày người dùng đã đổi; bỏ giờ riêng thì gọi
/// [onChanged] với null. Dùng chung cho onboarding và cài đặt.
class DayTimesEditor extends StatefulWidget {
  const DayTimesEditor({
    super.key,
    required this.weekdays,
    required this.slot,
    required this.times,
    required this.onChanged,
    this.initiallyExpanded = false,
  });

  /// 1 = Thứ Hai … 7 = Chủ Nhật.
  final List<int> weekdays;

  /// Tên khung giờ (early_morning | noon | evening | late_evening).
  final String? slot;
  final Map<int, String> times;
  final void Function(int weekday, String? time) onChanged;
  final bool initiallyExpanded;

  @override
  State<DayTimesEditor> createState() => _DayTimesEditorState();
}

class _DayTimesEditorState extends State<DayTimesEditor> {
  late bool _expanded = widget.initiallyExpanded;

  Future<void> _pick(int day) async {
    final current =
        parseHhMm(widget.times[day]) ??
        parseHhMm(slotDefaultTime(widget.slot))!;
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: 'Giờ tập ${kWeekdayNames[day - 1]}',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final value = formatHhMm(picked);
    widget.onChanged(day, value == slotDefaultTime(widget.slot) ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final days = [...widget.weekdays]..sort();
    final defaultTime = slotDefaultTime(widget.slot);
    final customCount = days.where(widget.times.containsKey).length;

    return GlassCard(
      key: const ValueKey('day-times-editor'),
      padding: EdgeInsets.zero,
      borderRadius: AppColors.radiusButton,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const ValueKey('day-times-toggle'),
            borderRadius: BorderRadius.circular(AppColors.radiusButton),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 20, color: c.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Giờ riêng từng ngày',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                        Text(
                          customCount == 0
                              ? 'Không bắt buộc · mặc định $defaultTime'
                              : 'Đã đặt riêng $customCount ngày',
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: !_expanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 10, 8),
                    child: Column(
                      children: [
                        Divider(height: 1, color: c.border),
                        const SizedBox(height: 4),
                        for (final day in days)
                          _DayRow(
                            day: day,
                            time: widget.times[day] ?? defaultTime,
                            custom: widget.times.containsKey(day),
                            onTap: () => _pick(day),
                            onReset: () => widget.onChanged(day, null),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.time,
    required this.custom,
    required this.onTap,
    required this.onReset,
  });

  final int day;
  final String time;
  final bool custom;
  final VoidCallback onTap;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              kWeekdayNames[day - 1],
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ),
          if (custom)
            IconButton(
              key: ValueKey('day-time-reset-$day'),
              tooltip: 'Dùng giờ mặc định',
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              color: c.textSecondary,
              onPressed: onReset,
              icon: const Icon(Icons.close_rounded),
            ),
          InkWell(
            key: ValueKey('day-time-$day'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: custom ? c.primaryLight : c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: custom ? c.primary : c.border),
              ),
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: custom ? c.primary : c.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
