import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hvp_forging/app/route_paths.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/design/hvp_text_styles.dart';
import 'package:hvp_forging/core/design/hvp_theme.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/core/widgets/entrance.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/checkin/data/checkin_repository_impl.dart';
import 'package:hvp_forging/features/checkin/domain/checkin_outcome.dart';
import 'package:hvp_forging/features/checkin/domain/checkin_repository.dart';
import 'package:hvp_forging/features/checkin/domain/checkin_session.dart';
import 'package:hvp_forging/features/checkin/presentation/checkin_providers.dart';
import 'package:hvp_forging/features/checkin/presentation/checkin_tab.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';

CheckinSession _session(
  String id,
  String title, {
  required DateTime startsAt,
  CheckinState state = CheckinState.open,
  String? message,
  DateTime? checkedInAt,
}) =>
    CheckinSession(
      sessionId: id,
      title: title,
      sessionType: 'GROUP',
      isExam: false,
      startsAt: startsAt,
      endsAt: startsAt.add(const Duration(hours: 1)),
      branchId: 'q1',
      branchName: 'HVP The Corner',
      coachName: 'Minh',
      state: state,
      canCheckin: state == CheckinState.open,
      message: message,
      opensAt: startsAt.subtract(const Duration(minutes: 45)),
      closesAt: startsAt.add(const Duration(minutes: 30)),
      checkedInAt: checkedInAt,
    );

class FakeCheckin implements CheckinRepository {
  FakeCheckin(this.data);
  final TodayCheckin data;

  @override
  Future<TodayCheckin> today() async => data;

  @override
  Future<CheckinOutcome> submit({String? payload, String? shortCode, String? sessionId}) =>
      throw UnimplementedError('the Check-in tab never submits');
}

TodayCheckin _day(List<CheckinSession> sessions, {CheckinEligibility? eligibility}) => TodayCheckin(
      date: '2026-11-02',
      eligibility: eligibility ?? const CheckinEligibility(canCheckin: true),
      sessions: sessions,
    );

