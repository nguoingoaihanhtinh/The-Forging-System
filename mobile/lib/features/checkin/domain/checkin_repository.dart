import 'checkin_outcome.dart';
import 'checkin_session.dart';

abstract interface class CheckinRepository {
  /// The member's sessions of today with their check-in state.
  Future<TodayCheckin> today();

  /// Checks the member in with the scanned QR text ([payload]) or the typed 6 digits ([shortCode]);
  /// [sessionId] picks the session when several are open. A refusal throws an `ApiException`
  /// (see [checkinActionOf] for what to offer next).
  Future<CheckinOutcome> submit({String? payload, String? shortCode, String? sessionId});
}
