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

  Future<ApiEnvelope> approveRenewal(String id, String evidenceUrl) =>
      _api.post('/renewal-requests/$id/approve',
          body: <String, dynamic>{'paymentEvidenceUrl': evidenceUrl});

  Future<ApiEnvelope> cancelRenewal(String id, String reason) =>
      _api.post('/renewal-requests/$id/cancel',
          body: <String, dynamic>{'reason': reason});

  Future<ApiEnvelope> cancelMembership(String id, String reason) =>
      _api.post('/memberships/$id/cancel',
          body: <String, dynamic>{'reason': reason});

  Future<ApiEnvelope> member(String memberId) => _api.get('/members/$memberId');

  Future<ApiEnvelope> memberMembership(String memberId) =>
      _api.get('/members/$memberId/membership');
}
