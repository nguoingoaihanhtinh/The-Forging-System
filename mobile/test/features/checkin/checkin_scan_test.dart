import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hvp_forging/app/route_paths.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/design/hvp_text_styles.dart';
import 'package:hvp_forging/core/design/hvp_theme.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
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
import 'package:hvp_forging/features/checkin/presentation/checkin_scan_screen.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';

const _payload = 'HVP|Q1|1|58739402|3fa9c01b7d2e44a0';

CheckedIn _checkedIn({bool already = false, int? remaining = 31}) => CheckedIn(
      alreadyCheckedIn: already,
      checkedInAt: DateTime.utc(2026, 11, 2, 10, 50),
      sessionId: 's1',
      sessionTitle: 'Evening class',
      startsAt: DateTime.utc(2026, 11, 2, 11, 0),
      endsAt: DateTime.utc(2026, 11, 2, 12, 0),
      branchName: 'HVP The Corner',
      sessionsRemaining: remaining,
      message: 'Buổi tập đang chờ Coach xác nhận.',
    );

CheckinSession _open(String id, String title, int hour) => CheckinSession(
      sessionId: id,
      title: title,
      sessionType: 'GROUP',
      isExam: false,
      startsAt: DateTime.utc(2026, 11, 2, hour),
      endsAt: DateTime.utc(2026, 11, 2, hour + 1),
      branchId: 'q1',
      branchName: 'HVP The Corner',
      coachName: 'Minh',
      state: CheckinState.open,
      canCheckin: true,
      opensAt: DateTime.utc(2026, 11, 2, hour - 1),
      closesAt: DateTime.utc(2026, 11, 2, hour + 1),
    );

ApiException _refusal(String code, String message, String action, {int status = 422}) =>
    ApiException(code: code, message: message, statusCode: status, details: <String, dynamic>{'action': action});

class FakeCheckin implements CheckinRepository {
  /// Answers of successive `submit` calls: an outcome, an exception, or a future.
  final List<Object> answers = <Object>[];
  final List<({String? payload, String? sessionId})> calls = <({String? payload, String? sessionId})>[];
  int todayCalls = 0;

  @override
  Future<TodayCheckin> today() async {
    todayCalls++;
    return const TodayCheckin(date: '2026-11-02', eligibility: CheckinEligibility(canCheckin: true), sessions: <CheckinSession>[]);
  }

  @override
  Future<CheckinOutcome> submit({String? payload, String? shortCode, String? sessionId}) async {
    calls.add((payload: payload, sessionId: sessionId));
    final next = answers.removeAt(0);
    if (next is Future<CheckinOutcome>) return next;
    if (next is CheckinOutcome) return next;
    throw next;
  }
}

/// A scanner that "reads" [_payload] (or another code) when its buttons are pressed. The buttons sit at the
/// bottom, clear of the viewfinder frame drawn over the middle of the camera view.
Widget _fakeScanner(BuildContext context, ValueChanged<String> onCode) => Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextButton(onPressed: () => onCode(_payload), child: const Text('READ-A')),
            TextButton(onPressed: () => onCode('HVP|Q1|1|58739403|bbbbbbbbbbbbbbbb'), child: const Text('READ-B')),
          ],
        ),
      ),
    );

Future<GoRouter> _pumpScan(WidgetTester tester, FakeCheckin repo, {String? sessionId = 's1'}) async {
  HvpFonts.useGoogleFonts = false;
  hvpEntranceEnabled = false;
  usePhoneSurface(tester);
  final router = GoRouter(routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, __) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('TAB'),
              TextButton(onPressed: () => context.push(StudentPaths.checkinScanFor(sessionId)), child: const Text('OPEN-SCAN')),
            ],
          ),
        ),
      ),
    ),
    GoRoute(
      path: StudentPaths.checkinScan,
      builder: (_, state) => CheckinScanScreen(sessionId: state.uri.queryParameters['sessionId']),
    ),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('member'),
      checkinRepositoryProvider.overrideWithValue(repo),
      qrScannerBuilderProvider.overrideWithValue(_fakeScanner),
    ],
    child: MaterialApp.router(theme: HvpTheme.light(), darkTheme: HvpTheme.dark(), themeMode: ThemeMode.dark, routerConfig: router),
  ));
  await tester.pump();
  await tester.tap(find.text('OPEN-SCAN'));
  // The viewfinder animates forever while scanning, so pumpAndSettle would never return.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return router;
}

