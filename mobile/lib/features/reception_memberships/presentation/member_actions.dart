import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/hvp_toast.dart';
import 'reception_memberships_providers.dart';
import 'widgets/reason_sheet.dart';

/// MEM-14: ask why, then cancel the package [membershipId] of [memberId].
Future<void> askCancelPackage(BuildContext context, WidgetRef ref,
    {required String memberId,
    required String membershipId,
    required String packageName}) async {
  final done = await showReasonSheet(
    context,
    title: 'Huỷ gói tập',
    summary: packageName,
    confirmLabel: 'Huỷ gói',
    emptyMessage: 'Vui lòng nhập lý do huỷ.',
    submit: (reason) => ref
        .read(receptionMembershipsRepositoryProvider)
        .cancelMembership(membershipId, reason: reason),
  );
  if (done != true) return;
  ref.invalidate(memberOverviewProvider(memberId));
  if (context.mounted) {
    HvpToast.success(context, 'Đã huỷ gói tập.');
  }
}
