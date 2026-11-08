import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/hvp_app_bar.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_refresh.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/membership_models.dart';
import '../../domain/membership_rules.dart';
import '../providers/membership_providers.dart';
import '../widgets/membership_banner.dart';
import '../widgets/package_cards.dart';
import '../widgets/renewal_sheet.dart';

/// "Gói tập của tôi": account status, current / queued package, pending request.
class MembershipScreen extends ConsumerWidget {
  const MembershipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const HvpAppBar(title: 'Gói tập của tôi'),
      body: AsyncBody<MyMembership>(
        value: ref.watch(myMembershipProvider),
        onRetry: () => ref.invalidate(myMembershipProvider),
        builder: (context, m) => HvpRefresh(
          onRefresh: () => ref.refresh(myMembershipProvider.future),
          child: _Body(membership: m),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.membership});

  final MyMembership membership;

  @override
  Widget build(BuildContext context) {
    final m = membership;
    final current = m.current;
    final scheduled = m.scheduled;
    final pending = m.pendingRenewal;
    final noPackage = m.renewNotice == RenewNotice.noPackage;
    final canRenew = canRequestRenewal(m);
    final hasBanner = membershipBanner(m, showNoPackage: false) != null;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        MembershipBanner(
          onAction: canRenew ? () => showRenewalSheet(context) : null,
          showNoPackage: false,
        ),
        if (hasBanner) const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: StatusChip(
            label: m.memberStatus.label,
            tone: switch (m.memberStatus) {
              MemberStatus.active => ChipTone.success,
              MemberStatus.frozen => ChipTone.info,
              MemberStatus.inactive => ChipTone.neutral,
            },
          ),
        ),
        const SizedBox(height: 12),
        if (current != null)
          CurrentPackageCard(package: current)
        else
          EmptyState(
            icon: HvpIcons.ticket,
            title: noPackage ? 'Chưa có gói tập' : 'Gói tập đã kết thúc',
            message: noPackage
                ? 'Bạn chưa có gói tập, liên hệ lễ tân để đăng ký.'
                : 'Đăng ký gói mới để tiếp tục check-in và tích điểm. '
                    'DP, Marks và hạng của bạn vẫn được giữ nguyên.',
          ),
        if (scheduled != null) ...<Widget>[
          const SectionHeader(title: 'Gói nối tiếp'),
          ScheduledPackageCard(package: scheduled),
        ],
        if (pending != null) ...<Widget>[
          const SectionHeader(title: 'Yêu cầu gia hạn'),
          PendingRenewalCard(renewal: pending),
        ],
        // The banner carries the CTA when it shows; otherwise offer it here.
        if (!hasBanner) ...<Widget>[
          const SizedBox(height: 16),
          HvpButton.gold(
            label: 'Gia hạn gói tập',
            expand: true,
            onPressed: canRenew ? () => showRenewalSheet(context) : null,
          ),
        ],
      ],
    );
  }
}
