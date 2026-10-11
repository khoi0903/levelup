import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                          p == BillingPeriod.monthly
                              ? '${vnd(c.monthlyPriceVnd)}/tháng'
                              : '${vnd(c.yearlyPriceVnd)}/năm',
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
          if (me.subscription.tier == 'pro')
            Text(
              'Gói Pro hiện tại • hết hạn ${me.subscription.expiresAt?.toLocal().toString().split(' ').first ?? ''}',
            ),
          PrimaryButton(
            label: 'Dùng thử ${c.trialDays} ngày',
            isLoading: busy,
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      final message = await ref
                          .read(billingServiceProvider)
                          .purchase(period);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(message)));
                      }
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
          ),
          const SizedBox(height: 10),
          const Text(
            'Giá dự kiến. Chức năng mua đang được chuẩn bị.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
