import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/profile_api.dart';
import '../../data/profile_repository_impl.dart';
import '../../domain/profile_models.dart';
import '../../domain/profile_repository.dart';

/// Tests override this with a fake repository.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(ProfileApi(ref.watch(apiClientProvider))),
);

/// Watching the user id drops cached data on account switch.
final profileProvider = FutureProvider.autoDispose<MemberProfile>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(profileRepositoryProvider).getProfile();
});
