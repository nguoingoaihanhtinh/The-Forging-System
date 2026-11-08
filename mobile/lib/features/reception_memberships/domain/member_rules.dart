import '../../../core/utils/formatters.dart';
import '../../membership/domain/membership_models.dart';

/// Reception cancels only a package waiting to start; cancelling a running one is an admin job.
bool canCancelPackage({required bool isAdmin, required bool scheduled}) =>
    scheduled || isAdmin;

/// `9.800.000đ · 84 ngày · 36 buổi`; missing values are "chưa có giá" / "không giới hạn".
String packageTypeSummary(PackageType p) => <String>[
      p.priceVnd == null ? 'chưa có giá' : '${formatInt(p.priceVnd!)}đ',
      p.durationDays == null ? 'không giới hạn ngày' : '${p.durationDays} ngày',
      p.totalSessions == null
          ? 'không giới hạn buổi'
          : '${p.totalSessions} buổi',
    ].join(' · ');

/// The status the desk may move an account to. Reception never sets INACTIVE: it can only
/// freeze an active account or reopen a frozen one (an inactive one comes back with a package).
String? nextStatusFor(String status) => switch (status) {
      'ACTIVE' => 'FROZEN',
      'FROZEN' => 'ACTIVE',
      _ => null,
    };