Future<void> _read(WidgetTester tester, [String button = 'READ-A']) async {
  await tester.tap(find.text(button));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  test('CHK-07 repository sends the scanned code and reads the three kinds of answer', () async {
    final dio = createApiDio(
      config: const AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(const StoredTokens(accessToken: 'member-token', refreshToken: 'refresh')),
    );
    Map<String, dynamic> sessionJson(String id, String title, int hour) => <String, dynamic>{
          'sessionId': id,
          'title': title,
          'sessionType': 'GROUP',
          'isExam': false,
          'startsAt': '2026-11-02T$hour:00:00.000Z',
          'endsAt': '2026-11-02T${hour + 1}:00:00.000Z',
          'branch': <String, dynamic>{'id': 'q1', 'name': 'HVP The Corner'},
          'coach': <String, dynamic>{'id': 'c', 'fullName': 'Minh'},
          'checkin': <String, dynamic>{
            'state': 'OPEN',
            'canCheckin': true,
            'opensAt': '2026-11-02T10:00:00.000Z',
            'closesAt': '2026-11-02T13:00:00.000Z',
          },
        };
    final adapter = ScriptedAdapter((request) {
      final body = request.data as Map<String, dynamic>;
      if (body['payload'] == 'choose') {
        return okEnvelope(<String, dynamic>{
          'status': 'CHOOSE_SESSION',
          'sessions': <dynamic>[sessionJson('a', 'Class A', 11), sessionJson('b', 'Class B', 12)],
        });
      }
      if (body['payload'] == 'expired') {
        return errorEnvelope(422, 'CHECKIN_CODE_EXPIRED', 'Mã QR đã hết hạn', details: <String, dynamic>{'action': 'RESCAN'});
      }
      return okEnvelope(<String, dynamic>{
        'status': 'CHECKED_IN',
        'alreadyCheckedIn': body['sessionId'] == 'again',
        'checkedInAt': '2026-11-02T10:50:12.000Z',
        'session': <String, dynamic>{
          'sessionId': 's1',
          'title': 'Evening',
          'startsAt': '2026-11-02T11:00:00.000Z',
          'endsAt': '2026-11-02T12:00:00.000Z',
          'branch': <String, dynamic>{'id': 'q1', 'name': 'HVP The Corner'},
        },
        'sessionsRemaining': null,
        'message': 'Check-in thành công.',
      }, status: body['sessionId'] == 'again' ? 200 : 201);
    });
    dio.httpClientAdapter = adapter;
    final repo = CheckinRepositoryImpl(ApiClient(dio));

    final done = await repo.submit(payload: _payload, sessionId: 's1');
    expect(adapter.requests.last.path, '/me/checkin');
    expect(adapter.requests.last.data, <String, dynamic>{'payload': _payload, 'sessionId': 's1'});
    expect(done, isA<CheckedIn>().having((c) => c.alreadyCheckedIn, 'alreadyCheckedIn', isFalse).having((c) => c.sessionsRemaining, 'sessionsRemaining', isNull));
    expect((done as CheckedIn).sessionTitle, 'Evening');
    expect(done.branchName, 'HVP The Corner');

    expect(((await repo.submit(payload: _payload, sessionId: 'again')) as CheckedIn).alreadyCheckedIn, isTrue);

    final choose = await repo.submit(payload: 'choose');
    expect(choose, isA<ChooseSession>());
    expect((choose as ChooseSession).sessions.map((s) => s.title), <String>['Class A', 'Class B']);

    final error = await repo.submit(payload: 'expired').then<Object>((_) => 'no error', onError: (Object e) => e);
    expect(error, isA<ApiException>().having((e) => e.code, 'code', 'CHECKIN_CODE_EXPIRED'));
    expect(checkinActionOf(error), CheckinAction.rescan);
  });

  test('actions are read from the error details, anything else means none', () {
    expect(checkinActionOf(_refusal('X', 'm', 'WAIT')), CheckinAction.wait);
    expect(checkinActionOf(_refusal('X', 'm', 'ASK_FRONT_DESK')), CheckinAction.askFrontDesk);
    expect(checkinActionOf(_refusal('X', 'm', 'RENEW_PACKAGE')), CheckinAction.renewPackage);
    expect(checkinActionOf(_refusal('X', 'm', 'GO_TO_BRANCH')), CheckinAction.goToBranch);
    expect(checkinActionOf(_refusal('X', 'm', 'SOMETHING_NEW')), CheckinAction.none);
    expect(checkinActionOf(const ApiException(code: 'X', message: 'm')), CheckinAction.none);
    expect(checkinActionOf(StateError('not an api error')), CheckinAction.none);
  });

  testWidgets('a scanned code checks the member in and shows the result', (tester) async {
    final repo = FakeCheckin()..answers.add(_checkedIn());
    await _pumpScan(tester, repo);
    expect(find.text('Đưa mã QR trên màn hình phòng tập vào khung'), findsOneWidget);

    await _read(tester);
    expect(repo.calls, <({String? payload, String? sessionId})>[(payload: _payload, sessionId: 's1')]);
    expect(find.text('CHECK-IN THÀNH CÔNG'), findsOneWidget);
    expect(find.text('Evening class'), findsOneWidget);
    expect(find.text('Gói tập còn 31 buổi'), findsOneWidget);
    expect(find.text('Buổi tập đang chờ Coach xác nhận.'), findsOneWidget);
  });

  testWidgets('leaves the scanner when done, back to the tab', (tester) async {
    final repo = FakeCheckin()..answers.add(_checkedIn());
    await _pumpScan(tester, repo);
    await _read(tester);
    await tester.tap(find.text('XONG'));
    await tester.pumpAndSettle();
    expect(find.text('TAB'), findsOneWidget);
    expect(find.text('CHECK-IN THÀNH CÔNG'), findsNothing);
  });

  testWidgets('tells the member when the session was already checked in, and stays silent about a package without a limit', (tester) async {
    final repo = FakeCheckin()..answers.add(_checkedIn(already: true, remaining: null));
    await _pumpScan(tester, repo);
    await _read(tester);
    expect(find.text('ĐÃ CHECK-IN RỒI'), findsOneWidget);
    expect(find.textContaining('Gói tập còn'), findsNothing);
  });

  testWidgets('asks which session when several are open and sends the same code with the one picked', (tester) async {
    final repo = FakeCheckin()..answers.addAll(<Object>[ChooseSession(<CheckinSession>[_open('a', 'Class A', 11), _open('b', 'Class B', 12)]), _checkedIn()]);
    await _pumpScan(tester, repo, sessionId: null);
    await _read(tester);
    expect(find.text('Bạn check-in buổi nào?'), findsOneWidget);
    expect(find.text('Class A'), findsOneWidget);

    await tester.tap(find.text('Class B'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.calls, <({String? payload, String? sessionId})>[(payload: _payload, sessionId: null), (payload: _payload, sessionId: 'b')]);
    expect(find.text('CHECK-IN THÀNH CÔNG'), findsOneWidget);
  });

  testWidgets('can back out of the session choice and keep scanning', (tester) async {
    final repo = FakeCheckin()..answers.add(ChooseSession(<CheckinSession>[_open('a', 'Class A', 11), _open('b', 'Class B', 12)]));
    await _pumpScan(tester, repo, sessionId: null);
    await _read(tester);
    await tester.tap(find.text('HỦY'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Bạn check-in buổi nào?'), findsNothing);
    expect(find.text('Đưa mã QR trên màn hình phòng tập vào khung'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100)); // lets the viewfinder animation start its first tick
  });

  testWidgets('shows why a code was refused and lets the member scan again', (tester) async {
    final repo = FakeCheckin()
      ..answers.addAll(<Object>[_refusal('CHECKIN_CODE_EXPIRED', 'Mã QR đã hết hạn, vui lòng quét lại.', 'RESCAN'), _checkedIn()]);
    await _pumpScan(tester, repo);
    await _read(tester);
    expect(find.text('Mã QR đã hết hạn, vui lòng quét lại.'), findsOneWidget);

    await tester.tap(find.text('QUÉT LẠI'));
    await tester.pump(const Duration(milliseconds: 400));
    // The camera still sees the refused code: it is not sent again...
    await _read(tester);
    expect(repo.calls.length, 1);
    // ...but a different code is.
    await _read(tester, 'READ-B');
    expect(repo.calls.length, 2);
    expect(find.text('CHECK-IN THÀNH CÔNG'), findsOneWidget);
  });

  testWidgets('goes back to the tab after a refusal that scanning again cannot fix', (tester) async {
    final repo = FakeCheckin()..answers.add(_refusal('CHECKIN_CLOSED', 'Đã hết giờ check-in. Vui lòng nhờ lễ tân check-in hộ.', 'ASK_FRONT_DESK'));
    await _pumpScan(tester, repo);
    await _read(tester);
    expect(find.text('Đã hết giờ check-in. Vui lòng nhờ lễ tân check-in hộ.'), findsOneWidget);
    expect(find.text('QUÉT LẠI'), findsNothing);
    await tester.tap(find.text('QUAY LẠI'));
    await tester.pumpAndSettle();
    expect(find.text('TAB'), findsOneWidget);
  });

  testWidgets('retries the same code after a lost connection', (tester) async {
    final repo = FakeCheckin()
      ..answers.addAll(<Object>[const ApiException(code: ApiErrorCodes.network, message: 'Không có kết nối mạng.'), _checkedIn()]);
    await _pumpScan(tester, repo);
    await _read(tester);
    expect(find.text('Không có kết nối mạng.'), findsOneWidget);
    await tester.tap(find.text('THỬ LẠI'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.calls.map((c) => c.payload), <String?>[_payload, _payload]);
    expect(find.text('CHECK-IN THÀNH CÔNG'), findsOneWidget);
  });

  testWidgets('ignores the codes the camera keeps reporting while a check-in is in flight', (tester) async {
    final pending = Completer<CheckinOutcome>();
    final repo = FakeCheckin()..answers.add(pending.future);
    await _pumpScan(tester, repo);
    await tester.tap(find.text('READ-A'));
    await tester.pump();
    expect(find.text('Đang check-in…'), findsOneWidget);
    // The camera is hidden behind the overlay but keeps reading: a second tap on the (covered) button still reaches it.
    final readB = tester.widget<TextButton>(find.widgetWithText(TextButton, 'READ-B'));
    readB.onPressed!();
    readB.onPressed!();
    await tester.pump();
    expect(repo.calls.length, 1);
    pending.complete(_checkedIn());
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('CHECK-IN THÀNH CÔNG'), findsOneWidget);
    expect(repo.calls.length, 1);
  });

  testWidgets('refreshes the Check-in tab after a successful check-in', (tester) async {
    final repo = FakeCheckin()..answers.add(_checkedIn());
    await _pumpScan(tester, repo);
    final before = repo.todayCalls;
    await _read(tester);
    await tester.pump(const Duration(milliseconds: 400));
    // The scan screen reads today's list for the picked-session chip; success invalidates it, so it loads again.
    expect(repo.todayCalls, greaterThan(before));
  });
}
