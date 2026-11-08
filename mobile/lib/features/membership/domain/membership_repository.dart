import 'membership_models.dart';

/// What the "Gói tập" screen needs from the backend.
abstract class MembershipRepository {
  /// `GET /me/membership`
  Future<MyMembership> getMyMembership();

  /// `GET /package-types`: every package on sale.
  Future<List<PackageType>> listPackageTypes();

  /// `POST /me/renewal-requests`
  Future<void> requestRenewal({required String packageTypeId, String? note});

  /// `GET /me/renewal-requests`, newest first. First page only (limit 50).
  Future<List<RenewalRequest>> listMyRenewalRequests();
}
