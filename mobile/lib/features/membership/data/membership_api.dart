import '../../../core/network/api_client.dart';

class MembershipApi {
  MembershipApi(this._api);

  final ApiClient _api;

  Future<ApiEnvelope> mine() => _api.get('/me/membership');

  Future<ApiEnvelope> packageTypes() => _api.get('/package-types');

  Future<ApiEnvelope> requestRenewal(String packageTypeId, String? note) =>
      _api.post('/me/renewal-requests', body: <String, dynamic>{
        'packageTypeId': packageTypeId,
        if (note != null) 'note': note,
      });

  Future<ApiEnvelope> myRenewalRequests() =>
      _api.get('/me/renewal-requests', query: <String, dynamic>{'limit': 50});
}
