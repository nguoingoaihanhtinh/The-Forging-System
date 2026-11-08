import 'profile_models.dart';

/// What the Hồ sơ tab needs from the backend.
/// Presentation depends on this interface only; tests override it with a fake.
abstract class ProfileRepository {
  /// `GET /me/profile`
  Future<MemberProfile> getProfile();
}
