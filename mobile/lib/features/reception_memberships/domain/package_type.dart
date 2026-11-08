/// A package on sale (`GET /package-types`). Null numbers mean "not limited" / "no price yet".
class PackageType {
  const PackageType(
      {required this.id,
      required this.name,
      this.isTrial = false,
      this.priceVnd,
      this.durationDays,
      this.totalSessions});

  final String id;
  final String name;
  final bool isTrial;
  final int? priceVnd;
  final int? durationDays;
  final int? totalSessions;
}
