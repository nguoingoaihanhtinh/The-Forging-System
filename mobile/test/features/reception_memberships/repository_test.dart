import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/features/reception_memberships/data/reception_memberships_api.dart';
import 'package:hvp_forging/features/reception_memberships/data/reception_memberships_repository_impl.dart';

import '../../helpers/scripted_adapter.dart';
import 'desk_harness.dart';
import 'renewal_requests_test.dart' show renewalJson;

void main() {
  late Desk desk;
  late ReceptionMembershipsRepositoryImpl repo;

  void boot(Map<String, Reply> routes) {
    desk = Desk(routes);
    repo =
        ReceptionMembershipsRepositoryImpl(ReceptionMembershipsApi(desk.api));
  }

  test('MEM-12 renewals sends status, q and paging and maps the page',
      () async {
    boot(<String, Reply>{
      'GET /renewal-requests': (_) => okEnvelope(<dynamic>[
            renewalJson('r1', 'Nguyễn Văn A')
          ], meta: <String, dynamic>{
            'page': 1,
            'limit': 20,
            'total': 45,
            'totalPages': 3
          }),
    });
    final page = await repo.renewals(q: 'an', page: 1);
    expect(
        desk.calls('GET /renewal-requests').single.queryParameters,
        <String, dynamic>{
          'status': 'PENDING',
          'page': 1,
          'limit': 20,
          'q': 'an'
        });
    expect(page.hasMore, isTrue);
    final r = page.items.single;
    expect([r.id, r.memberName, r.packageName, r.priceVnd, r.currentEndDate],
        ['r1', 'Nguyễn Văn A', 'BOOK II', 9800000, '2026-11-30']);
  });

  test('MEM-13 approveRenewal posts the evidence URL and returns the message',
      () async {
    boot(<String, Reply>{
      'POST /renewal-requests/r1/approve': (_) =>
          okEnvelope(<String, dynamic>{'message': 'Xong'}),
    });
    expect(await repo.approveRenewal('r1', evidenceUrl: 'http://x/files/a.jpg'),
        'Xong');
    expect(desk.calls('POST /renewal-requests/r1/approve').single.data,
        <String, dynamic>{'paymentEvidenceUrl': 'http://x/files/a.jpg'});
  });

  test('MEM-14 cancel calls post the reason to the request and the package',
      () async {
    boot(<String, Reply>{
      'POST /renewal-requests/r1/cancel': (_) =>
          okEnvelope(<String, dynamic>{'id': 'r1'}),
      'POST /memberships/ms1/cancel': (_) =>
          okEnvelope(<String, dynamic>{'membership': <String, dynamic>{}}),
    });
    await repo.cancelRenewal('r1', reason: 'Sai gói');
    await repo.cancelMembership('ms1', reason: 'Học viên xin huỷ');
    expect(desk.calls('POST /renewal-requests/r1/cancel').single.data,
        <String, dynamic>{'reason': 'Sai gói'});
    expect(desk.calls('POST /memberships/ms1/cancel').single.data,
        <String, dynamic>{'reason': 'Học viên xin huỷ'});
  });
}
