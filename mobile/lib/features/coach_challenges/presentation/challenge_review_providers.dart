import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../../core/state/submit_notifier.dart';
import '../data/challenge_review_repository.dart';
import '../domain/challenge_review.dart';

final challengeReviewRepositoryProvider = Provider<ChallengeReviewRepository>(
  (ref) => ChallengeReviewRepositoryImpl(ref.watch(apiClientProvider)),
);
final challengeReviewQueueProvider = FutureProvider.autoDispose<List<ChallengeReview>>(
  (ref) => ref.watch(challengeReviewRepositoryProvider).waiting(),
);
final challengeReviewActionProvider = NotifierProvider<SubmitNotifier, SubmitState>(SubmitNotifier.new);
