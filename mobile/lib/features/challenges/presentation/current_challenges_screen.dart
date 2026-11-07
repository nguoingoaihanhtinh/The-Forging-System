import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/current_challenge.dart';
import 'current_challenge_providers.dart';

class CurrentChallengesScreen extends ConsumerWidget {
  const CurrentChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = ref.watch(currentChallengesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Thử thách')),
      body: AsyncBody<List<CurrentChallenge>>(
        value: challenges,
        onRetry: () => ref.invalidate(currentChallengesProvider),
        builder: (_, items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(currentChallengesProvider);
            await ref.read(currentChallengesProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: <Widget>[
              Text('THỬ THÁCH HIỆN TẠI', style: context.txt.titleL),
              const SizedBox(height: 4),
              Text('Theo dõi mục tiêu, thời hạn và phần thưởng của bạn.',
                  style: context.txt.bodySmall),
              const SizedBox(height: 16),
              if (items.isEmpty)
                const EmptyState(
                  icon: HvpIcons.flag,
                  title: 'Chưa tham gia thử thách',
                  message:
                      'Khi tham gia thử thách đang mở, tiến độ sẽ xuất hiện tại đây.',
                ),
              for (final challenge in items) ...<Widget>[
                CurrentChallengeCard(challenge: challenge),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CurrentChallengeCard extends StatelessWidget {
  const CurrentChallengeCard({super.key, required this.challenge});
  final CurrentChallenge challenge;

  @override
  Widget build(BuildContext context) => HvpCard(
        highlighted: true,
        accent: _tone(challenge.participationStatus) == ChipTone.success
            ? context.hvp.emerald
            : null,
        semanticLabel: 'Tiến độ thử thách ${challenge.title}',
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                StatusChip(
                    label: _type(challenge.challengeType), tone: ChipTone.gold),
                StatusChip(
                    label: _status(challenge.participationStatus),
                    tone: _tone(challenge.participationStatus)),
              ]),
              const SizedBox(height: 12),
              Text(challenge.title, style: context.txt.titleS),
              const SizedBox(height: 14),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('TIẾN ĐỘ', style: context.txt.caption),
                    Text(
                        '${formatInt(challenge.progressValue)} / ${formatInt(challenge.target)}',
                        style: context.txt.bodySmall),
                  ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: challenge.progress,
                  minHeight: 10,
                  backgroundColor: context.hvp.surfaceHighest,
                  color: context.hvp.gold,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 14, runSpacing: 8, children: <Widget>[
                _detail(context, HvpIcons.calendar,
                    'Hạn: ${formatDateTime(challenge.endsAt)}'),
                _detail(context, HvpIcons.star,
                    '+${formatInt(challenge.rewardDp)} DP'),
                _detail(context, HvpIcons.coins,
                    '+${formatInt(challenge.rewardMarks)} Marks'),
              ]),
            ]),
      );

  Widget _detail(BuildContext context, IconData icon, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Icon(icon, size: 16, color: context.hvp.gold),
        const SizedBox(width: 4),
        Text(label, style: context.txt.bodySmall),
      ]);

  String _type(String value) => switch (value) {
        'DAILY' => 'Hằng ngày',
        'WEEKLY' => 'Hằng tuần',
        'MONTHLY' => 'Hằng tháng',
        'EVENT' => 'Sự kiện',
        _ => value,
      };

  String _status(String value) => switch (value) {
        'JOINED' => 'Đang thực hiện',
        'AWAITING_COACH' => 'Chờ xác nhận',
        'REWARDED' => 'Đã nhận thưởng',
        'EXPIRED' => 'Đã hết hạn',
        _ => value,
      };

  ChipTone _tone(String value) => switch (value) {
        'REWARDED' => ChipTone.success,
        'AWAITING_COACH' => ChipTone.warning,
        'EXPIRED' => ChipTone.danger,
        _ => ChipTone.info,
      };
}
