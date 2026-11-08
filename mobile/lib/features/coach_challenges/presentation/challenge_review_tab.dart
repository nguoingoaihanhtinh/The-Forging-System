import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/design/hvp_layout.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/inline_banner.dart';
import '../domain/challenge_review.dart';
import 'challenge_review_providers.dart';

/// Coach "Challenge" tab: review evidence the learner submitted and release the reward.
class ChallengeReviewTab extends ConsumerWidget {
  const ChallengeReviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(challengeReviewQueueProvider);
    final action = ref.watch(challengeReviewActionProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Duyệt Challenge', style: context.txt.titleL),
              const SizedBox(height: 4),
              Text(
                'Kiểm tra bằng chứng học viên nộp và phát thưởng khi đạt mục tiêu.',
                style: context.txt.bodySmall,
              ),
            ],
          ),
        ),
        if (action.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: InlineBanner(message: action.error!),
          ),
        Expanded(
          child: AsyncBody<List<ChallengeReview>>(
            value: queue,
            onRetry: () => ref.invalidate(challengeReviewQueueProvider),
            builder: (context, items) {
              if (items.isEmpty) {
                return const EmptyState(
                  icon: HvpIcons.flag,
                  title: 'Không có bài nộp chờ duyệt',
                  message: 'Bài nộp của học viên sẽ xuất hiện tại đây khi họ đạt mục tiêu.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(challengeReviewQueueProvider);
                  await ref.read(challengeReviewQueueProvider.future);
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, HvpLayout.navClearance),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) =>
                      _ReviewCard(item: items[index], submitting: action.submitting),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({required this.item, required this.submitting});

  final ChallengeReview item;
  final bool submitting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = item.evidenceUrl;
    return HvpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(item.challengeTitle, style: context.txt.titleS),
          const SizedBox(height: 4),
          Text('${item.memberFullName} · ${item.memberCode}', style: context.txt.bodySmall),
          const SizedBox(height: 8),
          Text('Tiến độ: ${item.progressValue} / ${item.target}', style: context.txt.bodySmall),
          if (url != null) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                url,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  alignment: Alignment.center,
                  color: context.hvp.surfaceHighest,
                  child: Text('Không tải được ảnh minh chứng', style: context.txt.bodySmall),
                ),
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 12),
            Text('Học viên chưa nộp ảnh minh chứng.', style: context.txt.bodySmall),
          ],
          const SizedBox(height: 14),
          HvpButton.gold(
            label: 'Duyệt và phát thưởng',
            small: true,
            loading: submitting,
            onPressed: submitting || url == null ? null : () => _approve(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Duyệt bài nộp',
      message:
          'Xác nhận bài nộp của ${item.memberFullName}? Phần thưởng Challenge sẽ được phát.',
      confirmLabel: 'Duyệt bài nộp',
    );
    if (!confirmed) return;
    final ok = await ref.read(challengeReviewActionProvider.notifier).run(
          () => ref.read(challengeReviewRepositoryProvider).approve(item.participationId),
        );
    if (ok) ref.invalidate(challengeReviewQueueProvider);
  }
}
