import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../data/redemption_repository.dart';
import '../domain/redemption.dart';

final redemptionRepositoryProvider = Provider<RedemptionRepository>(
  (ref) => RedemptionRepositoryImpl(ref.watch(apiClientProvider)),
);

final redemptionHistoryProvider = FutureProvider.autoDispose
    .family<RedemptionPage, ({String? status, int page})>((ref, query) {
  ref.watch(currentUserIdProvider);
  return ref
      .watch(redemptionRepositoryProvider)
      .history(status: query.status, page: query.page);
});

final redemptionDetailProvider =
    FutureProvider.autoDispose.family<ArmoryRedemption, String>((ref, id) {
  ref.watch(currentUserIdProvider);
  return ref.watch(redemptionRepositoryProvider).detail(id);
});
