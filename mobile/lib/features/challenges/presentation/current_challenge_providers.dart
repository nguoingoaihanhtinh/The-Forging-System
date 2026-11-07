import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../data/current_challenge_repository.dart';
import '../domain/current_challenge.dart';

final currentChallengeRepositoryProvider = Provider<CurrentChallengeRepository>(
  (ref) => CurrentChallengeRepositoryImpl(ref.watch(apiClientProvider)),
);

final currentChallengesProvider =
    FutureProvider.autoDispose<List<CurrentChallenge>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(currentChallengeRepositoryProvider).list();
});
