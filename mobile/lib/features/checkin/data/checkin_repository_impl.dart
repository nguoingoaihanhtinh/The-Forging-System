import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/checkin_outcome.dart';
import '../domain/checkin_repository.dart';
import '../domain/checkin_session.dart';

class CheckinRepositoryImpl implements CheckinRepository {
  CheckinRepositoryImpl(this.api);

  final ApiClient api;

  @override
  Future<TodayCheckin> today() => _today('/me/checkin/sessions');

  @override
  Future<TodayCheckin> todayFor(String memberId) => _today('/members/$memberId/checkin/sessions');

  Future<TodayCheckin> _today(String path) async {
    final j = (await api.get(path)).dataMap;
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

  @override
  Future<CheckinOutcome> submit({String? payload, String? shortCode, String? sessionId}) async {
    final j = (await api.post('/me/checkin', body: <String, dynamic>{
      if (payload != null) 'payload': payload,
      if (shortCode != null) 'shortCode': shortCode,
      if (sessionId != null) 'sessionId': sessionId,
    }))
        .dataMap;
    if (str(j, 'status') == 'CHOOSE_SESSION') {
      return ChooseSession(asList(j['sessions']).map((e) => _session(asMap(e))).toList(growable: false));
    }
    return _checkedIn(j);
  }

  @override
  Future<CheckedIn> checkInFor({required String memberId, required String sessionId, required String evidenceUrl}) async {
    final j = (await api.post('/members/$memberId/checkin', body: <String, dynamic>{'sessionId': sessionId, 'evidenceUrl': evidenceUrl})).dataMap;
    return _checkedIn(j);
  }

  CheckedIn _checkedIn(JsonMap j) {
    final session = asMap(j['session']);
    final startsAt = dateOrNull(session, 'startsAt') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return CheckedIn(
      alreadyCheckedIn: boolOf(j, 'alreadyCheckedIn'),
      checkedInAt: dateOrNull(j, 'checkedInAt') ?? DateTime.now().toUtc(),
      sessionId: str(session, 'sessionId'),
      sessionTitle: str(session, 'title', 'Buổi tập'),
      startsAt: startsAt,
      endsAt: dateOrNull(session, 'endsAt') ?? startsAt,
      branchName: str(asMap(session['branch']), 'name'),
      sessionsRemaining: j['sessionsRemaining'] == null ? null : intOf(j, 'sessionsRemaining'),
      message: str(j, 'message', 'Check-in thành công.'),
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
