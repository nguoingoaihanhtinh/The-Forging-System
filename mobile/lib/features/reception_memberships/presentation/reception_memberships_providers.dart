import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../../core/widgets/evidence_photo_picker.dart';
import '../data/reception_memberships_api.dart';
import '../data/reception_memberships_repository_impl.dart';
import '../../../core/state/submit_notifier.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../domain/member_models.dart';
import '../domain/package_type.dart';
import '../domain/reception_memberships_repository.dart';

/// Tests override this with a fake repository.
final receptionMembershipsRepositoryProvider =
    Provider<ReceptionMembershipsRepository>(
  (ref) => ReceptionMembershipsRepositoryImpl(
      ReceptionMembershipsApi(ref.watch(apiClientProvider))),
);

typedef EvidencePhotoBuilder = Widget Function(
    BuildContext context, ValueChanged<String?> onChanged);

/// The photo field of the payment evidence step; tests replace it (no camera).
final evidencePhotoBuilderProvider = Provider<EvidencePhotoBuilder>(
  (ref) => (context, onChanged) => EvidencePhotoPicker(
        onChanged: onChanged,
        label: 'Ảnh minh chứng đã thu phí (bắt buộc)',
        hint: 'Chụp hoặc chọn ảnh đã thu phí',
      ),
);

/// A learner's profile and packages.
final memberOverviewProvider =
    FutureProvider.autoDispose.family<MemberOverview, String>((ref, memberId) {
  ref.watch(currentUserIdProvider);
  return ref
      .watch(receptionMembershipsRepositoryProvider)
      .memberOverview(memberId);
});

/// Packages on sale, for the manual activation picker.
final packageTypesProvider =
    FutureProvider.autoDispose<List<PackageType>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(receptionMembershipsRepositoryProvider).packageTypes();
});

/// State of the "create learner" form.
final createMemberSubmitProvider =
    NotifierProvider<SubmitNotifier, SubmitState>(SubmitNotifier.new);
