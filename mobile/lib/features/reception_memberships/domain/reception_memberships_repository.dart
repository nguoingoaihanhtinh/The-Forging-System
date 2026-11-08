import 'member_models.dart';
import 'renewal_models.dart';

/// Everything the front desk (and admin) does on packages and learners.
abstract interface class ReceptionMembershipsRepository {
  /// `GET /renewal-requests`
  Future<RenewalPage> renewals(
      {String? q, String status = 'PENDING', int page = 1, int limit = 20});

  /// `POST /renewal-requests/:id/approve`. Returns the message to show.
  Future<String> approveRenewal(String id, {required String evidenceUrl});

  /// `POST /renewal-requests/:id/cancel`
  Future<void> cancelRenewal(String id, {required String reason});

  /// `POST /memberships/:id/cancel`
  Future<void> cancelMembership(String id, {required String reason});

  /// `GET /members/:memberId` and `GET /members/:memberId/membership`, together.
  Future<MemberOverview> memberOverview(String memberId);
}
