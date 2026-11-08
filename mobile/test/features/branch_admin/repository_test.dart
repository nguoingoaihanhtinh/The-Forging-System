import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/branch_admin/data/branch_admin_api.dart';
import 'package:hvp_forging/features/branch_admin/data/branch_admin_repository_impl.dart';
import 'package:hvp_forging/features/branch_admin/domain/branch_admin_repository.dart';
import 'package:hvp_forging/features/branch_admin/domain/branch_input.dart';

import '../../helpers/scripted_adapter.dart';

const AppConfig _config =
    AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp');

void main() {
  test('getBranches asks for inactive branches and maps the new fields',
      () async {
    final dio = createApiDio(
      config: _config,
      tokens: MemoryTokenStore(
          const StoredTokens(accessToken: 'a', refreshToken: 'r')),
    );
    final adapter = ScriptedAdapter((o) => okEnvelope(<dynamic>[
          <String, dynamic>{
            'id': 'b1',
            'code': 'Q1',
            'name': 'The Corner',
            'address': '12 Nguyễn Huệ',
            'openingHours': '06:00 – 21:30',
            'latitude': 10.7769,
            'longitude': '106.7009',
            'geofenceRadiusM': 150,
            'isActive': true,
            'qrVersion': '1',
          },
          <String, dynamic>{
            'id': 'b2',
            'code': 'Q2',
            'name': 'Old',
            'address': null,
            'isActive': false
          },
        ]));
    dio.httpClientAdapter = adapter;
    final repo = BranchAdminRepositoryImpl(BranchAdminApi(ApiClient(dio)));

    final list = await repo.getBranches();

    final req = adapter.requests.single;
    expect(req.path, '/branches');
    expect(req.queryParameters['includeInactive'], true);
    expect(list.first.addressLine, '12 Nguyễn Huệ · 06:00 – 21:30');
    expect(list.first.qrVersion, '1');
    expect(list.first.latitude, 10.7769);
    expect(list.first.longitude, 106.7009);
    expect(list.first.geofenceRadiusM, 150);
    expect(list.last.latitude, isNull);
    expect(list.last.geofenceRadiusM, 100);
    expect(list.last.isActive, isFalse);
    expect(list.last.addressLine, '');
    expect(visibleBranches(list, showInactive: false).map((b) => b.id),
        <String>['b1']);
    expect(visibleBranches(list, showInactive: true), hasLength(2));
  });

  group('create and update', () {
    late ScriptedAdapter adapter;
    late BranchAdminRepositoryImpl repo;

    setUp(() {
      final dio = createApiDio(
        config: _config,
        tokens: MemoryTokenStore(
            const StoredTokens(accessToken: 'a', refreshToken: 'r')),
      );
      adapter = ScriptedAdapter((o) => o.method == 'POST'
          ? okEnvelope(
              <String, dynamic>{'id': 'b9', 'code': 'Q9', 'name': 'New'},
              status: 201)
          : okEnvelope(
              <String, dynamic>{'id': 'b9', 'code': 'Q9', 'name': 'Renamed'}));
      dio.httpClientAdapter = adapter;
      repo = BranchAdminRepositoryImpl(BranchAdminApi(ApiClient(dio)));
    });

    test('create posts every field and returns the branch', () async {
      final b = await repo.create(const BranchInput(
          code: 'Q9', name: ' New ', address: '', latitude: 10.5));

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/admin/branches');
      expect(req.data, <String, dynamic>{
        'code': 'Q9',
        'name': 'New',
        'address': null,
        'openingHours': null,
        'latitude': 10.5,
        'longitude': null,
        'geofenceRadiusM': 100,
      });
      expect(b.id, 'b9');
    });

    test('update patches the branch id and clears empty fields', () async {
      final b = await repo.update(
          'b9', const BranchInput(code: 'Q9', name: 'Renamed'));

      final req = adapter.requests.single;
      expect(req.method, 'PATCH');
      expect(req.path, '/admin/branches/b9');
      expect(req.data['address'], isNull);
      expect(req.data.containsKey('address'), isTrue);
      expect(b.name, 'Renamed');
    });
  });

  test('setActive posts isActive and the reason', () async {
    final dio = createApiDio(
      config: _config,
      tokens: MemoryTokenStore(
          const StoredTokens(accessToken: 'a', refreshToken: 'r')),
    );
    final adapter = ScriptedAdapter((o) => okEnvelope(<String, dynamic>{
          'id': 'b9',
          'code': 'Q9',
          'name': 'X',
          'isActive': false
        }));
    dio.httpClientAdapter = adapter;
    final repo = BranchAdminRepositoryImpl(BranchAdminApi(ApiClient(dio)));

    final b = await repo.setActive('b9', isActive: false, reason: 'Đóng cửa');

    final req = adapter.requests.single;
    expect(req.method, 'POST');
    expect(req.path, '/admin/branches/b9/status');
    expect(
        req.data, <String, dynamic>{'isActive': false, 'reason': 'Đóng cửa'});
    expect(b.isActive, isFalse);
  });

  test('getQr and rotateQr map the payload and send the reason', () async {
    final dio = createApiDio(
      config: _config,
      tokens: MemoryTokenStore(
          const StoredTokens(accessToken: 'a', refreshToken: 'r')),
    );
    final adapter = ScriptedAdapter((o) => okEnvelope(<String, dynamic>{
          'branchId': 'b9',
          'code': 'Q9',
          'qrVersion': '4',
          'payload': 'HVP|Q9|4'
        }));
    dio.httpClientAdapter = adapter;
    final repo = BranchAdminRepositoryImpl(BranchAdminApi(ApiClient(dio)));

    final qr = await repo.getQr('b9');
    expect(adapter.requests.last.path, '/branches/b9/qr');
    expect(qr.payload, 'HVP|Q9|4');
    expect(qr.qrVersion, '4');

    await repo.rotateQr('b9');
    expect(adapter.requests.last.method, 'POST');
    expect(adapter.requests.last.path, '/admin/branches/b9/qr/rotate');
    expect(adapter.requests.last.data, <String, dynamic>{});

    await repo.rotateQr('b9', reason: 'Mất bảng QR');
    expect(
        adapter.requests.last.data, <String, dynamic>{'reason': 'Mất bảng QR'});
  });

  test('BranchRules follow the API limits', () {
    expect(BranchRules.code('q1'), isNull);
    expect(BranchRules.code('a'), isNotNull);
    expect(BranchRules.code('has space'), isNotNull);
    expect(BranchRules.name('A'), isNotNull);
    expect(BranchRules.latitude(''), isNull);
    expect(BranchRules.latitude('91'), isNotNull);
    expect(BranchRules.latitude('abc'), isNotNull);
    expect(BranchRules.longitude('-180'), isNull);
    expect(BranchRules.longitude('181'), isNotNull);
    expect(BranchRules.radius('9'), isNotNull);
    expect(BranchRules.radius('5000'), isNull);
    expect(BranchRules.radius(''), isNotNull);
  });
}
