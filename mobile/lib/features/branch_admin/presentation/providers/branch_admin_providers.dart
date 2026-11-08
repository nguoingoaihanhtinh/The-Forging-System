import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/branch/branch.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/state/submit_notifier.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/branch_admin_api.dart';
import '../../data/branch_admin_repository_impl.dart';
import '../../domain/branch_admin_repository.dart';

/// Tests override this with a fake repository.
final branchAdminRepositoryProvider = Provider<BranchAdminRepository>(
  (ref) =>
      BranchAdminRepositoryImpl(BranchAdminApi(ref.watch(apiClientProvider))),
);

/// All branches, including inactive ones.
final adminBranchesProvider = FutureProvider.autoDispose<List<Branch>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(branchAdminRepositoryProvider).getBranches();
});

/// "Hiện chi nhánh ngừng hoạt động" toggle.
class ShowInactiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final showInactiveBranchesProvider =
    NotifierProvider<ShowInactiveNotifier, bool>(ShowInactiveNotifier.new);

/// Submit state of the add/edit branch form.
final branchFormSubmitProvider =
    NotifierProvider<SubmitNotifier, SubmitState>(SubmitNotifier.new);

/// Submit state of the activate/deactivate reason sheet.
final branchStatusSubmitProvider =
    NotifierProvider<SubmitNotifier, SubmitState>(SubmitNotifier.new);
