import '../../../core/branch/branch.dart';

/// What the admin branch form sends (`POST /admin/branches`, `PATCH /admin/branches/:id`).
class BranchInput {
  const BranchInput({
    required this.code,
    required this.name,
    this.address,
    this.openingHours,
    this.latitude,
    this.longitude,
    this.geofenceRadiusM = 100,
  });

  final String code;
  final String name;
  final String? address;
  final String? openingHours;
  final double? latitude;
  final double? longitude;
  final int geofenceRadiusM;
}

/// Field rules of docs/api/branches.md. Each returns an error message or null.
abstract final class BranchRules {
  static final RegExp _code = RegExp(r'^[A-Za-z0-9_-]{2,20}$');

  static String? code(String? v) => _code.hasMatch((v ?? '').trim())
      ? null
      : 'Mã gồm 2–20 ký tự: chữ, số, _ hoặc -.';

  static String? name(String? v) {
    final n = (v ?? '').trim().length;
    return n >= 2 && n <= 100 ? null : 'Tên chi nhánh gồm 2–100 ký tự.';
  }

  static String? address(String? v) =>
      (v ?? '').trim().length <= 255 ? null : 'Địa chỉ tối đa 255 ký tự.';

  static String? openingHours(String? v) =>
      (v ?? '').trim().length <= 100 ? null : 'Giờ mở cửa tối đa 100 ký tự.';

  static String? latitude(String? v) => _range(v, -90, 90, 'Vĩ độ');

  static String? longitude(String? v) => _range(v, -180, 180, 'Kinh độ');

  static String? radius(String? v) {
    final n = int.tryParse((v ?? '').trim());
    return n != null && n >= 10 && n <= 5000
        ? null
        : 'Bán kính từ 10 đến 5000 m.';
  }

  /// Empty is allowed (the coordinate is optional).
  static String? _range(String? v, double min, double max, String label) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return null;
    final n = double.tryParse(text);
    return n != null && n >= min && n <= max
        ? null
        : '$label từ ${min.toInt()} đến ${max.toInt()}.';
  }

  /// Text from a coordinate field to a number; empty means "none".
  static double? parseCoordinate(String v) =>
      v.trim().isEmpty ? null : double.parse(v.trim());
}

/// Pre-fills the form from an existing branch.
BranchInput inputOf(Branch b) => BranchInput(
      code: b.code,
      name: b.name,
      address: b.address,
      openingHours: b.openingHours,
      latitude: b.latitude,
      longitude: b.longitude,
      geofenceRadiusM: b.geofenceRadiusM,
    );
