import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/hvp_app_bar.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/admin_armory_repository.dart';
import '../admin_armory_providers.dart';
import 'admin_armory_reward_form_screen.dart';
import 'admin_armory_tiers_screen.dart';

class AdminArmoryManagementScreen extends ConsumerStatefulWidget {
  const AdminArmoryManagementScreen({super.key});

  @override
  ConsumerState<AdminArmoryManagementScreen> createState() =>
      _AdminArmoryManagementScreenState();
}

class _AdminArmoryManagementScreenState
    extends ConsumerState<AdminArmoryManagementScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const HvpAppBar(title: 'Quản lý Armory'),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(
            _tab == 0
                ? AdminPaths.armoryTierCreate
                : AdminPaths.armoryRewardCreate,
          ),
          icon: const Icon(HvpIcons.plus),
          label: Text(_tab == 0 ? 'Tạo tier' : 'Tạo quà'),
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SegmentedButton<int>(
                segments: const <ButtonSegment<int>>[
                  ButtonSegment<int>(value: 0, label: Text('Tier')),
                  ButtonSegment<int>(value: 1, label: Text('Quà tặng')),
                ],
                selected: <int>{_tab},
                onSelectionChanged: (value) =>
                    setState(() => _tab = value.first),
              ),
            ),
            Expanded(
                child: _tab == 0 ? const _TierList() : const _RewardList()),
          ],
        ),
      );
}

class _TierList extends ConsumerWidget {
  const _TierList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiers = ref.watch(adminArmoryTiersProvider);
    return AsyncBody<List<AdminArmoryTier>>(
      value: tiers,
      onRetry: () => ref.invalidate(adminArmoryTiersProvider),
      builder: (_, items) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final tier = items[index];
          return HvpCard(
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => AdminArmoryTiersScreen(tier: tier),
              ));
              ref.invalidate(adminArmoryTiersProvider);
            },
            child: Row(children: <Widget>[
              Icon(HvpIcons.armory, color: context.hvp.gold),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(tier.name, style: context.txt.titleS),
                  Text(
                      '${tier.code} · ${tier.minMarks}${tier.maxMarks == null ? '+' : '–${tier.maxMarks}'} Marks',
                      style: context.txt.bodySmall),
                ],
              )),
              Icon(HvpIcons.caretRight, color: context.hvp.textMuted),
            ]),
          );
        },
      ),
    );
  }
}

class _RewardList extends ConsumerWidget {
  const _RewardList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(adminArmoryRewardsProvider);
    return AsyncBody<AdminArmoryRewardPage>(
      value: rewards,
      onRetry: () => ref.invalidate(adminArmoryRewardsProvider),
      builder: (_, page) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: page.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final reward = page.items[index];
          return HvpCard(
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => AdminArmoryRewardFormScreen(reward: reward),
              ));
              ref.invalidate(adminArmoryRewardsProvider);
            },
            child: Row(children: <Widget>[
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(reward.name, style: context.txt.titleS),
                  Text(
                      '${reward.sku} · ${reward.marksCost} Marks · tồn ${reward.stock}',
                      style: context.txt.bodySmall),
                ],
              )),
              StatusChip(
                  label: reward.isActive ? 'Đang bán' : 'Ngừng bán',
                  tone: reward.isActive ? ChipTone.success : ChipTone.neutral),
            ]),
          );
        },
      ),
    );
  }
}
