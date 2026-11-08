import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/hvp_toast.dart';
import 'reception_memberships_providers.dart';
import 'renewal_notifier.dart';
import 'widgets/evidence_sheet.dart';
import 'widgets/package_picker_sheet.dart';
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

/// MEM-16: pick a package, then the payment photo, then activate or renew for [memberId].
Future<void> askActivatePackage(BuildContext context, WidgetRef ref,
    {required String memberId, required String memberName}) async {
  final package = await showPackagePicker(context);
  if (package == null || !context.mounted) return;
  final message = await showEvidenceSheet(
    context,
    title: 'Xác nhận đã thu phí',
    summary: '$memberName · ${package.name}',
    confirmLabel: 'Xác nhận & kích hoạt gói',
    submit: (url) => ref
        .read(receptionMembershipsRepositoryProvider)
        .activateMembership(memberId,
            packageTypeId: package.id, evidenceUrl: url),
  );
  if (message == null) return;
  ref.invalidate(memberOverviewProvider(memberId));
  ref.invalidate(renewalListProvider);
  if (context.mounted) {
    HvpToast.success(context, message.isEmpty ? 'Đã kích hoạt gói.' : message);
  }
}

/// MEM-18: ask why, then freeze (`FROZEN`) or reopen (`ACTIVE`) the account of [memberId].
Future<void> askChangeStatus(BuildContext context, WidgetRef ref,
    {required String memberId,
    required String memberName,
    required String status}) async {
  final freeze = status == 'FROZEN';
  final done = await showReasonSheet(
    context,
    title: freeze ? 'Đóng băng tài khoản' : 'Mở lại tài khoản',
    summary: memberName,
    label: 'Lý do (bắt buộc)',
    confirmLabel: freeze ? 'Đóng băng' : 'Mở lại',
    emptyMessage: 'Vui lòng nhập lý do trước khi đổi trạng thái.',
    destructive: freeze,
    submit: (reason) => ref
        .read(receptionMembershipsRepositoryProvider)
        .changeStatus(memberId, status: status, reason: reason),
  );
  if (done != true) return;
  ref.invalidate(memberOverviewProvider(memberId));
  if (context.mounted) {
    HvpToast.success(
        context, freeze ? 'Đã đóng băng tài khoản.' : 'Đã mở lại tài khoản.');
  }
}
