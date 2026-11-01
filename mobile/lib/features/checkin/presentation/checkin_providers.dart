import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../data/checkin_repository_impl.dart';
import '../domain/checkin_session.dart';

final checkinRepositoryProvider =
    Provider<CheckinRepository>((ref) => CheckinRepositoryImpl(ref.watch(apiClientProvider)));

/// Today's sessions with their check-in state. The states depend on the clock (a window opens at a set time),
/// so the screen refreshes this periodically; it is per learner, hence the user id.
final todayCheckinProvider = FutureProvider.autoDispose<TodayCheckin>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(checkinRepositoryProvider).today();
});
