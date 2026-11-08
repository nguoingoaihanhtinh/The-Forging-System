import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../../core/state/submit_notifier.dart';
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
