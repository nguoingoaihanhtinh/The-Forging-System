import '../utils/json_utils.dart';

double? _numOrNull(Object? v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

/// Branch directory entry (`GET /branches`). The optional fields are what the
/// admin list uses; `qrVersion` is only sent to staff.
class Branch {
  const Branch({
    required this.id,
    required this.code,
    required this.name,
    this.address,
    this.openingHours,
    this.latitude,
    this.longitude,
    this.geofenceRadiusM = 100,
    this.isActive = true,
    this.qrVersion,
  });

  factory Branch.fromJson(JsonMap j) => Branch(
        id: str(j, 'id'),
        code: str(j, 'code'),
        name: str(j, 'name'),
        address: strOrNull(j, 'address'),
        openingHours: strOrNull(j, 'openingHours'),
        latitude: _numOrNull(j['latitude']),
        longitude: _numOrNull(j['longitude']),
        geofenceRadiusM: intOf(j, 'geofenceRadiusM', 100),
        isActive: boolOf(j, 'isActive', true),
        qrVersion: strOrNull(j, 'qrVersion'),
      );

  final String id;
  final String code;
  final String name;
  final String? address;
  final String? openingHours;
  final double? latitude;
  final double? longitude;
  final int geofenceRadiusM;
  final bool isActive;
  final String? qrVersion;

  /// "address · openingHours", skipping whichever part is missing.
  String get addressLine => <String?>[address, openingHours]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(' · ');
}
