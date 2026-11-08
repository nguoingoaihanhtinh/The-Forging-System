class ChallengeReview {
  const ChallengeReview({
    required this.participationId,
    required this.challengeTitle,
    required this.memberFullName,
    required this.memberCode,
    required this.progressValue,
    required this.target,
    required this.evidenceUrl,
  });

  final String participationId;
  final String challengeTitle;
  final String memberFullName;
  final String memberCode;
  final int progressValue;
  final int target;
  final String? evidenceUrl;
}

abstract interface class ChallengeReviewRepository {
  Future<List<ChallengeReview>> waiting();
  Future<void> approve(String participationId);
}
