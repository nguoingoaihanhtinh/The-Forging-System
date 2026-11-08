/// Display rules for the package screen (pure, unit-tested).
library;

import '../../../core/utils/formatters.dart';
import 'membership_models.dart';

/// `30/36 buổi đã dùng · còn 6` or `12 buổi đã tập · Không giới hạn`.
String sessionsLabel(MemberPackage p) {
  final total = p.totalSessions;
  if (total == null) return '${p.usedSessions} buổi đã tập · Không giới hạn';
  final remaining =
      p.sessionsRemaining ?? (total - p.usedSessions).clamp(0, total);
  return '${p.usedSessions}/$total buổi đã dùng · còn $remaining';
}

/// `01/09/2026 → 01/11/2026` or `01/09/2026 → không thời hạn`.
String validityLabel(MemberPackage p) {
  final start = p.startDate == null ? '' : formatCalendarDate(p.startDate!);
  final end =
      p.endDate == null ? 'không thời hạn' : formatCalendarDate(p.endDate!);
  return '$start → $end';
}

/// `còn 7 ngày`, `Hôm nay là ngày cuối`, or null when there is no expiry.
String? daysRemainingLabel(int? days) {
  if (days == null) return null;
  return days == 0 ? 'Hôm nay là ngày cuối' : 'còn $days ngày';
}

/// Share of sessions used, 0..1. Null for unlimited packages.
double? sessionsFraction(MemberPackage p) {
  final total = p.totalSessions;
  if (total == null || total <= 0) return null;
  return (p.usedSessions / total).clamp(0.0, 1.0);
}

/// Chip on the current package card.
enum CurrentPackageBadge {
  active('Đang hoạt động'),
  endingSoon('Sắp hết hạn');

  const CurrentPackageBadge(this.label);

  final String label;
}

CurrentPackageBadge currentPackageBadge(MemberPackage p) =>
    p.endingSoon ? CurrentPackageBadge.endingSoon : CurrentPackageBadge.active;

enum MembershipBannerKind { frozen, noPackage, expiring, ended }

class MembershipBannerData {
  const MembershipBannerData({
    required this.kind,
    required this.title,
    required this.ctaLabel,
    this.bonusLabel,
  });

  final MembershipBannerKind kind;
  final String title;
  final String ctaLabel;

  /// Early-renewal reward chip (expiring only).
  final String? bonusLabel;
}

/// What the status banner says, or null when there is nothing to warn about.
/// The server decides when a package is ending (`renewNotice`), not the app.
/// [showNoPackage] is false on "Gói tập", which already has its own empty state.
MembershipBannerData? membershipBanner(MyMembership m,
    {bool showNoPackage = true}) {
  if (m.memberStatus == MemberStatus.frozen) {
    return const MembershipBannerData(
      kind: MembershipBannerKind.frozen,
      title: 'Tài khoản đang đóng băng — chế độ chỉ xem',
      ctaLabel: 'Đăng ký / gia hạn gói để mở lại',
    );
  }
  switch (m.renewNotice) {
    case RenewNotice.noPackage:
      return showNoPackage
          ? const MembershipBannerData(
              kind: MembershipBannerKind.noPackage,
              title: 'Chào mừng! Bạn chưa có gói tập',
              ctaLabel: 'Đăng ký gói tập',
            )
          : null;
    case RenewNotice.ended:
      return const MembershipBannerData(
        kind: MembershipBannerKind.ended,
        title: 'Gói tập đã kết thúc.',
        ctaLabel: 'ĐĂNG KÝ GÓI MỚI',
      );
    case RenewNotice.endingSoon:
      final cur = m.current;
      final days = cur?.daysRemaining;
      final sessions = cur?.sessionsRemaining;
      final left = days != null
          ? ' — còn $days ngày'
          : (sessions != null ? ' — còn $sessions buổi' : '');
      return MembershipBannerData(
        kind: MembershipBannerKind.expiring,
        title: 'Gói sắp kết thúc$left',
        ctaLabel: 'GIA HẠN NGAY',
        bonusLabel: '+50 Marks',
      );
    case RenewNotice.ok:
      return null;
  }
}
