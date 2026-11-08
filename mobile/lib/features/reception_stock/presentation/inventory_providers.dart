import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../../core/state/submit_notifier.dart';
import '../data/inventory_repository_impl.dart';
import '../domain/inventory.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepositoryImpl(ref.watch(apiClientProvider)),
);

final inventoryRewardsProvider = FutureProvider.autoDispose
    .family<InventoryRewardPage, ({String query, int page})>((ref, filter) =>
        ref.watch(inventoryRepositoryProvider).rewards(
              query: filter.query,
              page: filter.page,
            ));

final inventoryMovementsProvider = FutureProvider.autoDispose.family<
    InventoryMovementPage,
    ({String? rewardId, String? movementType, int page})>((ref, filter) =>
        ref.watch(inventoryRepositoryProvider).movements(
              rewardId: filter.rewardId,
              movementType: filter.movementType,
              page: filter.page,
            ));

final inventoryAdjustProvider =
    NotifierProvider<SubmitNotifier, SubmitState>(SubmitNotifier.new);
