import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/hvp_toast.dart';
import '../domain/renewal_models.dart';
import 'reception_memberships_providers.dart';
import 'renewal_notifier.dart';
import 'widgets/evidence_sheet.dart';

/// MEM-13 / AMB-07: collect the payment photo, then approve [request].
Future<void> askApproveRenewal(
    BuildContext context, WidgetRef ref, RenewalRequest request) async {
  final price =
      request.priceVnd == null ? '' : ' · ${formatInt(request.priceVnd!)}đ';
  final message = await showEvidenceSheet(
    context,
    title: 'Xác nhận đã thu phí',
    summary: '${request.memberName} · ${request.packageName}$price',
    confirmLabel: 'Xác nhận & kích hoạt gói',
    submit: (url) async {
      try {
        return await ref
            .read(receptionMembershipsRepositoryProvider)
            .approveRenewal(request.id, evidenceUrl: url);
      } on ApiException catch (e) {
        // Someone else already handled it: the inbox is stale.
        if (e.code == 'RENEWAL_ALREADY_HANDLED') {
          ref.invalidate(renewalListProvider);
        }
        rethrow;
      }
    },
  );
  if (message == null) return;
  ref.invalidate(renewalListProvider);
  if (context.mounted) {
    HvpToast.success(context, message.isEmpty ? 'Đã kích hoạt gói.' : message);
  }
}
