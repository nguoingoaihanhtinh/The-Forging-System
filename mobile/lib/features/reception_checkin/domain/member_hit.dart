/// A learner found at the front desk by name, phone or member code.
class MemberHit {
  const MemberHit({
    required this.id,
    required this.memberCode,
    required this.fullName,
    required this.status,
    this.phone,
    this.avatarUrl,
    this.rankName,
    this.packageName,
  });

  final String id;
  final String memberCode;
  final String fullName;
  final String? phone;
  final String? avatarUrl;

  /// `ACTIVE`, `FROZEN` or `INACTIVE`.
  final String status;
  final String? rankName;

  /// The package running now, if any.
  final String? packageName;
}

class MemberSearchResult {
  const MemberSearchResult({required this.items, required this.total});

  final List<MemberHit> items;

  /// Everyone matching, which can be more than [items] (the first page only).
  final int total;

  bool get hasMoreThanShown => total > items.length;
}

abstract interface class MemberSearchRepository {
  /// Learners matching [query] in name, phone, email or member code, by name.
  Future<MemberSearchResult> search(String query);
}

/// Shortest text worth searching: one letter would match half the academy.
const int memberSearchMinLength = 2;
