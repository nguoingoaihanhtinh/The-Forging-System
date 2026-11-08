import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/network/upload_service.dart';
import 'package:hvp_forging/core/utils/image_picking.dart';
import 'package:hvp_forging/features/auth/domain/auth_user.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_providers.dart';
import 'package:hvp_forging/features/fighter_record/presentation/providers/fighter_record_providers.dart';
import 'package:hvp_forging/features/profile/presentation/providers/profile_providers.dart';
import 'package:hvp_forging/features/profile/presentation/widgets/profile_details.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/test_harness.dart';
import '../fighter_record/fixtures.dart';
import 'fixtures.dart';

const _url = 'https://api.hvp.vn/files/hvp/avatars/u/x.jpg';

class _FakeUpload implements UploadService {
  Object? error;
  final List<UploadPurpose> purposes = <UploadPurpose>[];

  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    UploadPurpose purpose = UploadPurpose.evidence,
  }) async {
    purposes.add(purpose);
    if (error != null) throw error!;
    return _url;
  }
}

class _AvatarProbe extends ConsumerWidget {
  const _AvatarProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Text('avatar:${ref.watch(currentUserProvider)?.avatarUrl}');
}

PickedImage? _picked = PickedImage(
    bytes: Uint8List.fromList(<int>[1, 2, 3]),
    filename: 'a.jpg',
    mimeType: 'image/jpeg');

Future<void> _pump(
    WidgetTester tester, FakeProfileRepository repo, _FakeUpload upload) async {
  await pumpHvp(
    tester,
    const Scaffold(
      body: SingleChildScrollView(
          child: Column(children: <Widget>[_AvatarProbe(), ProfileDetails()])),
    ),
    overrides: <Override>[
      profileRepositoryProvider.overrideWithValue(repo),
      uploadServiceProvider.overrideWithValue(upload),
      profileImagePickerProvider.overrideWithValue((_) async => _picked),
      fighterRecordRepositoryProvider
          .overrideWithValue(FakeFighterRecordRepository()),
      authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(restored: makeUser(AppRole.student))),
    ],
  );
  await tester.pumpAndSettle();
}

Future<void> _pickPhoto(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Chỉnh sửa hồ sơ'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Đổi ảnh đại diện'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Chụp ảnh'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => _picked = PickedImage(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      filename: 'a.jpg',
      mimeType: 'image/jpeg'));

  testWidgets('the camera badge only exists in edit mode', (tester) async {
    await _pump(tester, FakeProfileRepository(), _FakeUpload());
    expect(find.byTooltip('Đổi ảnh đại diện'), findsNothing);
    await tester.tap(find.byTooltip('Chỉnh sửa hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Đổi ảnh đại diện'), findsOneWidget);
  });

  testWidgets(
      'picking a photo uploads it as avatar, PATCHes avatarUrl and updates the user',
      (tester) async {
    final repo = FakeProfileRepository()
      ..onUpdate = (_) async => sampleProfile(avatarUrl: _url);
    final upload = _FakeUpload();
    await _pump(tester, repo, upload);
    await _pickPhoto(tester);

    expect(upload.purposes, <UploadPurpose>[UploadPurpose.avatar]);
    expect(repo.updates.single, <String, Object?>{'avatarUrl': _url});
    expect(find.text('avatar:$_url'), findsOneWidget);
    expect(find.text('Đã cập nhật ảnh đại diện.'), findsOneWidget);
  });

  testWidgets('cancelling the picker does nothing', (tester) async {
    _picked = null;
    final repo = FakeProfileRepository();
    final upload = _FakeUpload();
    await _pump(tester, repo, upload);
    await _pickPhoto(tester);

    expect(upload.purposes, isEmpty);
    expect(repo.updates, isEmpty);
  });

  testWidgets('an upload error shows its message and saves nothing',
      (tester) async {
    final repo = FakeProfileRepository();
    final upload = _FakeUpload()
      ..error = const ApiException(code: 'X', message: 'Ảnh quá lớn.');
    await _pump(tester, repo, upload);
    await _pickPhoto(tester);

    expect(find.text('Ảnh quá lớn.'), findsOneWidget);
    expect(repo.updates, isEmpty);
    expect(find.text('avatar:null'), findsOneWidget);
  });

  testWidgets('a rejected avatar URL shows the API message', (tester) async {
    final repo = FakeProfileRepository()
      ..onUpdate = (_) async => throw const ApiException(
          code: 'INVALID_AVATAR_URL',
          message:
              'Ảnh đại diện không hợp lệ. Vui lòng tải ảnh lên trước rồi chọn lại.');
    await _pump(tester, repo, _FakeUpload());
    await _pickPhoto(tester);

    expect(find.textContaining('Ảnh đại diện không hợp lệ'), findsOneWidget);
    expect(find.text('avatar:null'), findsOneWidget);
  });
}
