import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/error/api_exception.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/hvp_toast.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/membership_models.dart';
import '../../domain/membership_rules.dart';
import '../providers/membership_providers.dart';

/// MEM-10: opens the "Chọn gói tập" picker.
Future<void> showRenewalSheet(BuildContext context) => showHvpSheet<void>(
      context,
      title: 'Chọn gói tập',
      builder: (_) => const RenewalSheet(),
    );

class RenewalSheet extends ConsumerStatefulWidget {
  const RenewalSheet({super.key});

  @override
  ConsumerState<RenewalSheet> createState() => _RenewalSheetState();
}

class _RenewalSheetState extends ConsumerState<RenewalSheet> {
  final _note = TextEditingController();
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
        () => ref.read(renewalSubmitProvider.notifier).reset());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(PackageType package) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Gửi yêu cầu gia hạn?',
      message: '${package.name} · ${priceLabel(package.priceVnd)}',
      confirmLabel: 'Gửi yêu cầu',
    );
    if (!confirmed || !mounted) return;
    final ok = await ref.read(renewalSubmitProvider.notifier).run(() async {
      try {
        await ref
            .read(membershipRepositoryProvider)
            .requestRenewal(packageTypeId: package.id, note: _note.text);
      } on ApiException catch (e) {
        // Server state moved on: a pending request exists / package left sale.
        if (e.code == 'RENEWAL_PENDING_EXISTS') {
          ref.invalidate(myMembershipProvider);
        } else if (e.code == 'PACKAGE_NOT_AVAILABLE') {
          _selectedId = null;
          ref.invalidate(packageTypesProvider);
        }
        rethrow;
      }
    });
    if (!mounted || !ok) return;
    ref.invalidate(myMembershipProvider);
    HvpToast.success(context, 'Đã gửi yêu cầu gia hạn tới lễ tân.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final submit = ref.watch(renewalSubmitProvider);
    return AsyncBody<List<PackageType>>(
      value: ref.watch(packageTypesProvider),
      onRetry: () => ref.invalidate(packageTypesProvider),
      loading: const SizedBox(height: 240, child: ShimmerList(itemCount: 3)),
      builder: (context, packages) {
        if (packages.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: EmptyState(
              icon: HvpIcons.ticket,
              title: 'Hiện chưa có gói nào đang bán',
            ),
          );
        }
        PackageType? selected;
        for (final p in packages) {
          if (p.id == _selectedId) selected = p;
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final p in packages) ...<Widget>[
                _PackageTile(
                  package: p,
                  selected: p.id == _selectedId,
                  onTap: submit.submitting
                      ? null
                      : () => setState(() => _selectedId = p.id),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 4),
              HvpTextField(
                label: 'Ghi chú (không bắt buộc)',
                controller: _note,
                maxLength: 500,
                maxLines: 2,
              ),
              if (submit.error != null) ...<Widget>[
                const SizedBox(height: 12),
                InlineBanner(message: submit.error!),
              ],
              const SizedBox(height: 16),
              HvpButton.primary(
                label: 'Gửi yêu cầu gia hạn',
                expand: true,
                loading: submit.submitting,
                onPressed: selected == null || submit.submitting
                    ? null
                    : () => _submit(selected!),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.package,
    required this.selected,
    required this.onTap,
  });

  final PackageType package;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return HvpCard(
      accent: selected ? c.gold : null,
      highlighted: selected,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(package.name, style: t.titleS),
                if (package.isTrial) ...<Widget>[
                  const SizedBox(height: 4),
                  const StatusChip(
                      label: 'Gói trải nghiệm', tone: ChipTone.gold),
                ],
                const SizedBox(height: 4),
                Text(packageSummary(package), style: t.bodySmall),
                const SizedBox(height: 4),
                Text(priceLabel(package.priceVnd),
                    style: t.titleS.copyWith(color: c.gold)),
              ],
            ),
          ),
          if (selected) Icon(HvpIcons.checkCircle, color: c.gold),
        ],
      ),
    );
  }
}
