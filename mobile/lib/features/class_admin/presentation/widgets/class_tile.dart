import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/branch/branch_providers.dart';
import '../../../../core/design/hvp_context.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/class_models.dart';
import '../../domain/class_rules.dart';
import '../../domain/session_types.dart';
import '../class_providers.dart';

/// One class in the list: name, schedule, branch, coach and enrolment.
class ClassTile extends ConsumerWidget {
  const ClassTile({super.key, required this.item, this.onTap});

  final ClassSummary item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.txt;
    final branch = ref
        .watch(branchesProvider)
        .valueOrNull
        ?.where((b) => b.id == item.branchId)
        .firstOrNull;
    final coach = ref
        .watch(classCoachesProvider)
        .valueOrNull
        ?.where((c) => c.id == item.defaultCoachId)
        .firstOrNull;
    return HvpCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[
            Expanded(child: Text(item.name, style: t.titleM)),
            if (!item.isActive)
              const StatusChip(label: 'Ngừng', tone: ChipTone.danger),
          ]),
          const SizedBox(height: 4),
          Text(
              '${sessionTypeLabel(item.sessionTypeCode)} · ${weekdaysLabel(item.weekdays)} · ${item.startTime}',
              style: t.body),
          const SizedBox(height: 2),
          Text(
              [
                if (branch != null) branch.name,
                if (coach != null) 'Coach ${coach.name}',
                '${enrolmentLabel(item.enrolledCount, item.capacity)} học viên',
              ].join(' · '),
              style: t.bodySmall),
        ],
      ),
    );
  }
}
