import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/branch_code.dart';

class BranchCodeRepositoryImpl implements BranchCodeRepository {
  BranchCodeRepositoryImpl(this.api, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final ApiClient api;
  final DateTime Function() _now;

  @override
  Future<BranchCheckinCode> current(String branchId) async {
    final sent = _now().toUtc();
    final j = (await api.get('/branches/$branchId/checkin-code')).dataMap;
    final received = _now().toUtc();
    final serverTime = dateOrNull(j, 'serverTime') ?? received;
    // The answer was computed about half-way through the round trip.
    final deviceAtServer = sent.add(Duration(microseconds: received.difference(sent).inMicroseconds ~/ 2));
    return BranchCheckinCode(
      branchId: str(j, 'branchId', branchId),
      branchCode: str(j, 'branchCode'),
      payload: str(j, 'payload'),
      shortCode: str(j, 'shortCode'),
      ttlSeconds: intOf(j, 'ttlSeconds', 30),
      expiresAt: dateOrNull(j, 'expiresAt') ?? serverTime.add(const Duration(seconds: 30)),
      serverOffset: serverTime.difference(deviceAtServer),
    );
  }
}
