import '../../reception_checkin/domain/member_hit.dart';
import 'member_models.dart';
import 'package_type.dart';
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

  /// `GET /package-types`: the packages on sale.
  Future<List<PackageType>> packageTypes();

  /// `POST /members/:memberId/memberships`. Returns the message to show.
  Future<String> activateMembership(String memberId,
      {required String packageTypeId, required String evidenceUrl});

  /// `POST /members`
  Future<CreatedMember> createMember(
      {required String fullName, required String phone});

  /// `POST /members/:memberId/status` with [status] `ACTIVE` or `FROZEN`.
  Future<void> changeStatus(String memberId,
      {required String status, required String reason});

  /// `GET /members/:memberId/duplicates`: other accounts with the same phone or email.
  Future<List<MemberHit>> duplicates(String memberId);

  /// `POST /admin/members/merge`: moves [dropId] into [keepId]. Cannot be undone.
  Future<void> mergeMembers({required String keepId, required String dropId});
}
