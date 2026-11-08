import 'package:hvp_forging/features/membership/domain/membership_models.dart';
import 'package:hvp_forging/features/membership/domain/membership_repository.dart';

/// Scripted [MembershipRepository]; unset calls fail loudly.
class FakeMembershipRepository implements MembershipRepository {
  FakeMembershipRepository(
    this.membership, {
    this.packages,
    this.request,
  });

  final Future<MyMembership> Function() membership;
  final Future<List<PackageType>> Function()? packages;
  final Future<void> Function(String packageTypeId, String? note)? request;

  int membershipCalls = 0;
  int packageCalls = 0;
  final List<({String packageTypeId, String? note})> requests =
      <({String packageTypeId, String? note})>[];

  @override
  Future<MyMembership> getMyMembership() {
    membershipCalls++;
    return membership();
  }

  @override
  Future<List<PackageType>> listPackageTypes() {
    packageCalls++;
    return packages!();
  }

  @override
  Future<void> requestRenewal(
      {required String packageTypeId, String? note}) async {
    requests.add((packageTypeId: packageTypeId, note: note));
    await request!(packageTypeId, note);
  }
}
