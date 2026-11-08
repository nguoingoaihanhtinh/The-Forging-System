import '../../../core/network/api_client.dart';

/// Raw endpoint calls; mapping to entities happens in `dto/`.
class ReceptionMembershipsApi {
  ReceptionMembershipsApi(this._api);

  final ApiClient _api;

  Future<ApiEnvelope> renewals(
          {String? q,
          required String status,
          required int page,
          required int limit}) =>
      _api.get('/renewal-requests', query: <String, dynamic>{
        'status': status,
        'page': page,
        'limit': limit,
        if (q != null && q.isNotEmpty) 'q': q,
      });
}
