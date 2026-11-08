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
import 'package:hvp_forging/features/reception_checkin/domain/member_hit.dart';
import 'package:hvp_forging/features/reception_checkin/presentation/assisted_checkin_controller.dart';
import 'package:hvp_forging/features/reception_checkin/presentation/assisted_checkin_screen.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';

const _lan = MemberHit(id: 'm1', memberCode: 'HVP-AB12CD', fullName: 'Nguyễn Thị Lan', phone: '0912345678', status: 'ACTIVE', packageName: 'BOOK I');
const _photo = 'http://localhost:4000/files/evidence/desk.jpg';

CheckedIn _done({bool already = false}) => CheckedIn(
      alreadyCheckedIn: already,
      checkedInAt: DateTime.utc(2026, 11, 2, 11, 45),
      sessionId: 's1',
      sessionTitle: 'Evening class',
      startsAt: DateTime.utc(2026, 11, 2, 11),
      endsAt: DateTime.utc(2026, 11, 2, 12),
      branchName: 'HVP The Corner',
      sessionsRemaining: 31,
      message: 'Đã check-in hộ học viên. Buổi tập đang chờ Coach xác nhận.',
    );

final _session = CheckinSession(
  sessionId: 's1',
  title: 'Evening class',
  sessionType: 'GROUP',
  isExam: false,
  startsAt: DateTime.utc(2026, 11, 2, 11),
  endsAt: DateTime.utc(2026, 11, 2, 12),
  branchId: 'q1',
  branchName: 'HVP The Corner',
  coachName: 'Minh',
  state: CheckinState.closed,
  canCheckin: false,
  opensAt: DateTime.utc(2026, 11, 2, 10),
  closesAt: DateTime.utc(2026, 11, 2, 11, 30),
);

ApiException _refusal(String code, String message, String action, {int status = 422}) =>
    ApiException(code: code, message: message, statusCode: status, details: <String, dynamic>{'action': action});

class FakeDesk implements CheckinRepository {
  /// Answers of successive check-ins: a result, an exception or a future.
  final List<Object> answers = <Object>[];
  final List<({String memberId, String sessionId, String evidenceUrl})> calls = <({String memberId, String sessionId, String evidenceUrl})>[];
  int todayForCalls = 0;

  @override
  Future<TodayCheckin> today() => throw UnimplementedError();

  @override
  Future<TodayCheckin> todayFor(String memberId) async {
    todayForCalls++;
    return TodayCheckin(date: '2026-11-02', eligibility: const CheckinEligibility(canCheckin: true), sessions: <CheckinSession>[_session]);
  }

  @override
  Future<CheckinOutcome> submit({String? payload, String? shortCode, String? sessionId}) => throw UnimplementedError();

  @override
  Future<CheckedIn> checkInFor({required String memberId, required String sessionId, required String evidenceUrl}) async {
    calls.add((memberId: memberId, sessionId: sessionId, evidenceUrl: evidenceUrl));
    final next = answers.removeAt(0);
    if (next is Future<CheckedIn>) return next;
    if (next is CheckedIn) return next;
    throw next;
  }
}

/// A photo field with buttons instead of a camera.
Widget _fakePhotoField(BuildContext context, ValueChanged<String?> onChanged) => Wrap(
      children: <Widget>[
        TextButton(onPressed: () => onChanged(_photo), child: const Text('TAKE-PHOTO')),
        TextButton(onPressed: () => onChanged(null), child: const Text('REMOVE-PHOTO')),
      ],
    );

