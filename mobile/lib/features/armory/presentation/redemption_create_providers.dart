import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../data/redemption_create_repository.dart';
import '../domain/redemption_create.dart';

final redemptionCreateRepositoryProvider = Provider<RedemptionCreateRepository>(
  (ref) => RedemptionCreateRepositoryImpl(ref.watch(apiClientProvider)),
);
