import 'profile_models.dart';

/// What the Hồ sơ tab needs from the backend.
/// Presentation depends on this interface only; tests override it with a fake.
abstract class ProfileRepository {
  /// `GET /me/profile`
  Future<MemberProfile> getProfile();

  /// `PATCH /me/profile`. Only the given keys are sent (`fullName`, `phone`, `email`,
  /// `avatarUrl`); a null value clears the field. Returns the new profile.
  /// Throws `ApiException` (`CONTACT_REQUIRED`, `PHONE_TAKEN`, `EMAIL_TAKEN`, ...).
  Future<MemberProfile> updateProfile(Map<String, Object?> changes);
}