/// The tab inside a router so the button's navigation (and the session it passes on) can be seen.
Future<void> _pumpTab(WidgetTester tester, TodayCheckin data) async {
  HvpFonts.useGoogleFonts = false;
  hvpEntranceEnabled = false;
  usePhoneSurface(tester);
  final router = GoRouter(routes: <RouteBase>[
    GoRoute(path: '/', builder: (_, __) => const Scaffold(body: CheckinTab())),
    GoRoute(
      path: StudentPaths.checkinScan,
      builder: (_, state) => Scaffold(body: Text('scan:${state.uri.queryParameters['sessionId']}')),
    ),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('member'),
      checkinRepositoryProvider.overrideWithValue(FakeCheckin(data)),
    ],
    child: MaterialApp.router(theme: HvpTheme.light(), darkTheme: HvpTheme.dark(), themeMode: ThemeMode.dark, routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tapScan(WidgetTester tester) async {
  await tester.tap(find.text('QUÉT MÃ CHECK-IN'));
  await tester.pumpAndSettle();
}

void main() {
  test('CHK-06 repository maps the sessions, their check-in state and the eligibility', () async {
    final dio = createApiDio(
      config: const AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(const StoredTokens(accessToken: 'member-token', refreshToken: 'refresh')),
    );
    Map<String, dynamic> raw(String id, String state, {bool can = false, String? reason, String? message, String? at}) => <String, dynamic>{
          'sessionId': id,
          'title': 'Evening $id',
          'sessionType': 'GROUP',
          'isExam': id == 'exam',
          'startsAt': '2026-11-02T11:00:00.000Z',
          'endsAt': '2026-11-02T12:00:00.000Z',
          'branch': <String, dynamic>{'id': 'q1', 'name': 'HVP The Corner'},
          'coach': <String, dynamic>{'id': 'c1', 'fullName': 'Minh'},
          'checkin': <String, dynamic>{
            'state': state,
            'canCheckin': can,
            'reason': reason,
            'message': message,
            'opensAt': '2026-11-02T10:15:00.000Z',
            'closesAt': '2026-11-02T11:30:00.000Z',
            'checkedInAt': at,
          },
        };
    final adapter = ScriptedAdapter((request) => okEnvelope(<String, dynamic>{
          'date': '2026-11-02',
          'eligibility': <String, dynamic>{'canCheckin': false, 'code': 'MEMBERSHIP_INVALID', 'message': 'Gói hết hạn'},
          'sessions': <dynamic>[
            raw('a', 'OPEN', can: true),
            raw('b', 'NOT_YET_OPEN', reason: 'NOT_YET_OPEN', message: 'Chưa đến giờ'),
            raw('exam', 'CHECKED_IN', reason: 'ALREADY_CHECKED_IN', at: '2026-11-02T10:50:00.000Z'),
            raw('d', 'SOMETHING_NEW'),
          ],
        }));
    dio.httpClientAdapter = adapter;
    final today = await CheckinRepositoryImpl(ApiClient(dio)).today();

    expect(adapter.requests.last.path, '/me/checkin/sessions');
    expect(today.date, '2026-11-02');
    expect(today.eligibility.canCheckin, isFalse);
    expect(today.eligibility.code, 'MEMBERSHIP_INVALID');
    expect(today.sessions.map((s) => s.state), <CheckinState>[
      CheckinState.open,
      CheckinState.notYetOpen,
      CheckinState.checkedIn,
      CheckinState.blocked, // a state the app does not know is never offered
    ]);
    expect(today.sessions[0].canCheckin, isTrue);
    expect(today.sessions[0].branchName, 'HVP The Corner');
    expect(today.sessions[0].coachName, 'Minh');
    expect(today.sessions[1].message, 'Chưa đến giờ');
    expect(today.sessions[2].isExam, isTrue);
    expect(today.sessions[2].checkedInAt, DateTime.utc(2026, 11, 2, 10, 50));
  });

  test('the default session is the open one that starts nearest to now', () {
    final now = DateTime.utc(2026, 11, 2, 11, 0);
    final early = _session('early', 'Early', startsAt: now.subtract(const Duration(minutes: 20)));
    final soon = _session('soon', 'Soon', startsAt: now.add(const Duration(minutes: 10)));
    final late = _session('late', 'Late', startsAt: now.add(const Duration(hours: 3)));
    final closed = _session('closed', 'Closed', startsAt: now, state: CheckinState.closed);
    expect(defaultCheckinSession(<CheckinSession>[late, early, soon, closed], now)?.sessionId, 'soon');
    expect(defaultCheckinSession(<CheckinSession>[closed], now), isNull);
    expect(defaultCheckinSession(const <CheckinSession>[], now), isNull);
  });

  testWidgets('lists the sessions with their status and pre-selects the nearest open one', (tester) async {
    final now = DateTime.now();
    await _pumpTab(
      tester,
      _day(<CheckinSession>[
        _session('far', 'Late class', startsAt: now.add(const Duration(hours: 4))),
        _session('near', 'Evening class', startsAt: now.add(const Duration(minutes: 15))),
      ]),
    );
    expect(find.text('Evening class'), findsOneWidget);
    expect(find.text('Late class'), findsOneWidget);
    expect(find.text('ĐANG MỞ CHECK-IN'), findsNWidgets(2));
    await _tapScan(tester);
    expect(find.text('scan:near'), findsOneWidget);
  });

  testWidgets('lets the learner pick another open session but not one that cannot be checked into', (tester) async {
    final now = DateTime.now();
    await _pumpTab(
      tester,
      _day(<CheckinSession>[
        _session('a', 'Class A', startsAt: now.add(const Duration(minutes: 15))),
        _session('b', 'Class B', startsAt: now.add(const Duration(hours: 2))),
        _session('c', 'Class C', startsAt: now.subtract(const Duration(hours: 3)), state: CheckinState.closed, message: 'Đã hết giờ check-in.'),
      ]),
    );
    expect(find.text('ĐÃ ĐÓNG CHECK-IN'), findsOneWidget);
    expect(find.text('Đã hết giờ check-in.'), findsOneWidget);

    await tester.tap(find.text('Class B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Class C')); // closed: the choice stays on B
    await tester.pumpAndSettle();
    await _tapScan(tester);
    expect(find.text('scan:b'), findsOneWidget);
  });

  testWidgets('marks a session already checked into and still offers the next one', (tester) async {
    final now = DateTime.now();
    await _pumpTab(
      tester,
      _day(<CheckinSession>[
        _session('done', 'Morning class', startsAt: now.subtract(const Duration(hours: 5)), state: CheckinState.checkedIn, checkedInAt: now.subtract(const Duration(hours: 5))),
        _session('next', 'Evening class', startsAt: now.add(const Duration(minutes: 20))),
      ]),
    );
    expect(find.textContaining('ĐÃ CHECK-IN'), findsOneWidget);
    await _tapScan(tester);
    expect(find.text('scan:next'), findsOneWidget);
  });

  testWidgets('explains why check-in is not possible and keeps the scan button off', (tester) async {
    final now = DateTime.now();
    await _pumpTab(
      tester,
      _day(
        <CheckinSession>[_session('a', 'Class A', startsAt: now, state: CheckinState.blocked, message: 'Gói tập của bạn đã hết hạn.')],
        eligibility: const CheckinEligibility(canCheckin: false, code: 'MEMBERSHIP_INVALID', message: 'Gói tập của bạn đã hết hạn.'),
      ),
    );
    expect(find.text('Gói tập của bạn đã hết hạn.'), findsNWidgets(2)); // the banner and the card
    await tester.tap(find.text('QUÉT MÃ CHECK-IN'));
    await tester.pumpAndSettle();
    expect(find.textContaining('scan:'), findsNothing);
  });

  testWidgets('says so on a day without sessions', (tester) async {
    await _pumpTab(tester, _day(const <CheckinSession>[]));
    expect(find.text('HÔM NAY KHÔNG CÓ BUỔI TẬP'), findsOneWidget);
    await tester.tap(find.text('QUÉT MÃ CHECK-IN'));
    await tester.pumpAndSettle();
    expect(find.textContaining('scan:'), findsNothing);
  });
}
