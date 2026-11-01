import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../core/design/color_utils.dart';
import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/design/scan_frame.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/hvp_app_bar.dart';
import '../../../core/widgets/hvp_button.dart';
import '../../../core/widgets/hvp_card.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/checkin_outcome.dart';
import '../domain/checkin_session.dart';
import 'checkin_providers.dart';
import 'checkin_scan_controller.dart';

/// The member points the camera at the QR on the front-desk screen; the server checks it in.
/// [sessionId] is the session picked on the Check-in tab (optional).
class CheckinScanScreen extends ConsumerWidget {
  const CheckinScanScreen({super.key, this.sessionId});

  final String? sessionId;

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(StudentPaths.checkin);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkinScanProvider);
    final controller = ref.read(checkinScanProvider.notifier);
    final scanner = ref.watch(qrScannerBuilderProvider);
    final picked = ref.watch(todayCheckinProvider).valueOrNull?.sessions.where((s) => s.sessionId == sessionId);
    final pickedSession = picked != null && picked.isNotEmpty ? picked.first : null;

    return Scaffold(
      appBar: const HvpAppBar(title: 'Quét mã check-in'),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          scanner(context, (code) => controller.onCode(code, sessionId: sessionId)),
          if (state is ScanIdle) ...<Widget>[
            const Center(child: ScanFrame(size: 260)),
            Positioned(
              top: 16,
              left: 24,
              right: 24,
              child: _Hint(session: pickedSession),
            ),
          ],
          if (state is ScanSubmitting) const _Busy(),
          if (state is ScanChoosing) _ChooseSessionPanel(state: state, onPick: controller.choose, onCancel: controller.scanAgain),
          if (state is ScanFailed) _FailurePanel(state: state, controller: controller, onLeave: () => _leave(context)),
          if (state is ScanDone) _SuccessPanel(result: state.result, onDone: () => _leave(context)),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({this.session});

  final CheckinSession? session;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: Colors.black.fade(0.55), borderRadius: BorderRadius.circular(8)),
          child: Text(
            'Đưa mã QR trên màn hình phòng tập vào khung',
            style: t.body.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
        if (session != null) ...<Widget>[
          const SizedBox(height: 8),
          StatusChip(label: '${session!.title} · ${formatTime(session!.startsAt)}', tone: ChipTone.gold),
        ],
      ],
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.fade(0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Đang check-in…', style: context.txt.body.copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

/// Sheet over the camera, anchored to the bottom.
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(padding: const EdgeInsets.all(16), child: HvpCard(child: child)),
      ),
    );
  }
}

class _ChooseSessionPanel extends StatelessWidget {
  const _ChooseSessionPanel({required this.state, required this.onPick, required this.onCancel});

  final ScanChoosing state;
  final ValueChanged<String> onPick;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return _BottomPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Bạn check-in buổi nào?', style: t.titleM),
          const SizedBox(height: 4),
          Text('Có nhiều buổi đang mở tại chi nhánh này.', style: t.bodySmall),
          const SizedBox(height: 12),
          for (final s in state.sessions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HvpCard(
                semanticLabel: 'Check-in ${s.title}',
                onTap: () => onPick(s.sessionId),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(s.title, style: t.titleS),
                          Text('${formatTime(s.startsAt)} - ${formatTime(s.endsAt)}', style: t.caption),
                        ],
                      ),
                    ),
                    const Icon(HvpIcons.caretRight),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          SizedBox(width: double.infinity, child: HvpButton.secondary(label: 'Hủy', onPressed: onCancel, small: true)),
        ],
      ),
    );
  }
}

class _FailurePanel extends StatelessWidget {
  const _FailurePanel({required this.state, required this.controller, required this.onLeave});

  final ScanFailed state;
  final CheckinScanController controller;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final action = state.action;
    final bool retryable = state.error.isNetwork;
    final String label;
    final VoidCallback onPressed;
    if (retryable) {
      label = 'Thử lại';
      onPressed = controller.retry;
    } else if (action == CheckinAction.rescan) {
      label = 'Quét lại';
      onPressed = controller.scanAgain;
    } else {
      label = 'Quay lại';
      onPressed = onLeave;
    }
    return _BottomPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InlineBanner(title: 'Chưa check-in được', message: state.error.message),
          const SizedBox(height: 12),
          HvpButton.gold(label: label, onPressed: onPressed),
        ],
      ),
    );
  }
}

class _SuccessPanel extends StatelessWidget {
  const _SuccessPanel({required this.result, required this.onDone});

  final CheckedIn result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return ColoredBox(
      color: Colors.black.fade(0.7),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: HvpCard(
            highlighted: true,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Icon(HvpIcons.checkCircle, size: 56, color: c.emerald),
                const SizedBox(height: 12),
                Text(
                  result.alreadyCheckedIn ? 'ĐÃ CHECK-IN RỒI' : 'CHECK-IN THÀNH CÔNG',
                  style: t.titleL,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(result.sessionTitle, style: t.titleS, textAlign: TextAlign.center),
                Text(
                  '${formatTime(result.startsAt)} - ${formatTime(result.endsAt)} · ${result.branchName}',
                  style: t.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text('Check-in lúc ${formatTime(result.checkedInAt)}', style: t.caption, textAlign: TextAlign.center),
                if (result.sessionsRemaining != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text('Gói tập còn ${result.sessionsRemaining} buổi', style: t.body, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 12),
                Text(result.message, style: t.bodySmall, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                HvpButton.gold(label: 'Xong', onPressed: onDone),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
