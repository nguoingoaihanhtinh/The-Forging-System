import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/checkin_session.dart';

class CheckinRepositoryImpl implements CheckinRepository {
  CheckinRepositoryImpl(this.api);

  final ApiClient api;

  @override
  Future<TodayCheckin> today() async {
    final j = (await api.get('/me/checkin/sessions')).dataMap;
    final eligibility = asMap(j['eligibility']);
    return TodayCheckin(
      date: str(j, 'date'),
      eligibility: CheckinEligibility(
        canCheckin: boolOf(eligibility, 'canCheckin', true),
        code: strOrNull(eligibility, 'code'),
        message: strOrNull(eligibility, 'message'),
      ),
      sessions: asList(j['sessions']).map((e) => _session(asMap(e))).toList(growable: false),
    );
  }

  CheckinSession _session(JsonMap j) {
    final branch = asMap(j['branch']);
    final coach = asMap(j['coach']);
    final checkin = asMap(j['checkin']);
    final startsAt = dateOrNull(j, 'startsAt') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return CheckinSession(
      sessionId: str(j, 'sessionId'),
      title: str(j, 'title', 'Buổi tập'),
      sessionType: str(j, 'sessionType'),
      isExam: boolOf(j, 'isExam'),
      startsAt: startsAt,
      endsAt: dateOrNull(j, 'endsAt') ?? startsAt,
      branchId: str(branch, 'id'),
      branchName: str(branch, 'name'),
      coachName: str(coach, 'fullName'),
      state: parseCheckinState(strOrNull(checkin, 'state')),
      canCheckin: boolOf(checkin, 'canCheckin'),
      reason: strOrNull(checkin, 'reason'),
      message: strOrNull(checkin, 'message'),
      opensAt: dateOrNull(checkin, 'opensAt') ?? startsAt,
      closesAt: dateOrNull(checkin, 'closesAt') ?? startsAt,
      checkedInAt: dateOrNull(checkin, 'checkedInAt'),
    );
  }
}