Future<void> _pump(WidgetTester tester, FakeDesk repo) async {
  HvpFonts.useGoogleFonts = false;
  hvpEntranceEnabled = false;
  usePhoneSurface(tester);
  final router = GoRouter(routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, __) => Scaffold(
        body: Column(
          children: <Widget>[
            const Text('LIST'),
            TextButton(
              onPressed: () => context.push(ReceptionPaths.assistedCheckin('m1', 's1'), extra: _lan),
              child: const Text('OPEN'),
            ),
          ],
        ),
      ),
    ),
    GoRoute(
      path: ReceptionPaths.assistedCheckinPattern,
      builder: (_, state) => AssistedCheckinScreen(
        memberId: state.pathParameters['memberId']!,
        sessionId: state.pathParameters['sessionId']!,
        member: state.extra is MemberHit ? state.extra! as MemberHit : null,
      ),
    ),
    GoRoute(path: ReceptionPaths.memberships, builder: (_, __) => const Scaffold(body: Text('MEMBERSHIPS'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('desk'),
      checkinRepositoryProvider.overrideWithValue(repo),
      assistedPhotoFieldBuilderProvider.overrideWithValue(_fakePhotoField),
    ],
    child: MaterialApp.router(theme: HvpTheme.light(), darkTheme: HvpTheme.dark(), themeMode: ThemeMode.dark, routerConfig: router),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.text('TAKE-PHOTO'));
  await tester.pump();
  await tester.tap(find.text('XÁC NHẬN CHECK-IN HỘ'));
  await tester.pumpAndSettle();
}

