import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/coach_challenges/data/challenge_review_repository.dart';
import 'package:hvp_forging/features/coach_challenges/domain/challenge_review.dart';
import 'package:hvp_forging/features/coach_challenges/presentation/challenge_review_providers.dart';
import 'package:hvp_forging/features/coach_challenges/presentation/challenge_review_tab.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';

class _FakeChallengeReviews implements ChallengeReviewRepository {
  int approved = 0;

  @override
  Future<List<ChallengeReview>> waiting() async => <ChallengeReview>[
        const ChallengeReview(
          participationId: 'participation-1',
          challengeTitle: 'Bao cát bền bỉ',
          memberFullName: 'Nguyễn Văn A',
          memberCode: 'HVP0001',
          progressValue: 5,
          target: 5,
          evidenceUrl: null,
        ),
      ];

  @override
  Future<void> approve(String participationId) async => approved++;
}

void main() {
  test('CHL-06 lists only submitted evidence awaiting the coach', () async {
    final dio = createApiDio(
      config: const AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(const StoredTokens(
          accessToken: 'coach-token', refreshToken: 'refresh-token')),
    );
    final adapter = ScriptedAdapter(
      (_) => okEnvelope(<dynamic>[
        <String, dynamic>{
          'id': 'participation-1',
          'challengeTitle': 'Bao cát bền bỉ',
          'memberFullName': 'Nguyễn Văn A',
          'memberCode': 'HVP0001',
          'progressValue': 5,
          'target': 5,
          'evidenceUrl': 'http://test.local/files/proof.jpg',
        },
      ]),
    );
    dio.httpClientAdapter = adapter;

    final items = await ChallengeReviewRepositoryImpl(ApiClient(dio)).waiting();

    expect(adapter.requests.single.path, '/staff/challenges/participations');
    expect(adapter.requests.single.queryParameters, <String, dynamic>{
      'status': 'AWAITING_COACH',
      'evidence': 'SUBMITTED',
      'page': 1,
      'limit': 100,
    });
    expect(items.single.challengeTitle, 'Bao cát bền bỉ');
    expect(items.single.memberFullName, 'Nguyễn Văn A');
    expect(items.single.evidenceUrl, 'http://test.local/files/proof.jpg');
  });

  test('CHL-06 approves the participation by id', () async {
    final dio = createApiDio(
      config: const AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(const StoredTokens(
          accessToken: 'coach-token', refreshToken: 'refresh-token')),
    );
    final adapter = ScriptedAdapter(
      (_) => okEnvelope(<String, dynamic>{'id': 'participation-1'}),
    );
    dio.httpClientAdapter = adapter;

    await ChallengeReviewRepositoryImpl(ApiClient(dio)).approve('participation-1');

    expect(adapter.requests.single.path,
        '/staff/challenges/participations/participation-1/approve');
  });

  testWidgets('CHL-06 shows the waiting submission for the coach', (tester) async {
    final fake = _FakeChallengeReviews();
    await pumpHvp(
      tester,
      const ChallengeReviewTab(),
      overrides: [
        challengeReviewRepositoryProvider.overrideWithValue(fake),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Duyệt Challenge'), findsOneWidget);
    expect(find.text('Bao cát bền bỉ'), findsOneWidget);
    expect(find.text('Nguyễn Văn A · HVP0001'), findsOneWidget);
    expect(find.text('Tiến độ: 5 / 5'), findsOneWidget);
    expect(find.text('Học viên chưa nộp ảnh minh chứng.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
