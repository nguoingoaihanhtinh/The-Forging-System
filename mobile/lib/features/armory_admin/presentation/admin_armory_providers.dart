import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../../core/state/submit_notifier.dart';
import '../data/admin_armory_repository_impl.dart';
import '../domain/admin_armory_repository.dart';

final adminArmoryRepositoryProvider = Provider<AdminArmoryRepository>(
  (ref) => AdminArmoryRepositoryImpl(ref.watch(apiClientProvider)),
);

final createArmoryTierSubmitProvider =
    NotifierProvider<SubmitNotifier, SubmitState>(SubmitNotifier.new);

final updateArmoryTierSubmitProvider =
    NotifierProvider<SubmitNotifier, SubmitState>(SubmitNotifier.new);

final createArmoryRewardSubmitProvider =
    NotifierProvider<SubmitNotifier, SubmitState>(SubmitNotifier.new);

final updateArmoryRewardSubmitProvider =
    NotifierProvider<SubmitNotifier, SubmitState>(SubmitNotifier.new);

final adminArmoryTiersProvider =
    FutureProvider.autoDispose<List<AdminArmoryTier>>(
  (ref) => ref.watch(adminArmoryRepositoryProvider).tiers(),
);

final adminArmoryRewardsProvider = FutureProvider.autoDispose.family<
    AdminArmoryRewardPage,
    ({String query, String? tierCode, int page})>((ref, filter) =>
  ref.watch(adminArmoryRepositoryProvider).rewards(
    query: filter.query, tierCode: filter.tierCode, page: filter.page,
  ),
);
