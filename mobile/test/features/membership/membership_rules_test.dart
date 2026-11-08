import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/features/membership/domain/membership_models.dart';
import 'package:hvp_forging/features/membership/domain/membership_rules.dart';

MemberPackage _pkg({
  int? total = 36,
  int used = 30,
  int? remaining = 6,
  String? end = '2026-11-01',
  bool endingSoon = false,
}) =>
    MemberPackage(
      id: 'p',
      name: 'BOOK I',
      isTrial: false,
      startDate: '2026-09-01',
      endDate: end,
      totalSessions: total,
      usedSessions: used,
      sessionsRemaining: remaining,
      endingSoon: endingSoon,
    );

void main() {
  _bannerTests();
  _renewalRuleTests();
  test('sessionsLabel for limited and unlimited packages', () {
    expect(sessionsLabel(_pkg()), '30/36 buổi đã dùng · còn 6');
    expect(sessionsLabel(_pkg(remaining: null)), '30/36 buổi đã dùng · còn 6');
    expect(sessionsLabel(_pkg(total: null, used: 12, remaining: null)),
        '12 buổi đã tập · Không giới hạn');
  });

  test('validityLabel handles open-ended packages', () {
    expect(validityLabel(_pkg()), '01/09/2026 → 01/11/2026');
    expect(validityLabel(_pkg(end: null)), '01/09/2026 → không thời hạn');
  });

  test('daysRemainingLabel', () {
    expect(daysRemainingLabel(null), isNull);
    expect(daysRemainingLabel(0), 'Hôm nay là ngày cuối');
    expect(daysRemainingLabel(7), 'còn 7 ngày');
  });

  test('sessionsFraction is null when unlimited and clamped otherwise', () {
    expect(sessionsFraction(_pkg(total: null)), isNull);
    expect(sessionsFraction(_pkg()), closeTo(30 / 36, 1e-9));
    expect(sessionsFraction(_pkg(used: 50)), 1);
  });

  test('currentPackageBadge follows endingSoon', () {
    expect(currentPackageBadge(_pkg()).label, 'Đang hoạt động');
    expect(currentPackageBadge(_pkg(endingSoon: true)).label, 'Sắp hết hạn');
  });
}

void _bannerTests() {
  MyMembership m(RenewNotice n,
          {MemberStatus st = MemberStatus.active, MemberPackage? cur}) =>
      MyMembership(memberStatus: st, renewNotice: n, current: cur);

  group('membershipBanner', () {
    test('frozen wins over every notice', () {
      final b =
          membershipBanner(m(RenewNotice.ended, st: MemberStatus.frozen))!;
      expect(b.kind, MembershipBannerKind.frozen);
      expect(b.title, 'Tài khoản đang đóng băng — chế độ chỉ xem');
    });

    test('no package can be hidden', () {
      expect(membershipBanner(m(RenewNotice.noPackage))!.ctaLabel,
          'Đăng ký gói tập');
      expect(membershipBanner(m(RenewNotice.noPackage), showNoPackage: false),
          isNull);
    });

    test('ended and ok', () {
      expect(
          membershipBanner(m(RenewNotice.ended))!.ctaLabel, 'ĐĂNG KÝ GÓI MỚI');
      expect(membershipBanner(m(RenewNotice.ok)), isNull);
    });

    test('expiring uses the server days, then sessions', () {
      final days = membershipBanner(
          m(RenewNotice.endingSoon, cur: _pkg(endingSoon: true).copyDays(5)))!;
      expect(days.title, 'Gói sắp kết thúc — còn 5 ngày');
      expect(days.bonusLabel, '+50 Marks');
      final sessions = membershipBanner(m(RenewNotice.endingSoon,
          cur: _pkg(endingSoon: true).copyDays(null)))!;
      expect(sessions.title, 'Gói sắp kết thúc — còn 6 buổi');
    });
  });
}

extension on MemberPackage {
  MemberPackage copyDays(int? days) => MemberPackage(
        id: id,
        name: name,
        isTrial: isTrial,
        startDate: startDate,
        endDate: endDate,
        totalSessions: totalSessions,
        usedSessions: usedSessions,
        sessionsRemaining: sessionsRemaining,
        daysRemaining: days,
        endingSoon: endingSoon,
      );
}

void _renewalRuleTests() {
  MyMembership m(RenewNotice n, {bool early = false, bool pending = false}) =>
      MyMembership(
        memberStatus: MemberStatus.active,
        renewNotice: n,
        canRenewEarly: early,
        pendingRenewal: pending
            ? const PendingRenewal(packageName: 'x', createdAt: null)
            : null,
      );

  test('canRequestRenewal follows the API rule', () {
    expect(canRequestRenewal(m(RenewNotice.ok)), isFalse);
    expect(canRequestRenewal(m(RenewNotice.ok, early: true)), isTrue);
    expect(canRequestRenewal(m(RenewNotice.endingSoon)), isTrue);
    expect(canRequestRenewal(m(RenewNotice.noPackage)), isTrue);
    expect(canRequestRenewal(m(RenewNotice.ended, pending: true)), isFalse);
  });

  test('price and summary labels', () {
    expect(priceLabel(8900000), '8.900.000đ');
    expect(priceLabel(null), 'Chưa có giá');
    expect(
        packageSummary(const PackageType(
            id: 'a',
            name: 'a',
            isTrial: false,
            durationDays: 84,
            totalSessions: 36)),
        '84 ngày · 36 buổi');
    expect(
        packageSummary(const PackageType(id: 'a', name: 'a', isTrial: false)),
        'Không giới hạn ngày · Không giới hạn buổi');
  });
}
