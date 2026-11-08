import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/branch/branch.dart';
import 'package:hvp_forging/core/branch/branch_providers.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/branch_qr/data/branch_code_repository_impl.dart';
import 'package:hvp_forging/features/branch_qr/domain/branch_code.dart';
import 'package:hvp_forging/features/branch_qr/presentation/branch_qr_providers.dart';
import 'package:hvp_forging/features/branch_qr/presentation/branch_qr_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';

final DateTime _t0 = DateTime.utc(2026, 11, 2, 10, 0, 0);

/// The payload of the QR on screen.
String _shown(WidgetTester tester) {
  final key = tester.widget<QrImageView>(find.byType(QrImageView)).key! as ValueKey<String>;
  return key.value.substring('qr:'.length);
}

BranchCheckinCode _code(String payload, String digits, DateTime expiresAt, {Duration offset = Duration.zero}) => BranchCheckinCode(
      branchId: 'q1',
      branchCode: 'Q1',
      payload: payload,
      shortCode: digits,
      ttlSeconds: 30,
      expiresAt: expiresAt,
      serverOffset: offset,
    );

/// Hands out codes of 30 seconds like the server, working off the test clock.
class FakeCodes implements BranchCodeRepository {
  FakeCodes(this.clock);

  final DateTime Function() clock;
  int calls = 0;

  /// Calls that fail, counted from the first one (1 = the first call).
  final Set<int> failing = <int>{};

  @override
  Future<BranchCheckinCode> current(String branchId) async {
    calls++;
    if (failing.contains(calls)) throw const ApiException(code: ApiErrorCodes.network, message: 'Không có kết nối mạng.');
    final now = clock();
    final windowStart = DateTime.fromMillisecondsSinceEpoch(now.millisecondsSinceEpoch ~/ 30000 * 30000, isUtc: true);
    final n = windowStart.millisecondsSinceEpoch ~/ 30000;
    final digits = (100000 + n % 800000).toString();
    return _code('HVP|Q1|1|$n|sig', digits, windowStart.add(const Duration(seconds: 30)));
  }
}

class _Harness {
  _Harness(this.tester) : now = _t0;

  final WidgetTester tester;
  DateTime now;
  late final FakeCodes repo = FakeCodes(() => now);

