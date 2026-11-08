/// Where a session stands for check-in, as decided by the backend (docs/api/checkin.md).
enum CheckinState { open, notYetOpen, closed, checkedIn, overlapsCheckedIn, blocked }

CheckinState parseCheckinState(String? raw) {
  switch (raw) {
    case 'OPEN':
      return CheckinState.open;
    case 'NOT_YET_OPEN':
      return CheckinState.notYetOpen;
    case 'CLOSED':
      return CheckinState.closed;
    case 'CHECKED_IN':
      return CheckinState.checkedIn;
    case 'OVERLAPS_CHECKED_IN':
      return CheckinState.overlapsCheckedIn;
    default:
      return CheckinState.blocked; // an unknown state is treated as "cannot check in"
  }
}

class CheckinSession {
  const CheckinSession({
    required this.sessionId,
    required this.title,
    required this.sessionType,
    required this.isExam,
    required this.startsAt,
    required this.endsAt,
    required this.branchId,
    required this.branchName,
    required this.coachName,
    required this.state,
    required this.canCheckin,
    required this.opensAt,
    required this.closesAt,
    this.reason,
    this.message,
    this.checkedInAt,
  });

  final String sessionId;
  final String title;
  final String sessionType;
  final bool isExam;
  final DateTime startsAt;
  final DateTime endsAt;
  final String branchId;
  final String branchName;
  final String coachName;
  final CheckinState state;
  final bool canCheckin;
  final DateTime opensAt;
  final DateTime closesAt;

  /// Machine code of why the session cannot be checked into (null when it can).
  final String? reason;

  /// Vietnamese sentence explaining it, ready to show.
  final String? message;
  final DateTime? checkedInAt;
}

/// Whether the member may check in at all (account status and package), whichever session.
class CheckinEligibility {
  const CheckinEligibility({required this.canCheckin, this.code, this.message});

  final bool canCheckin;
  final String? code;
  final String? message;
}

class TodayCheckin {
  const TodayCheckin({required this.date, required this.eligibility, required this.sessions});

  /// Local calendar date the list is for (`YYYY-MM-DD`).
  final String date;
  final CheckinEligibility eligibility;
  final List<CheckinSession> sessions;
}

/// The session to pre-select: among those that can be checked into, the one starting nearest to [now].
/// Null when none can.
CheckinSession? defaultCheckinSession(List<CheckinSession> sessions, DateTime now) {
  CheckinSession? best;
  Duration? bestGap;
  for (final s in sessions) {
    if (!s.canCheckin) continue;
    final gap = s.startsAt.difference(now).abs();
    if (best == null || gap < bestGap!) {
      best = s;
      bestGap = gap;
    }
  }
  return best;
}
