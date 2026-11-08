import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/branch/branch_providers.dart';
import '../../../core/design/hvp_context.dart';
import '../../../core/design/hvp_icons.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/inline_banner.dart';
import '../domain/branch_code.dart';
import 'branch_qr_providers.dart';

/// The device clock, replaceable so tests can move time.
final branchQrClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// How often the countdown moves and the screen checks whether it needs the next code.
const Duration branchQrTick = Duration(seconds: 1);

/// A failed fetch is tried again after this long.
const Duration branchQrRetryEvery = Duration(seconds: 5);

/// Full-screen QR of the branch for the tablet at the front desk: members scan it with the app, or type the
/// 6 digits under it. The code changes every few seconds; this screen asks the server for the next one the
/// moment the current one runs out.
class BranchQrScreen extends ConsumerStatefulWidget {
  const BranchQrScreen({super.key, required this.branchId});

  final String branchId;

  @override
  ConsumerState<BranchQrScreen> createState() => _BranchQrScreenState();
}

class _BranchQrScreenState extends ConsumerState<BranchQrScreen> {
  Timer? _timer;
  late DateTime _now;
  DateTime? _lastAsked;

  @override
  void initState() {
    super.initState();
    _now = ref.read(branchQrClockProvider)();
    _lastAsked = _now;
    _timer = Timer.periodic(branchQrTick, (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    final now = ref.read(branchQrClockProvider)();
    final code = ref.read(branchCodeProvider(widget.branchId));
    final current = code.valueOrNull;
    final asking = code.isLoading;
    final overdue = current != null && current.remainingAt(now) <= Duration.zero;
    final failed = code.hasError;
    final sinceAsked = now.difference(_lastAsked ?? now);
    // Next code when this one is over; again after a failure, but not on every tick.
    if (!asking && ((overdue && !failed) || (failed && sinceAsked >= branchQrRetryEvery))) {
      _lastAsked = now;
      ref.invalidate(branchCodeProvider(widget.branchId));
    }
    setState(() => _now = now);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final code = ref.watch(branchCodeProvider(widget.branchId));
    final current = code.valueOrNull;
    final branches = ref.watch(branchesProvider).valueOrNull;
    final branchName = branches?.where((b) => b.id == widget.branchId).map((b) => b.name).firstOrNull ?? current?.branchCode;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _TopBar(branchName: branchName, onClose: () => context.pop()),
            if (code.hasError && current != null)
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: InlineBanner(message: 'Mất kết nối. Mã có thể đã cũ, đang thử lại…'),
              ),
            Expanded(
              child: current == null
                  ? (code.hasError
                      ? ErrorState.fromError(code.error, onRetry: () => ref.invalidate(branchCodeProvider(widget.branchId)))
                      : const Center(child: CircularProgressIndicator()))
                  : _CodeView(code: current, now: _now),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.branchName, required this.onClose});

  final String? branchName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: <Widget>[
          IconButton(tooltip: 'Đóng', onPressed: onClose, icon: const Icon(HvpIcons.close)),
          Expanded(
            child: Text(
              branchName == null ? 'Check-in tại quầy' : 'Check-in · $branchName',
              style: t.titleM,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 48), // balances the close button so the title stays centred
        ],
      ),
    );
  }
}

class _CodeView extends StatelessWidget {
  const _CodeView({required this.code, required this.now});

  final BranchCheckinCode code;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth > box.maxHeight; // a tablet lying on its side
        final qrSize = math.max(160.0, math.min(wide ? box.maxHeight - 48 : box.maxWidth - 64, 420.0));
        final qr = _QrCard(code: code, size: qrSize, now: now);
        final info = _CodeInfo(code: code, now: now);
        return Padding(
          padding: const EdgeInsets.all(24),
          child: wide
              ? Row(
                  children: <Widget>[
                    Expanded(child: Center(child: qr)),
                    const SizedBox(width: 24),
                    Expanded(child: Center(child: SingleChildScrollView(child: info))),
                  ],
                )
              : Column(
                  children: <Widget>[
                    Expanded(child: Center(child: qr)),
                    const SizedBox(height: 16),
                    info,
                  ],
                ),
        );
      },
    );
  }
}

/// A code far past its end is hidden: it would be refused, and a stale QR on a wall screen helps nobody.
bool _isStale(BranchCheckinCode code, DateTime now) => code.remainingAt(now) < -Duration(seconds: code.ttlSeconds);

class _QrCard extends StatelessWidget {
  const _QrCard({required this.code, required this.size, required this.now});

  final BranchCheckinCode code;
  final double size;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final stale = _isStale(code, now);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.gold, width: 3)),
      child: stale
          ? Center(
              child: Text('Đang kết nối lại để lấy mã mới…', style: t.body.copyWith(color: Colors.black87), textAlign: TextAlign.center),
            )
          : QrImageView(
              key: ValueKey<String>('qr:${code.payload}'), // lets tests tell which code is on screen
              data: code.payload,
              backgroundColor: Colors.white,
              padding: EdgeInsets.zero,
              semanticsLabel: 'Mã QR check-in chi nhánh ${code.branchCode}',
            ),
    );
  }
}

class _CodeInfo extends StatelessWidget {
  const _CodeInfo({required this.code, required this.now});

  final BranchCheckinCode code;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    final stale = _isStale(code, now);
    final seconds = math.max(0, (code.remainingAt(now).inMilliseconds / 1000).ceil());
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('MÃ NHẬP TAY', style: t.label, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Semantics(
          label: 'Mã 6 số: ${code.shortCode.split('').join(' ')}',
          excludeSemantics: true,
          child: Text(
            stale ? '--- ---' : code.shortCodeSpaced,
            style: t.displayM.copyWith(letterSpacing: 6, color: stale ? c.textMuted : c.gold),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: code.fractionLeftAt(now),
            minHeight: 6,
            backgroundColor: c.surfaceHighest,
            valueColor: AlwaysStoppedAnimation<Color>(c.gold),
          ),
        ),
        const SizedBox(height: 6),
        Text('Đổi mã sau ${seconds}s', style: t.caption.copyWith(color: c.textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Text(
          'Mở app HVP, chọn Check-in và quét mã này. Không quét được thì nhập 6 số ở trên.',
          style: t.bodySmall.copyWith(color: c.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