  Future<void> pump({String branchName = 'HVP The Corner'}) async {
    await pumpHvp(tester, const BranchQrScreen(branchId: 'q1'), overrides: [
      currentUserIdProvider.overrideWithValue('desk'),
      branchCodeRepositoryProvider.overrideWithValue(repo),
      branchQrClockProvider.overrideWithValue(() => now),
      branchesProvider.overrideWith((ref) async => <Branch>[Branch(id: 'q1', code: 'Q1', name: branchName)]),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Moves the clock and lets the screen's one-second timer fire for each second.
  Future<void> advance(int seconds) async {
    for (var i = 0; i < seconds; i++) {
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('the code and its clock', () {
    test('runs on the server clock, so a wrong tablet clock still changes codes on time', () {
      // The tablet is 7 seconds behind the server.
      final code = _code('p', '123456', _t0.add(const Duration(seconds: 30)), offset: const Duration(seconds: 7));
      final deviceNow = _t0.subtract(const Duration(seconds: 7)).add(const Duration(seconds: 10)); // = server 10s past the start
      expect(code.remainingAt(deviceNow), const Duration(seconds: 20));
      expect(code.fractionLeftAt(deviceNow), closeTo(20 / 30, 1e-9));
      expect(code.remainingAt(_t0.add(const Duration(minutes: 1))).isNegative, isTrue);
      expect(code.fractionLeftAt(_t0.add(const Duration(minutes: 5))), 0);
    });

    test('splits the 6 digits for reading aloud', () {
      expect(_code('p', '482913', _t0).shortCodeSpaced, '482 913');
      expect(_code('p', '12', _t0).shortCodeSpaced, '12');
    });

    test('CHK-12 repository reads the code and measures the server clock offset', () async {
      final dio = createApiDio(
        config: const AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
        tokens: MemoryTokenStore(const StoredTokens(accessToken: 'desk-token', refreshToken: 'refresh')),
      );
      final adapter = ScriptedAdapter((request) => okEnvelope(<String, dynamic>{
            'branchId': 'q1',
            'branchCode': 'Q1',
            'qrVersion': '1',
            'payload': 'HVP|Q1|1|58739402|3fa9c01b7d2e44a0',
            'shortCode': '482913',
            'ttlSeconds': 30,
            'expiresAt': '2026-11-02T10:00:30.000Z',
            'serverTime': '2026-11-02T10:00:12.000Z',
          }));
      dio.httpClientAdapter = adapter;
      // The tablet clock reads 10:00:05 when the request leaves and 10:00:05.200 when the answer is back.
      final ticks = <DateTime>[DateTime.utc(2026, 11, 2, 10, 0, 5), DateTime.utc(2026, 11, 2, 10, 0, 5, 200)];
      final repo = BranchCodeRepositoryImpl(ApiClient(dio), now: () => ticks.removeAt(0));

      final code = await repo.current('q1');
      expect(adapter.requests.last.path, '/branches/q1/checkin-code');
      expect(code.payload, 'HVP|Q1|1|58739402|3fa9c01b7d2e44a0');
      expect(code.shortCode, '482913');
      expect(code.ttlSeconds, 30);
      expect(code.expiresAt, DateTime.utc(2026, 11, 2, 10, 0, 30));
      // Server 10:00:12 against the tablet's 10:00:05.100 (mid-trip): about 6.9 seconds ahead.
      expect(code.serverOffset.inMilliseconds, closeTo(6900, 1));
    });
  });

  group('the screen', () {
    testWidgets('shows the QR, the digits, the branch and the time left', (tester) async {
      final h = _Harness(tester)..now = _t0.add(const Duration(seconds: 12)); // 18 s into the 30 s window
      await h.pump();

      expect(find.byType(QrImageView), findsOneWidget);
      expect(_shown(tester), startsWith('HVP|Q1|1|'));
      expect(find.textContaining('Check-in · HVP The Corner'), findsOneWidget);
      expect(find.text('MÃ NHẬP TAY'), findsOneWidget);
      expect(find.text('Đổi mã sau 18s'), findsOneWidget);
      final digits = h.repo.calls == 1 ? tester.widget<Text>(find.byWidgetPredicate((w) => w is Text && RegExp(r'^\d{3} \d{3}$').hasMatch(w.data ?? ''))).data : '';
      expect(digits, matches(RegExp(r'^\d{3} \d{3}$')));
    });

    testWidgets('counts down and fetches the next code only when this one runs out', (tester) async {
      final h = _Harness(tester)..now = _t0.add(const Duration(seconds: 12));
      await h.pump();
      final firstPayload = _shown(tester);
      expect(h.repo.calls, 1);

      await h.advance(10);
      expect(find.text('Đổi mã sau 8s'), findsOneWidget);
      expect(h.repo.calls, 1); // nothing asked while the code is still good

      await h.advance(9); // past the end of the window
      expect(h.repo.calls, 2);
      expect(_shown(tester), isNot(firstPayload));
      expect(find.text('Đổi mã sau 29s'), findsOneWidget); // the new window began a second ago
    });

    testWidgets('keeps showing the last code and says so when the connection drops, then recovers', (tester) async {
      final h = _Harness(tester)..now = _t0.add(const Duration(seconds: 12));
      h.repo.failing.add(2);
      await h.pump();
      final firstPayload = _shown(tester);

      await h.advance(19); // the code ends, the next request fails
      expect(h.repo.calls, 2);
      expect(find.text('Mất kết nối. Mã có thể đã cũ, đang thử lại…'), findsOneWidget);
      expect(_shown(tester), firstPayload); // still valid for a moment

      await h.advance(3);
      expect(h.repo.calls, 2); // not asking on every tick
      await h.advance(3); // 5 seconds after the failure
      expect(h.repo.calls, 3);
      expect(find.text('Mất kết nối. Mã có thể đã cũ, đang thử lại…'), findsNothing);
      expect(_shown(tester), isNot(firstPayload));
    });

    testWidgets('hides a code that has been dead for longer than a whole window', (tester) async {
      final h = _Harness(tester)..now = _t0.add(const Duration(seconds: 12));
      h.repo.failing.addAll(<int>{2, 3, 4, 5, 6, 7, 8, 9, 10, 11});
      await h.pump();

      await h.advance(18 + 31); // the code ended 31 seconds ago and no new one has arrived
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Đang kết nối lại để lấy mã mới…'), findsOneWidget);
      expect(find.text('--- ---'), findsOneWidget);
    });

    testWidgets('tries again by itself when the very first request fails', (tester) async {
      final h = _Harness(tester)..now = _t0.add(const Duration(seconds: 12));
      h.repo.failing.add(1);
      await h.pump();
      expect(find.byType(QrImageView), findsNothing);
      expect(h.repo.calls, 1);

      await h.advance(5);
      expect(h.repo.calls, 2);
      expect(find.byType(QrImageView), findsOneWidget);
    });
  });
}
