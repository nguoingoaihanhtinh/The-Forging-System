import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../../core/state/submit_notifier.dart';
import '../../../core/widgets/evidence_photo_picker.dart';
import '../data/staff_redemption_repository_impl.dart';
import '../domain/staff_redemption.dart';

final staffRedemptionRepositoryProvider = Provider<StaffRedemptionRepository>(
  (ref) => StaffRedemptionRepositoryImpl(ref.watch(apiClientProvider)),
);

final staffRedemptionListProvider = FutureProvider.autoDispose
    .family<StaffRedemptionPage, ({String? status, String query, int page})>(
        (ref, filter) => ref.watch(staffRedemptionRepositoryProvider).list(
            status: filter.status, query: filter.query, page: filter.page));

final staffRedemptionActionProvider =
    NotifierProvider<SubmitNotifier, SubmitState>(SubmitNotifier.new);

/// Builds the delivery proof field. Replaced in tests, where there is no camera.
typedef DeliveryPhotoFieldBuilder = Widget Function(
    BuildContext context, ValueChanged<String?> onChanged);

final deliveryPhotoFieldBuilderProvider =
    Provider<DeliveryPhotoFieldBuilder>((ref) => (context, onChanged) =>
        EvidencePhotoPicker(
          onChanged: onChanged,
          label: 'Ảnh biên nhận',
          hint: 'Chụp ảnh quà đã giao (không bắt buộc)',
        ));
