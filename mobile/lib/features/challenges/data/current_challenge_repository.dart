import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/current_challenge.dart';

class CurrentChallengeRepositoryImpl implements CurrentChallengeRepository {
  CurrentChallengeRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<List<CurrentChallenge>> list() async {
    final response = await _api.get('/me/challenges',
        query: <String, dynamic>{'page': 1, 'limit': 100});
    return response.dataList
        .map(asMap)
        .where((json) => strOrNull(json, 'participationId') != null)
        .map((json) {
      return CurrentChallenge(
        id: str(json, 'id'),
        title: str(json, 'title'),
        challengeType: str(json, 'challengeType'),
        target: intOf(json, 'target'),
        rewardDp: intOf(json, 'rewardDp'),
        rewardMarks: intOf(json, 'rewardMarks'),
        endsAt: dateOrNull(json, 'endsAt') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        participationStatus: str(json, 'participationStatus'),
        progressValue: intOf(json, 'progressValue'),
      );
    }).toList(growable: false);
  }
}
