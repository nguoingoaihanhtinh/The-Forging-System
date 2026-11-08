import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/hvp_avatar.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../reception_checkin/domain/member_hit.dart';
import '../../../reception_checkin/presentation/widgets/member_card.dart';

/// A search result: who, account status, and the running package with its expiry.
class MemberRow extends StatelessWidget {
  const MemberRow({super.key, required this.member, this.onTap});

  final MemberHit member;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final contact = <String>[
      if (member.phone != null) member.phone!,
      member.memberCode
    ].where((p) => p.isNotEmpty).join(' · ');
    final end = member.packageEndDate;
    return HvpCard(
      onTap: onTap,
      semanticLabel: 'Học viên ${member.fullName}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          HvpAvatar(url: member.avatarUrl, name: member.fullName, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(member.fullName, style: t.titleS),
                if (contact.isNotEmpty) Text(contact, style: t.bodySmall),
                if (member.packageName != null)
                  Text(
                      '${member.packageName} · ${end == null ? 'không thời hạn' : 'hết hạn ${formatCalendarDate(end)}'}',
                      style: t.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    memberStatusChip(member.status),
                    if (member.packageName == null)
                      const StatusChip(
                          label: 'Chưa có gói', tone: ChipTone.warning),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
