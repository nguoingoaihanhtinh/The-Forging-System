import '../../../core/utils/json_utils.dart';
import '../domain/membership_models.dart';
import '../domain/membership_repository.dart';
import 'dto/membership_dto.dart';
import 'membership_api.dart';

class MembershipRepositoryImpl implements MembershipRepository {
  MembershipRepositoryImpl(this._api);

  final MembershipApi _api;

  @override
  Future<MyMembership> getMyMembership() async =>
      myMembershipFromJson((await _api.mine()).dataMap);

  @override
  Future<List<PackageType>> listPackageTypes() async =>
      (await _api.packageTypes())
          .dataList
          .map((e) => packageTypeFromJson(asMap(e)))
          .toList(growable: false);

  @override
  Future<void> requestRenewal(
      {required String packageTypeId, String? note}) async {
    final trimmed = note?.trim();
    await _api.requestRenewal(
        packageTypeId, trimmed == null || trimmed.isEmpty ? null : trimmed);
  }
}
