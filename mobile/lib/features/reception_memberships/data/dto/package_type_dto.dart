import '../../../../core/utils/json_utils.dart';
import '../../domain/package_type.dart';

int? _intOrNull(JsonMap j, String key) => j[key] == null ? null : intOf(j, key);

PackageType packageTypeFromJson(JsonMap j) => PackageType(
      id: str(j, 'id'),
      name: str(j, 'name'),
      isTrial: boolOf(j, 'isTrial'),
      priceVnd: _intOrNull(j, 'priceVnd'),
      durationDays: _intOrNull(j, 'durationDays'),
      totalSessions: _intOrNull(j, 'totalSessions'),
    );
