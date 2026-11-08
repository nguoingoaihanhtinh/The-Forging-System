import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/api_exception.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/state/submit_notifier.dart';
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

/// Saving the profile: `fieldErrors` holds the `phone` / `email` conflict messages.
class ProfileSaveNotifier extends Notifier<SubmitState> {
  @override
  SubmitState build() => const SubmitState();

  /// Sends [changes] and refreshes the cached profile and the signed-in user.
  /// Returns true on success.
  Future<bool> save(Map<String, Object?> changes) async {
    state = const SubmitState(submitting: true);
    try {
      final saved =
          await ref.read(profileRepositoryProvider).updateProfile(changes);
      ref.invalidate(profileProvider);
      ref.read(authControllerProvider.notifier).updateUser((u) => u.withProfile(
            fullName: saved.fullName,
            email: saved.email,
            phone: saved.phone,
            avatarUrl: saved.avatarUrl,
          ));
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
