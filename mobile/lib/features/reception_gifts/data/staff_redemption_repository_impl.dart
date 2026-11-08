import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/staff_redemption.dart';

class StaffRedemptionRepositoryImpl implements StaffRedemptionRepository {
  StaffRedemptionRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<StaffRedemptionPage> list(
      {String? status, String? query, int page = 1}) async {
    final response =
        await _api.get('/staff/armory/redemptions', query: <String, dynamic>{
      'page': page,
      'limit': 20,
      if (status != null) 'status': status,
      if (query?.trim().isNotEmpty ?? false) 'q': query!.trim(),
    });
    final meta = PageMeta.fromJson(response.meta);
    return StaffRedemptionPage(
      items: response.dataList
          .map((value) => _fromJson(asMap(value)))
          .toList(growable: false),
      page: meta.page,
      totalPages: meta.totalPages,
      total: meta.total,
    );
  }

  @override
  Future<void> approve(String redemptionId, {String? reason}) => _api.post(
        '/staff/armory/redemptions/$redemptionId/approve',
        body: <String, dynamic>{
          if (reason?.trim().isNotEmpty ?? false) 'reason': reason!.trim()
        },
      );

  @override
  Future<void> deliver(String redemptionId,
          {String? reason, String? evidenceUrl}) =>
      _api.post(
        '/staff/armory/redemptions/$redemptionId/deliver',
        body: <String, dynamic>{
          if (reason?.trim().isNotEmpty ?? false) 'reason': reason!.trim(),
          if (evidenceUrl?.trim().isNotEmpty ?? false)
            'deliveryEvidenceUrl': evidenceUrl!.trim(),
        },
      );

  @override
  Future<void> reject(String redemptionId, {required String reason}) =>
      _api.post(
        '/staff/armory/redemptions/$redemptionId/reject',
        body: <String, dynamic>{'reason': reason.trim()},
      );

  StaffRedemption _fromJson(Map<String, dynamic> json) => StaffRedemption(
        id: str(json, 'id'),
        redemptionCode: str(json, 'redemptionCode'),
        memberId: str(json, 'memberId'),
        memberCode: str(json, 'memberCode'),
        memberFullName: str(json, 'memberFullName'),
        rewardId: str(json, 'rewardId'),
        rewardName: str(json, 'rewardName'),
        rewardSku: str(json, 'rewardSku'),
        pickupBranchId: str(json, 'pickupBranchId'),
        pickupBranchName: str(json, 'pickupBranchName'),
        marksCost: intOf(json, 'marksCost'),
        status: str(json, 'status'),
        requestedAt: dateOrNull(json, 'requestedAt') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        reason: strOrNull(json, 'reason'),
      );
}
