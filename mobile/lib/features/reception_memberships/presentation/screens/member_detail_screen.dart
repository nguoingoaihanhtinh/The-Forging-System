import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/hvp_app_bar.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/hvp_refresh.dart';
import '../../../auth/domain/auth_user.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../membership/domain/membership_models.dart';
import '../../domain/member_models.dart';
import '../../domain/member_rules.dart';
import '../member_actions.dart';
import '../reception_memberships_providers.dart';
import '../widgets/member_header_card.dart';
import '../widgets/package_panel.dart';

/// One learner: account, running and waiting package, and what the desk can do with them.
class MemberDetailScreen extends ConsumerWidget {
  const MemberDetailScreen({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(currentUserProvider)?.appRole == AppRole.admin;
    return Scaffold(
      appBar: const HvpAppBar(title: 'Học viên'),
      body: AsyncBody<MemberOverview>(
        value: ref.watch(memberOverviewProvider(memberId)),
        onRetry: () => ref.invalidate(memberOverviewProvider(memberId)),
        builder: (context, overview) {
          final membership = overview.membership;
          return HvpRefresh(
            onRefresh: () =>
                ref.refresh(memberOverviewProvider(memberId).future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: <Widget>[
                MemberHeaderCard(profile: overview.profile),
                const SizedBox(height: 12),
                if (membership.current != null) ...<Widget>[
                  _panel(
                      context, ref, 'Gói đang hoạt động', membership.current!,
                      scheduled: false, isAdmin: isAdmin),
                  const SizedBox(height: 12),
                ],
                if (membership.scheduled != null) ...<Widget>[
                  _panel(context, ref, 'Gói nối tiếp', membership.scheduled!,
                      scheduled: true, isAdmin: isAdmin),
                  const SizedBox(height: 12),
                ],
                if (membership.current == null && membership.scheduled == null)
                  HvpCard(
                      child: Text('Học viên chưa có gói tập.',
                          style: context.txt.body)),
                const SizedBox(height: 12),
                HvpButton.gold(
                  label: 'Kích hoạt / gia hạn gói',
                  expand: true,
                  onPressed: () => askActivatePackage(context, ref,
                      memberId: memberId,
                      memberName: overview.profile.fullName),
                ),
                if (membership.pendingRenewal != null) ...<Widget>[
                  const SizedBox(height: 12),
                  HvpCard(
                    child: Text(
                        'Đang chờ duyệt yêu cầu gia hạn: ${membership.pendingRenewal!.packageName}',
                        style: context.txt.body),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _panel(
      BuildContext context, WidgetRef ref, String title, MemberPackage package,
      {required bool scheduled, required bool isAdmin}) {
    final allowed = canCancelPackage(isAdmin: isAdmin, scheduled: scheduled);
    return PackagePanel(
      title: title,
      package: package,
      cancelLabel: scheduled ? 'Huỷ gói nối tiếp' : 'Huỷ gói đang hoạt động',
      onCancel: allowed
          ? () => askCancelPackage(context, ref,
              memberId: memberId,
              membershipId: package.id,
              packageName: package.name)
          : null,
    );
  }
}
