import '../../../core/network/api_client.dart';

/// Raw endpoint calls for the member profile.
class ProfileApi {
  ProfileApi(this._api);

  final ApiClient _api;

  Future<ApiEnvelope> profile() => _api.get('/me/profile');

  Future<ApiEnvelope> update(Map<String, Object?> changes) =>
      _api.patch('/me/profile', body: changes);
}
