import '../domain/profile_models.dart';
import '../domain/profile_repository.dart';
import 'dto/profile_dto.dart';
import 'profile_api.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._api);

  final ProfileApi _api;

  @override
  Future<MemberProfile> getProfile() async =>
      memberProfileFromJson((await _api.profile()).dataMap);

  @override
  Future<MemberProfile> updateProfile(Map<String, Object?> changes) async =>
      memberProfileFromJson((await _api.update(changes)).dataMap);
}
