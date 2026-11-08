import '../../../core/utils/json_utils.dart';
import '../domain/reception_memberships_repository.dart';
import '../domain/renewal_models.dart';
import 'dto/renewal_dto.dart';
import 'reception_memberships_api.dart';

class ReceptionMembershipsRepositoryImpl
    implements ReceptionMembershipsRepository {
  ReceptionMembershipsRepositoryImpl(this._api);

  final ReceptionMembershipsApi _api;

  @override
  Future<RenewalPage> renewals(
          {String? q,
          String status = 'PENDING',
          int page = 1,
          int limit = 20}) async =>
      renewalPageFromEnvelope(
          await _api.renewals(q: q, status: status, page: page, limit: limit));

  @override
  Future<String> approveRenewal(String id,
          {required String evidenceUrl}) async =>
      str((await _api.approveRenewal(id, evidenceUrl)).dataMap, 'message');

  @override
  Future<void> cancelRenewal(String id, {required String reason}) async {
    await _api.cancelRenewal(id, reason);
  }

  @override
  Future<void> cancelMembership(String id, {required String reason}) async {
    await _api.cancelMembership(id, reason);
  }
}