void main() {
  test('CHK-11 repository sends the session and the photo and reads the result', () async {
    final dio = createApiDio(
      config: const AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(const StoredTokens(accessToken: 'desk-token', refreshToken: 'refresh')),
    );
    final adapter = ScriptedAdapter((request) => okEnvelope(<String, dynamic>{
          'status': 'CHECKED_IN',
          'alreadyCheckedIn': false,
          'checkedInAt': '2026-11-02T11:45:00.000Z',
          'session': <String, dynamic>{
            'sessionId': 's1',
            'title': 'Evening class',
            'startsAt': '2026-11-02T11:00:00.000Z',
            'endsAt': '2026-11-02T12:00:00.000Z',
            'branch': <String, dynamic>{'id': 'q1', 'name': 'HVP The Corner'},
          },
          'sessionsRemaining': 31,
          'message': 'Đã check-in hộ học viên.',
        }, status: 201));
    dio.httpClientAdapter = adapter;
    final result = await CheckinRepositoryImpl(ApiClient(dio)).checkInFor(memberId: 'm1', sessionId: 's1', evidenceUrl: _photo);
    expect(adapter.requests.last.path, '/members/m1/checkin');
    expect(adapter.requests.last.data, <String, dynamic>{'sessionId': 's1', 'evidenceUrl': _photo});
    expect(result.sessionTitle, 'Evening class');
    expect(result.sessionsRemaining, 31);
    expect(result.alreadyCheckedIn, isFalse);
  });

  testWidgets('shows who and what, and will not send without a photo', (tester) async {
    final repo = FakeDesk()..answers.add(_done());
    await _pump(tester, repo);
    expect(find.text('Nguyễn Thị Lan'), findsOneWidget);
    expect(find.text('Evening class'), findsOneWidget);
    expect(find.text('Chụp ảnh học viên tại quầy để tiếp tục.'), findsOneWidget);

    await tester.tap(find.text('XÁC NHẬN CHECK-IN HỘ'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
  });

  testWidgets('sends the member, the session and the photo, then shows the result', (tester) async {
    final repo = FakeDesk()..answers.add(_done());
    await _pump(tester, repo);
    final before = repo.todayForCalls;
    await _confirm(tester);

    expect(repo.calls, <({String memberId, String sessionId, String evidenceUrl})>[(memberId: 'm1', sessionId: 's1', evidenceUrl: _photo)]);
    expect(find.text('CHECK-IN THÀNH CÔNG'), findsOneWidget);
    expect(find.text('Đã check-in hộ học viên. Buổi tập đang chờ Coach xác nhận.'), findsOneWidget);
    expect(repo.todayForCalls, greaterThan(before)); // the member's list is refreshed behind it

    await tester.tap(find.text('XONG'));
    await tester.pumpAndSettle();
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('removing the photo takes the confirm button away again', (tester) async {
    final repo = FakeDesk()..answers.add(_done());
    await _pump(tester, repo);
    await tester.tap(find.text('TAKE-PHOTO'));
    await tester.pump();
    expect(find.text('Chụp ảnh học viên tại quầy để tiếp tục.'), findsNothing);
    await tester.tap(find.text('REMOVE-PHOTO'));
    await tester.pump();
    expect(find.text('Chụp ảnh học viên tại quầy để tiếp tục.'), findsOneWidget);
    await tester.tap(find.text('XÁC NHẬN CHECK-IN HỘ'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
  });

  testWidgets('tells the desk when the member was already checked in', (tester) async {
    final repo = FakeDesk()..answers.add(_done(already: true));
    await _pump(tester, repo);
    await _confirm(tester);
    expect(find.text('ĐÃ CHECK-IN RỒI'), findsOneWidget);
  });

  testWidgets('a session that is over is refused, without telling the desk to ask the front desk', (tester) async {
    final repo = FakeDesk()..answers.add(_refusal('CHECKIN_CLOSED', 'Buổi tập đã kết thúc, không thể check-in.', 'ASK_FRONT_DESK'));
    await _pump(tester, repo);
    await _confirm(tester);
    expect(find.text('ĐÃ HẾT GIỜ CHECK-IN'), findsOneWidget);
    expect(find.text('Buổi tập đã kết thúc, không thể check-in.'), findsOneWidget);
    expect(find.text('Bạn có thể nhờ lễ tân tại quầy check-in hộ.'), findsNothing);
    await tester.tap(find.text('QUAY LẠI'));
    await tester.pumpAndSettle();
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('a refused photo goes back to the form to take another one', (tester) async {
    final repo = FakeDesk()..answers.add(_refusal('INVALID_CHECKIN_EVIDENCE', 'Ảnh minh chứng không hợp lệ.', 'ATTACH_PHOTO', status: 400));
    await _pump(tester, repo);
    await _confirm(tester);
    expect(find.text('Ảnh minh chứng không hợp lệ.'), findsOneWidget);

    await tester.tap(find.text('CHỤP LẠI ẢNH'));
    await tester.pumpAndSettle();
    expect(find.text('Chụp ảnh học viên tại quầy để tiếp tục.'), findsOneWidget); // back on the form, photo cleared
    expect(find.text('TAKE-PHOTO'), findsOneWidget);
  });

  testWidgets('a package that is over leads to the front desk packages tab', (tester) async {
    final repo = FakeDesk()..answers.add(_refusal('MEMBERSHIP_INVALID', 'Gói tập đã hết hạn hoặc hết số buổi.', 'RENEW_PACKAGE'));
    await _pump(tester, repo);
    await _confirm(tester);
    await tester.tap(find.text('GIA HẠN GÓI TẬP'));
    await tester.pumpAndSettle();
    expect(find.text('MEMBERSHIPS'), findsOneWidget);
  });

  testWidgets('retries the same photo after a lost connection', (tester) async {
    final repo = FakeDesk()..answers.addAll(<Object>[const ApiException(code: ApiErrorCodes.network, message: 'Không có kết nối mạng.'), _done()]);
    await _pump(tester, repo);
    await _confirm(tester);
    expect(find.text('MẤT KẾT NỐI'), findsOneWidget);
    await tester.tap(find.text('THỬ LẠI'));
    await tester.pumpAndSettle();
    expect(repo.calls.map((c) => c.evidenceUrl), <String>[_photo, _photo]);
    expect(find.text('CHECK-IN THÀNH CÔNG'), findsOneWidget);
  });

  test('the controller never sends the same check-in twice at once', () async {
    final pending = Completer<CheckedIn>();
    final repo = FakeDesk()..answers.add(pending.future);
    final container = ProviderContainer(overrides: [checkinRepositoryProvider.overrideWithValue(repo), currentUserIdProvider.overrideWithValue('desk')]);
    addTearDown(container.dispose);
    final controller = container.read(assistedCheckinProvider.notifier);

    final first = controller.submit(memberId: 'm1', sessionId: 's1', evidenceUrl: _photo);
    await controller.submit(memberId: 'm1', sessionId: 's1', evidenceUrl: _photo); // a second tap while the first is in flight
    expect(repo.calls.length, 1);
    pending.complete(_done());
    await first;
    expect(container.read(assistedCheckinProvider), isA<AssistedDone>());
  });
}
