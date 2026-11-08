import 'renewal_models.dart';

/// Everything the front desk (and admin) does on packages and learners.
abstract interface class ReceptionMembershipsRepository {
  /// `GET /renewal-requests`
  Future<RenewalPage> renewals(
      {String? q, String status = 'PENDING', int page = 1, int limit = 20});

  /// `POST /renewal-requests/:id/approve`. Returns the message to show.
  Future<String> approveRenewal(String id, {required String evidenceUrl});
}
