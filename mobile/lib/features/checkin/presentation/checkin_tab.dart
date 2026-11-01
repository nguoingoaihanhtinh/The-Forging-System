import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../core/design/color_utils.dart';
import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/design/hvp_layout.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/checkin_session.dart';
import 'checkin_providers.dart';

/// How often the list is reloaded while the tab is open: windows open and close on the clock.
const Duration checkinRefreshEvery = Duration(seconds: 60);

/// Student "Check-in" tab: today's sessions, the one to check into, and the way to the scanner.
class CheckinTab extends ConsumerStatefulWidget {
  const CheckinTab({super.key});

  @override
  ConsumerState<CheckinTab> createState() => _CheckinTabState();
}

class _CheckinTabState extends ConsumerState<CheckinTab> {
  Timer? _timer;

  /// What the learner tapped; falls back to the default while it is still a valid choice.
  String? _picked;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(checkinRefreshEvery, (_) => ref.invalidate(todayCheckinProvider));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  CheckinSession? _selected(List<CheckinSession> sessions) {
    final picked = sessions.where((s) => s.sessionId == _picked && s.canCheckin);
    return picked.isNotEmpty ? picked.first : defaultCheckinSession(sessions, DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayCheckinProvider);
    final t = context.txt;
    return AsyncBody<TodayCheckin>(
      value: today,
      onRetry: () => ref.invalidate(todayCheckinProvider),
      builder: (context, data) {
        final selected = _selected(data.sessions);
        final anyOpen = data.sessions.any((s) => s.canCheckin);
        return Column(
          children: <Widget>[
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(todayCheckinProvider);
                  await ref.read(todayCheckinProvider.future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  children: <Widget>[
                    Text('Check-in tại quầy', style: t.titleL),
                    const SizedBox(height: 6),
                    Text(
                      'Quét mã trên màn hình phòng tập. Điểm chỉ được cộng sau khi Coach xác nhận buổi.',
                      style: t.bodySmall,
                    ),
                    if (!data.eligibility.canCheckin && data.eligibility.message != null) ...<Widget>[
                      const SizedBox(height: 12),
                      InlineBanner(message: data.eligibility.message!),
                    ],
                    const SizedBox(height: 16),
                    if (data.sessions.isEmpty)
                      const EmptyState(
                        icon: HvpIcons.calendar,
                        title: 'Hôm nay không có buổi tập',
                        message: 'Bạn không có buổi nào cần check-in hôm nay.',
                      )
                    else ...<Widget>[
                      Text('BUỔI HÔM NAY', style: t.label),
                      const SizedBox(height: 8),
                      for (final session in data.sessions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SessionCard(
                            session: session,
                            selected: selected?.sessionId == session.sessionId,
                            onTap: session.canCheckin ? () => setState(() => _picked = session.sessionId) : null,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              // Clear of the floating bottom bar.
              padding: const EdgeInsets.fromLTRB(16, 4, 16, HvpLayout.navClearance),
              child: SizedBox(
                width: double.infinity,
                child: HvpButton.gold(
                  label: 'Quét mã check-in',
                  icon: HvpIcons.scan,
                  onPressed: anyOpen ? () => context.push(StudentPaths.checkinScanFor(selected?.sessionId)) : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.selected, required this.onTap});

  final CheckinSession session;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final enabled = session.canCheckin;
    final range = '${formatTime(session.startsAt)} - ${formatTime(session.endsAt)}';
    return Opacity(
      opacity: enabled || session.state == CheckinState.checkedIn ? 1 : 0.7,
      child: HvpCard(
        accent: selected ? c.gold : null,
        onTap: onTap,
        semanticLabel: '${session.title}, $range, ${_statusLabel(session)}',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 12),
              child: Icon(
                session.state == CheckinState.checkedIn
                    ? HvpIcons.checkCircle
                    : (selected ? Icons.radio_button_checked : Icons.radio_button_off),
                size: 22,
                color: session.state == CheckinState.checkedIn ? c.emerald : (selected ? c.gold : c.textMuted.fade(0.9)),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(session.title, style: t.titleS),
                  const SizedBox(height: 2),
                  Text('$range · ${session.branchName}', style: t.bodySmall),
                  if (session.coachName.isNotEmpty) Text('Coach ${session.coachName}', style: t.caption),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      StatusChip(label: _statusLabel(session), tone: _tone(session.state)),
                      if (session.isExam) const StatusChip(label: 'Kiểm tra', tone: ChipTone.info),
                    ],
                  ),
                  if (!enabled && session.message != null && session.state != CheckinState.checkedIn) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(session.message!, style: t.caption),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(CheckinSession s) {
  switch (s.state) {
    case CheckinState.open:
      return 'Đang mở check-in';
    case CheckinState.notYetOpen:
      return 'Mở lúc ${formatTime(s.opensAt)}';
    case CheckinState.closed:
      return 'Đã đóng check-in';
    case CheckinState.checkedIn:
      return s.checkedInAt == null ? 'Đã check-in' : 'Đã check-in ${formatTime(s.checkedInAt!)}';
    case CheckinState.overlapsCheckedIn:
      return 'Trùng giờ';
    case CheckinState.blocked:
      return 'Chưa thể check-in';
  }
}

ChipTone _tone(CheckinState state) {
  switch (state) {
    case CheckinState.open:
      return ChipTone.success;
    case CheckinState.checkedIn:
      return ChipTone.gold;
    case CheckinState.notYetOpen:
      return ChipTone.info;
    case CheckinState.closed:
    case CheckinState.overlapsCheckedIn:
      return ChipTone.warning;
    case CheckinState.blocked:
      return ChipTone.danger;
  }
}
