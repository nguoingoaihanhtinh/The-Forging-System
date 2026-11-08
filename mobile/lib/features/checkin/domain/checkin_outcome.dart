import '../../../core/error/api_exception.dart';
import 'checkin_session.dart';

/// What the backend said to a check-in (docs/api/checkin.md).
sealed class CheckinOutcome {
  const CheckinOutcome();
}

/// The member is checked in (just now, or already was: [alreadyCheckedIn]).
class CheckedIn extends CheckinOutcome {
  const CheckedIn({
    required this.alreadyCheckedIn,
    required this.checkedInAt,
    required this.sessionId,
    required this.sessionTitle,
    required this.startsAt,
    required this.endsAt,
    required this.branchName,
    required this.message,
    this.sessionsRemaining,
  });

  final bool alreadyCheckedIn;
  final DateTime checkedInAt;
  final String sessionId;
  final String sessionTitle;
  final DateTime startsAt;
  final DateTime endsAt;
  final String branchName;

  /// Sessions left on the package; null for a package without a session limit.
  final int? sessionsRemaining;
  final String message;
}

/// Several sessions are open at the branch: the member picks one and the same code is sent again with it.
class ChooseSession extends CheckinOutcome {
  const ChooseSession(this.sessions);

  final List<CheckinSession> sessions;
}

/// What to offer after a refused check-in (`details.action` of the error).
enum CheckinAction { rescan, wait, askFrontDesk, renewPackage, goToBranch, attachPhoto, none }

CheckinAction parseCheckinAction(String? raw) {
  switch (raw) {
    case 'RESCAN':
      return CheckinAction.rescan;
    case 'WAIT':
      return CheckinAction.wait;
    case 'ASK_FRONT_DESK':
      return CheckinAction.askFrontDesk;
    case 'RENEW_PACKAGE':
      return CheckinAction.renewPackage;
    case 'GO_TO_BRANCH':
      return CheckinAction.goToBranch;
    case 'ATTACH_PHOTO':
      return CheckinAction.attachPhoto;
    default:
      return CheckinAction.none;
  }
}

/// The action hint carried by a refused check-in; [CheckinAction.none] for any other error.
CheckinAction checkinActionOf(Object error) {
  if (error is ApiException) {
    final details = error.details;
    if (details is Map) return parseCheckinAction(details['action']?.toString());
  }
  return CheckinAction.none;
}
