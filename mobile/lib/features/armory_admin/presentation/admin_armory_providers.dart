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
