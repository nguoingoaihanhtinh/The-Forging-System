import 'checkin_outcome.dart';
import 'checkin_session.dart';

abstract interface class CheckinRepository {
  /// The member's sessions of today with their check-in state.
  Future<TodayCheckin> today();

  /// A member's sessions of today as the front desk sees them (their own branch only; admins every branch).
  Future<TodayCheckin> todayFor(String memberId);

  /// Checks the member in with the scanned QR text ([payload]) or the typed 6 digits ([shortCode]);
  /// [sessionId] picks the session when several are open. A refusal throws an `ApiException`
  /// (see [checkinActionOf] for what to offer next).
  Future<CheckinOutcome> submit({String? payload, String? shortCode, String? sessionId});

  /// The front desk checks [memberId] into [sessionId], with the photo at [evidenceUrl] (already uploaded).
  /// A refusal throws an `ApiException`.
  Future<CheckedIn> checkInFor({required String memberId, required String sessionId, required String evidenceUrl});
}
