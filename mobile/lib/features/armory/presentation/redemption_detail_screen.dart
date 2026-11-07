import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/hvp_app_bar.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/redemption.dart';
import 'redemption_providers.dart';

class RedemptionDetailScreen extends ConsumerWidget {
  const RedemptionDetailScreen({super.key, required this.redemptionId});
  final String redemptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(redemptionDetailProvider(redemptionId));
    return Scaffold(
      appBar: const HvpAppBar(title: 'Chi tiết đổi quà'),
      body: AsyncBody<ArmoryRedemption>(
        value: detail,
        onRetry: () => ref.invalidate(redemptionDetailProvider(redemptionId)),
        builder: (_, redemption) => ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Center(
              child: redemption.rewardImageUrl == null
                  ? Icon(HvpIcons.gift, size: 72, color: context.hvp.gold)
                  : CachedNetworkImage(
                      imageUrl: redemption.rewardImageUrl!,
                      width: 96,
                      height: 96,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => Icon(HvpIcons.gift,
                          size: 72, color: context.hvp.gold),
                    ),
            ),
            const SizedBox(height: 16),
            Text(redemption.rewardName,
                style: context.txt.titleL, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Center(child: _detailStatusChip(redemption.status)),
            const SizedBox(height: 20),
            HvpCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('THÔNG TIN YÊU CẦU', style: context.txt.titleS),
                    const SizedBox(height: 8),
                    _line(context, 'Mã yêu cầu', redemption.code),
                    _line(context, 'Marks đã đổi',
                        '${formatInt(redemption.marksCost)} Marks'),
                    _line(
                        context, 'Chi nhánh nhận', redemption.pickupBranchName),
                    _line(context, 'Thời điểm yêu cầu',
                        formatDateTime(redemption.requestedAt)),
                    if (redemption.decidedAt != null)
                      _line(context, 'Cập nhật lần cuối',
                          formatDateTime(redemption.decidedAt!)),
                  ]),
            ),
            if (redemption.reason != null) ...<Widget>[
              const SizedBox(height: 12),
              HvpCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('GHI CHÚ', style: context.txt.titleS),
                      const SizedBox(height: 8),
                      Text(redemption.reason!, style: context.txt.bodySmall),
                    ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: context.txt.caption),
              Text(value, style: context.txt.bodySmall),
            ]),
      );
}

StatusChip _detailStatusChip(String status) => switch (status) {
      'PENDING_PICKUP' =>
        const StatusChip(label: 'Chờ nhận', tone: ChipTone.warning),
      'DELIVERED' => const StatusChip(label: 'Đã giao', tone: ChipTone.success),
      'REJECTED' => const StatusChip(label: 'Từ chối', tone: ChipTone.danger),
      'CANCELLED' => const StatusChip(label: 'Đã hủy', tone: ChipTone.neutral),
      'EXPIRED' => const StatusChip(label: 'Hết hạn', tone: ChipTone.neutral),
      _ => StatusChip(label: status, tone: ChipTone.neutral),
    };
