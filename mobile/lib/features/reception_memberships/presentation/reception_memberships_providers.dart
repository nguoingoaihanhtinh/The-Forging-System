import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../data/reception_memberships_api.dart';
import '../data/reception_memberships_repository_impl.dart';
import '../domain/reception_memberships_repository.dart';

/// Tests override this with a fake repository.
final receptionMembershipsRepositoryProvider =
    Provider<ReceptionMembershipsRepository>(
  (ref) => ReceptionMembershipsRepositoryImpl(
      ReceptionMembershipsApi(ref.watch(apiClientProvider))),
);
