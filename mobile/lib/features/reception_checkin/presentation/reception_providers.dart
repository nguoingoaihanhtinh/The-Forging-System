import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../../checkin/domain/checkin_session.dart';
import '../../checkin/presentation/checkin_providers.dart';
import '../data/member_search_repository_impl.dart';
import '../domain/member_hit.dart';

final memberSearchRepositoryProvider =
    Provider<MemberSearchRepository>((ref) => MemberSearchRepositoryImpl(ref.watch(apiClientProvider)));

/// Learners matching the text; nothing is asked for text too short to be useful.
final memberSearchProvider = FutureProvider.autoDispose.family<MemberSearchResult, String>((ref, query) {
  ref.watch(currentUserIdProvider);
  final text = query.trim();
  if (text.length < memberSearchMinLength) return const MemberSearchResult(items: <MemberHit>[], total: 0);
  return ref.watch(memberSearchRepositoryProvider).search(text);
});

/// A learner's sessions of today as the front desk sees them.
final memberTodayProvider = FutureProvider.autoDispose.family<TodayCheckin, String>((ref, memberId) {
  ref.watch(currentUserIdProvider);
  return ref.watch(checkinRepositoryProvider).todayFor(memberId);
});
