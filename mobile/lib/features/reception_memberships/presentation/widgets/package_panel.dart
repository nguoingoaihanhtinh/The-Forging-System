import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../membership/domain/membership_models.dart';
import '../../../membership/domain/membership_rules.dart';

/// One package of the learner (running or waiting) with an optional cancel button.
class PackagePanel extends StatelessWidget {
  const PackagePanel(
      {super.key,
      required this.title,
      required this.package,
      this.cancelLabel,
      this.onCancel});

  final String title;
  final MemberPackage package;
  final String? cancelLabel;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final days = daysRemainingLabel(package.daysRemaining);
    return HvpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(title.toUpperCase(), style: t.label)),
              if (package.endingSoon)
                const StatusChip(label: 'Sắp hết hạn', tone: ChipTone.warning),
            ],
          ),
          const SizedBox(height: 4),
          Text(package.name, style: t.titleS),
          Text(
              <String>[validityLabel(package), if (days != null) days]
                  .join(' · '),
              style: t.bodySmall),
          Text(sessionsLabel(package), style: t.bodySmall),
          if (onCancel != null && cancelLabel != null) ...<Widget>[
            const SizedBox(height: 12),
            HvpButton.danger(
                label: cancelLabel!,
                small: true,
                expand: true,
                onPressed: onCancel),
          ],
        ],
      ),
    );
  }
}
