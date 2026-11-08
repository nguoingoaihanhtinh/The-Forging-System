import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/hvp_text_field.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/staff_redemption.dart';
import 'staff_redemption_providers.dart';

class GiftHandoverTab extends ConsumerStatefulWidget {
  const GiftHandoverTab({super.key});

  @override
  ConsumerState<GiftHandoverTab> createState() => _GiftHandoverTabState();
}

class _GiftHandoverTabState extends ConsumerState<GiftHandoverTab> {
  String? _status = 'READY_PICKUP';
  String _query = '';

  ({String? status, String query, int page}) get _filter =>
      (status: _status, query: _query, page: 1);

  Future<void> _run(
      Future<void> Function(StaffRedemptionRepository repository)
          action) async {
    final success = await ref.read(staffRedemptionActionProvider.notifier).run(
          () => action(ref.read(staffRedemptionRepositoryProvider)),
        );
    if (!mounted || !success) return;
    ref.invalidate(staffRedemptionListProvider(_filter));
  }

  Future<void> _approve(StaffRedemption item) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Duyệt đơn đổi quà',
      message: 'Chuyển đơn ${item.redemptionCode} sang Sẵn sàng nhận?',
      confirmLabel: 'Duyệt đơn',
    );
    if (confirmed) await _run((repository) => repository.approve(item.id));
  }

  Future<void> _deliver(StaffRedemption item) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Xác nhận giao quà',
      message:
          'Xác nhận đã giao ${item.rewardName} cho ${item.memberFullName}? Marks sẽ được trừ chính thức.',
      confirmLabel: 'Đã giao quà',
    );
    if (confirmed) await _run((repository) => repository.deliver(item.id));
  }

  Future<void> _reject(StaffRedemption item) async {
    final reason = await showHvpSheet<String>(
      context,
      title: 'Từ chối đơn',
      builder: (_) => const _RejectReasonSheet(),
    );
    if (reason != null) {
      await _run((repository) => repository.reject(item.id, reason: reason));
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(staffRedemptionListProvider(_filter));
    final action = ref.watch(staffRedemptionActionProvider);
    return Column(children: <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: HvpTextField(
          label: 'Tìm đơn / học viên',
          hint: 'Mã đơn, mã học viên hoặc họ tên',
          onSubmitted: (value) => setState(() => _query = value.trim()),
        ),
      ),
      SizedBox(
        height: 56,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          scrollDirection: Axis.horizontal,
          children: <Widget>[
            _filterChip(null, 'Tất cả'),
            _filterChip('READY_PICKUP', 'Sẵn sàng nhận'),
            _filterChip('PENDING_PICKUP', 'Chờ duyệt'),
          ],
        ),
      ),
      if (action.error != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: InlineBanner(message: action.error!),
        ),
      Expanded(
        child: AsyncBody<StaffRedemptionPage>(
          value: results,
          onRetry: () => ref.invalidate(staffRedemptionListProvider(_filter)),
          builder: (_, page) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(staffRedemptionListProvider(_filter));
              await ref.read(staffRedemptionListProvider(_filter).future);
            },
            child: page.items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const <Widget>[
                      SizedBox(
                        height: 360,
                        child: EmptyState(
                          icon: HvpIcons.gift,
                          title: 'Không có đơn cần xử lý',
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: page.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) => _RedemptionCard(
                      item: page.items[index],
                      submitting: action.submitting,
                      onApprove: () => _approve(page.items[index]),
                      onDeliver: () => _deliver(page.items[index]),
                      onReject: () => _reject(page.items[index]),
                    ),
                  ),
          ),
        ),
      ),
    ]);
  }

  Widget _filterChip(String? value, String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _status == value,
          onSelected: (_) => setState(() => _status = value),
        ),
      );
}

class _RedemptionCard extends StatelessWidget {
  const _RedemptionCard({
    required this.item,
    required this.submitting,
    required this.onApprove,
    required this.onDeliver,
    required this.onReject,
  });

  final StaffRedemption item;
  final bool submitting;
  final VoidCallback onApprove;
  final VoidCallback onDeliver;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) => HvpCard(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(children: <Widget>[
                Expanded(
                    child: Text(item.rewardName, style: context.txt.titleS)),
                _statusChip(item.status),
              ]),
              const SizedBox(height: 4),
              Text('${item.memberFullName} · ${item.memberCode}',
                  style: context.txt.bodySmall),
              const SizedBox(height: 3),
              Text(
                  '${item.redemptionCode} · ${formatInt(item.marksCost)} Marks',
                  style: context.txt.bodySmall),
              const SizedBox(height: 3),
              Text(
                  '${item.pickupBranchName} · ${formatDateTime(item.requestedAt)}',
                  style: context.txt.caption),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                if (item.status == 'PENDING_PICKUP')
                  HvpButton.primary(
                      label: 'Duyệt',
                      small: true,
                      onPressed: submitting ? null : onApprove),
                if (item.status == 'READY_PICKUP')
                  HvpButton.gold(
                      label: 'Giao quà',
                      small: true,
                      onPressed: submitting ? null : onDeliver),
                if (item.status == 'PENDING_PICKUP' ||
                    item.status == 'READY_PICKUP')
                  HvpButton.danger(
                      label: 'Từ chối',
                      small: true,
                      onPressed: submitting ? null : onReject),
              ]),
            ]),
      );

  StatusChip _statusChip(String status) => switch (status) {
        'PENDING_PICKUP' =>
          const StatusChip(label: 'Chờ duyệt', tone: ChipTone.warning),
        'READY_PICKUP' =>
          const StatusChip(label: 'Sẵn sàng nhận', tone: ChipTone.success),
        'DELIVERED' =>
          const StatusChip(label: 'Đã giao', tone: ChipTone.success),
        'REJECTED' => const StatusChip(label: 'Từ chối', tone: ChipTone.danger),
        _ => StatusChip(label: status, tone: ChipTone.neutral),
      };
}

class _RejectReasonSheet extends StatefulWidget {
  const _RejectReasonSheet();

  @override
  State<_RejectReasonSheet> createState() => _RejectReasonSheetState();
}

class _RejectReasonSheetState extends State<_RejectReasonSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.length < 3) {
      setState(() => _error = 'Nhập lý do ít nhất 3 ký tự.');
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          HvpTextField(
            label: 'Lý do từ chối',
            controller: _controller,
            maxLines: 3,
            maxLength: 500,
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(_error!,
                style: context.txt.bodySmall.copyWith(color: context.hvp.red)),
          ],
          const SizedBox(height: 20),
          HvpButton.danger(
              label: 'Xác nhận từ chối', expand: true, onPressed: _submit),
        ]),
      );
}
