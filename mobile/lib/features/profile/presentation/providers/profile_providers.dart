import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/error/api_exception.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/network/upload_service.dart';
import '../../../../core/state/submit_notifier.dart';
import '../../../../core/utils/image_picking.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/profile_api.dart';
import '../../data/profile_repository_impl.dart';
import '../../domain/profile_models.dart';
import '../../domain/profile_repository.dart';

/// Tests override this with a fake repository.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(ProfileApi(ref.watch(apiClientProvider))),
);

/// Watching the user id drops cached data on account switch.
final profileProvider = FutureProvider.autoDispose<MemberProfile>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(profileRepositoryProvider).getProfile();
});

/// `PATCH /me/profile`, then refreshes the cached profile and the signed-in user
/// (so AccountPanel and every HvpAvatar show the new values at once).
Future<void> _patchProfile(Ref ref, Map<String, Object?> changes) async {
  final saved =
      await ref.read(profileRepositoryProvider).updateProfile(changes);
  ref.invalidate(profileProvider);
  ref.read(authControllerProvider.notifier).updateUser((u) => u.withProfile(
        fullName: saved.fullName,
        email: saved.email,
        phone: saved.phone,
        avatarUrl: saved.avatarUrl,
      ));
}

/// Saving the profile: `fieldErrors` holds the `phone` / `email` conflict messages.
class ProfileSaveNotifier extends Notifier<SubmitState> {
  @override
  SubmitState build() => const SubmitState();

  /// Sends [changes]. Returns true on success.
  Future<bool> save(Map<String, Object?> changes) async {
    state = const SubmitState(submitting: true);
    try {
      await _patchProfile(ref, changes);
      state = const SubmitState();
      return true;
    } on ApiException catch (e) {
      state = switch (e.code) {
        'PHONE_TAKEN' =>
          SubmitState(fieldErrors: <String, String>{'phone': e.message}),
        'EMAIL_TAKEN' =>
          SubmitState(fieldErrors: <String, String>{'email': e.message}),
        _ => SubmitState(error: e.message, fieldErrors: e.fieldErrors),
      };
      return false;
    } catch (e) {
      state = SubmitState(error: errorMessage(e));
      return false;
    }
  }

  void reset() => state = const SubmitState();
}

final profileSaveProvider =
    NotifierProvider<ProfileSaveNotifier, SubmitState>(ProfileSaveNotifier.new);

/// AUTH-14: upload the picked photo (purpose avatar), then PATCH its URL.
class ProfileAvatarNotifier extends SubmitNotifier {
  Future<bool> change(PickedImage image) => run(() async {
        final url = await ref.read(uploadServiceProvider).uploadImage(
              bytes: image.bytes,
              filename: image.filename,
              mimeType: image.mimeType,
              purpose: UploadPurpose.avatar,
            );
        await _patchProfile(ref, <String, Object?>{'avatarUrl': url});
      });
}

final profileAvatarProvider =
    NotifierProvider<ProfileAvatarNotifier, SubmitState>(
        ProfileAvatarNotifier.new);

/// Opens camera or gallery. Tests override it (the real picker needs a device).
final profileImagePickerProvider =
    Provider<Future<PickedImage?> Function(ImageSource)>((ref) => pickImage);
