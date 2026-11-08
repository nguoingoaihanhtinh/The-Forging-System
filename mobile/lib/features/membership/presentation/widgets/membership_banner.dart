import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/membership_rules.dart';
import '../providers/membership_providers.dart';

/// Status banner driven by [myMembershipProvider]. Renders nothing while
/// loading, on error, or when there is nothing to warn about, so it never
/// blocks the screen it sits on. A null [onAction] disables the button.
class MembershipBanner extends ConsumerWidget {
  const MembershipBanner({
    super.key,
    required this.onAction,
    this.showNoPackage = true,
  });

  final VoidCallback? onAction;
  final bool showNoPackage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(myMembershipProvider).asData?.value;
    final banner =
        m == null ? null : membershipBanner(m, showNoPackage: showNoPackage);
    if (banner == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InlineBanner(
          message: banner.title,
          tone: switch (banner.kind) {
            MembershipBannerKind.expiring => ChipTone.warning,
            MembershipBannerKind.ended => ChipTone.danger,
            _ => ChipTone.info,
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: HvpButton.gold(
                label: banner.ctaLabel,
                small: true,
                expand: true,
                onPressed: onAction,
              ),
            ),
            if (banner.bonusLabel != null) ...<Widget>[
              const SizedBox(width: 8),
              StatusChip(label: banner.bonusLabel!, tone: ChipTone.gold),
            ],
          ],
        ),
      ],
    );
  }
}
