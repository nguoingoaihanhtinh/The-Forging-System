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
}
