import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_palette.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../nutrition/presentation/widgets/nutrition_widgets.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../../domain/services/billing_service.dart';
import '../controllers/product_controller.dart';

String vnd(int value) =>
    '${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}đ';

class ProScreen extends ConsumerStatefulWidget {
  const ProScreen({super.key});
  @override
  ConsumerState<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends ConsumerState<ProScreen> {
  BillingPeriod period = BillingPeriod.yearly;
  bool busy = false;

  Future<void> _handlePurchase(BuildContext context) async {
    setState(() => busy = true);
    try {
      final message = await ref.read(billingServiceProvider).purchase(period);
      if (context.mounted && message.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _handleRestore(BuildContext context) async {
    setState(() => busy = true);
    try {
      final message = await ref.read(billingServiceProvider).restore();
      if (context.mounted && message.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openSubscriptionManagement() async {
    final uri = Uri.parse(
      'https://play.google.com/store/account/subscriptions?package=vn.levelup.app',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    if (me?.subscription.enabled != true) {
      return const FeatureScaffold(
        title: 'Không tìm thấy trang',
        child: SizedBox.shrink(),
      );
    }
    final c = me!.productConfig;
    final isPro = me.subscription.tier == 'pro';
    final prices = ref.watch(proPricesProvider).valueOrNull ?? const {};

    final rows = [
      [
        'AI coach',
        '${c.coachFreePerDay} tin/ngày',
        '${c.coachProPerDay} tin/ngày',
      ],
      [
        'Chụp món',
        '${c.photosFreePerDay} ảnh/ngày',
        '${c.photosProPerDay} ảnh/ngày',
      ],
      ['Biểu đồ tiến bộ', '4 tuần gần nhất', 'Toàn bộ'],
      ['Giọng coach', '2 phong cách', '7 phong cách'],
    ];

    final expiresAtStr = me.subscription.expiresAt != null
        ? _viDate(me.subscription.expiresAt!.toLocal())
        : '';

    return FeatureScaffold(
      title: 'LevelUp Pro',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Thêm lượt AI, thêm lựa chọn cho bạn',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tập luyện, check-in, streak, buddy và tổng kết tuần luôn miễn phí.',
          ),
          const SizedBox(height: 20),
          GlassCard(
            child: Table(
              columnWidths: const {0: FlexColumnWidth(1.4)},
              children: [
                const TableRow(
                  children: [
                    Text('Tính năng'),
                    Text(
                      'Miễn phí',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Pro', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                for (final row in rows)
                  TableRow(
                    children: row
                        .map(
                          (s) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(s),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (!isPro)
            for (final p in BillingPeriod.values) ...[
              GlassCard(
                isSelected: period == p,
                onTap: busy ? null : () => setState(() => period = p),
                child: Row(
                  children: [
                    Icon(
                      period == p
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prices[p] != null
                                ? '${prices[p]}/${p == BillingPeriod.monthly ? 'tháng' : 'năm'}'
                                : (p == BillingPeriod.monthly
                                    ? '${vnd(c.monthlyPriceVnd)}/tháng'
                                    : '${vnd(c.yearlyPriceVnd)}/năm'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          if (p == BillingPeriod.yearly)
                            const Text('tiết kiệm 32%'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          if (isPro) ...[
            Text(
              'Pro đến $expiresAtStr',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Quản lý gói',
              onPressed: busy ? null : _openSubscriptionManagement,
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: busy ? null : () => _handleRestore(context),
                child: const Text(
                  'Khôi phục giao dịch',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ] else if (c.proEnabled) ...[
            PrimaryButton(
              label: c.trialDays > 0
                  ? 'Dùng thử ${c.trialDays} ngày'
                  : 'Nâng cấp Pro',
              isLoading: busy,
              onPressed: busy ? null : () => _handlePurchase(context),
            ),
            const SizedBox(height: 10),
            Text(
              'Tự gia hạn, huỷ bất kỳ lúc nào trong Google Play → Gói thuê bao',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: busy ? null : () => _handleRestore(context),
                child: const Text(
                  'Khôi phục giao dịch',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            const Text(
              'Giá dự kiến. Chức năng mua đang được chuẩn bị.',
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

String _viDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
