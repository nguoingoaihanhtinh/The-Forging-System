import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

import '../../../../core/design/color_utils.dart';
import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/confetti_burst.dart';
import '../../../../core/widgets/entrance.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/checkin_failure.dart';
import '../../domain/checkin_outcome.dart';

/// Full-screen frame of a result: a medallion, a heading, the details, and the buttons at the bottom.
class _ResultFrame extends StatelessWidget {
  const _ResultFrame({required this.icon, required this.color, required this.title, required this.children, required this.buttons});

  final IconData icon;
  final Color color;
  final String title;
  final List<Widget> children;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return ColoredBox(
      color: c.bg,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: color.fade(0.15), border: Border.all(color: color.fade(0.6), width: 2)),
                          child: Icon(icon, size: 48, color: color),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Semantics(
                        liveRegion: true,
                        header: true,
                        child: Text(title, style: t.titleL, textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 16),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final (i, b) in buttons.indexed) Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 10), child: b),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The member is checked in (or already was): which session, when, how many sessions are left, what happens next.
class CheckinSuccessView extends StatefulWidget {
  const CheckinSuccessView({super.key, required this.result, required this.onDone});

  final CheckedIn result;
  final VoidCallback onDone;

  @override
  State<CheckinSuccessView> createState() => _CheckinSuccessViewState();
}

class _CheckinSuccessViewState extends State<CheckinSuccessView> {
  final ConfettiController _confetti = ConfettiController(duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    if (!widget.result.alreadyCheckedIn) {
      Haptics.medium();
      if (hvpEntranceEnabled) _confetti.play(); // decoration: off wherever decorative motion is off (tests)
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final r = widget.result;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _ResultFrame(
          icon: HvpIcons.checkCircle,
          color: r.alreadyCheckedIn ? c.gold : c.emerald,
          title: r.alreadyCheckedIn ? 'ĐÃ CHECK-IN RỒI' : 'CHECK-IN THÀNH CÔNG',
          buttons: <Widget>[HvpButton.gold(label: 'Xong', onPressed: widget.onDone)],
          children: <Widget>[
            HvpCard(
              highlighted: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(r.sessionTitle, style: t.titleM),
                  const SizedBox(height: 4),
                  Text('${formatTime(r.startsAt)} - ${formatTime(r.endsAt)} · ${r.branchName}', style: t.bodySmall),
                  const SizedBox(height: 4),
                  Text('Check-in lúc ${formatTime(r.checkedInAt)}', style: t.caption),
                  if (r.sessionsRemaining != null) ...<Widget>[
                    const SizedBox(height: 12),
                    StatusChip(label: 'Gói tập còn ${r.sessionsRemaining} buổi', tone: ChipTone.gold),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(r.message, style: t.bodySmall, textAlign: TextAlign.center),
          ],
        ),
        IgnorePointer(child: ConfettiBurst(controller: _confetti)),
      ],
    );
  }
}

/// A refused check-in: why, the facts that help, and the one next step the error calls for.
class CheckinFailureView extends StatefulWidget {
  const CheckinFailureView({
    super.key,
    required this.failure,
    required this.typed,
    required this.onScanAgain,
    required this.onRetry,
    required this.onRenew,
    required this.onBack,
  });

  final CheckinFailure failure;

  /// The refused code was typed, so "again" means the typing form rather than the camera.
  final bool typed;
  final VoidCallback onScanAgain;
  final VoidCallback onRetry;
  final VoidCallback onRenew;
  final VoidCallback onBack;

  @override
  State<CheckinFailureView> createState() => _CheckinFailureViewState();
}

class _CheckinFailureViewState extends State<CheckinFailureView> {
  @override
  void initState() {
    super.initState();
    Haptics.light();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final f = widget.failure;

    final hint = switch (f.action) {
      CheckinAction.wait when f.opensAt != null => 'Check-in mở lúc ${formatTime(f.opensAt!)}.',
      CheckinAction.askFrontDesk => 'Bạn có thể nhờ lễ tân tại quầy check-in hộ.',
      _ => null,
    };

    final (String primaryLabel, VoidCallback primary) = f.isNetwork
        ? ('Thử lại', widget.onRetry)
        : switch (f.action) {
            CheckinAction.rescan => (widget.typed ? 'Nhập lại' : 'Quét lại', widget.onScanAgain),
            CheckinAction.renewPackage => ('Gia hạn gói tập', widget.onRenew),
            _ => ('Quay lại', widget.onBack),
          };

    return _ResultFrame(
      icon: f.isNetwork ? HvpIcons.retry : HvpIcons.warning,
      color: f.action == CheckinAction.wait ? c.info : c.amber,
      title: f.title,
      buttons: <Widget>[
        HvpButton.gold(label: primaryLabel, onPressed: primary),
        if (primaryLabel != 'Quay lại') HvpButton.secondary(label: 'Quay lại', onPressed: widget.onBack),
      ],
      children: <Widget>[
        Text(f.message, style: t.body, textAlign: TextAlign.center),
        if (f.action == CheckinAction.goToBranch && f.branchNames.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[for (final name in f.branchNames) StatusChip(label: name, tone: ChipTone.gold)],
          ),
        ],
        if (hint != null) ...<Widget>[
          const SizedBox(height: 16),
          HvpCard(child: Text(hint, style: t.bodySmall, textAlign: TextAlign.center)),
        ],
      ],
    );
  }
}
