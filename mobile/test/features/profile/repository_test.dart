import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/profile/data/profile_api.dart';
import 'package:hvp_forging/features/profile/data/profile_repository_impl.dart';

import '../../helpers/scripted_adapter.dart';

const AppConfig _config =
    AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp');

({ProfileRepositoryImpl repo, ScriptedAdapter adapter}) _build(
    ResponseBody Function(RequestOptions) handler) {
  final dio = createApiDio(
    config: _config,
    tokens: MemoryTokenStore(
        const StoredTokens(accessToken: 'a', refreshToken: 'r')),
  );
  final adapter = ScriptedAdapter(handler);
  dio.httpClientAdapter = adapter;
  return (
    repo: ProfileRepositoryImpl(ProfileApi(ApiClient(dio))),
    adapter: adapter
  );
}

const Map<String, dynamic> _json = <String, dynamic>{
  'userId': 'u1',
  'fullName': 'Nguyễn Văn A',
  'email': 'a@example.com',
  'phone': '0912345678',
  'avatarUrl': null,
  'homeBranchName': 'HVP Boxing - The Corner',
  'joinedAt': '2026-10-01T03:00:00.000Z',
  'status': 'FROZEN',
  'currentRankId': 'r3',
};

void main() {
  test('getProfile maps GET /me/profile', () async {
    final t = _build((o) => okEnvelope(_json));

    final p = await t.repo.getProfile();

    expect(t.adapter.requests.single.path, '/me/profile');
    expect(t.adapter.requests.single.method, 'GET');
    expect(p.fullName, 'Nguyễn Văn A');
    expect(p.avatarUrl, isNull);
    expect(p.joinedAt, DateTime.utc(2026, 10, 1, 3));
    expect(p.statusLabel, 'Đóng băng');
    expect(p.currentRankId, 'r3');
  });

  test('getProfile surfaces the API error message', () async {
    final t = _build(
        (o) => errorEnvelope(404, 'NOT_FOUND', 'Không có hồ sơ học viên'));

    expect(
      t.repo.getProfile(),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', 'Không có hồ sơ học viên')),
    );
  });

  test('updateProfile PATCHes only the given keys, null included', () async {
    final t =
        _build((o) => okEnvelope(<String, dynamic>{..._json, 'email': null}));

    final p = await t.repo
        .updateProfile(<String, Object?>{'email': null, 'fullName': 'B'});

    final request = t.adapter.requests.single;
    expect(request.method, 'PATCH');
    expect(request.path, '/me/profile');
    expect(request.data, <String, Object?>{'email': null, 'fullName': 'B'});
    expect(p.email, isNull);
  });

  test('updateProfile surfaces PHONE_TAKEN', () async {
    final t = _build((o) => errorEnvelope(
        409, 'PHONE_TAKEN', 'Số điện thoại này đã được đăng ký.'));

    expect(
      t.repo.updateProfile(<String, Object?>{'phone': '0900000000'}),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'PHONE_TAKEN')),
    );
  });
}
