import '../../../core/utils/formatters.dart';
import 'package_type.dart';

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
