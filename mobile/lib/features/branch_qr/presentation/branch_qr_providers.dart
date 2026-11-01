import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../data/branch_code_repository_impl.dart';
import '../domain/branch_code.dart';

final branchCodeRepositoryProvider =
    Provider<BranchCodeRepository>((ref) => BranchCodeRepositoryImpl(ref.watch(apiClientProvider)));

/// The current code of a branch. The screen asks for the next one when this one runs out.
final branchCodeProvider = FutureProvider.autoDispose.family<BranchCheckinCode, String>((ref, branchId) {
  ref.watch(currentUserIdProvider);
  return ref.watch(branchCodeRepositoryProvider).current(branchId);
});
