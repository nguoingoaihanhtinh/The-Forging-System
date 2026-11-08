import '../../../../core/utils/json_utils.dart';
import '../../domain/profile_models.dart';

MemberProfile memberProfileFromJson(JsonMap j) => MemberProfile(
      userId: str(j, 'userId'),
      fullName: str(j, 'fullName'),
      email: strOrNull(j, 'email'),
      phone: strOrNull(j, 'phone'),
      avatarUrl: strOrNull(j, 'avatarUrl'),
      homeBranchName: strOrNull(j, 'homeBranchName'),
      joinedAt: dateOrNull(j, 'joinedAt'),
      status: str(j, 'status', 'ACTIVE'),
      currentRankId: strOrNull(j, 'currentRankId'),
    );
