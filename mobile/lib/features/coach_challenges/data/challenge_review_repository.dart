import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/challenge_review.dart';

class ChallengeReviewRepositoryImpl implements ChallengeReviewRepository {
  ChallengeReviewRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<List<ChallengeReview>> waiting() async {
    final response = await _api.get('/staff/challenges/participations', query: <String, dynamic>{
      'status': 'AWAITING_COACH',
      'evidence': 'SUBMITTED',
      'page': 1,
      'limit': 100,
    });
    return response.dataList.map((entry) {
      final json = asMap(entry);
      return ChallengeReview(
        participationId: str(json, 'id'),
        challengeTitle: str(json, 'challengeTitle'),
        memberFullName: str(json, 'memberFullName'),
        memberCode: str(json, 'memberCode'),
        progressValue: intOf(json, 'progressValue'),
        target: intOf(json, 'target'),
        evidenceUrl: strOrNull(json, 'evidenceUrl'),
      );
    }).toList(growable: false);
  }

  @override
  Future<void> approve(String participationId) => _api.post('/staff/challenges/participations/$participationId/approve');
}
