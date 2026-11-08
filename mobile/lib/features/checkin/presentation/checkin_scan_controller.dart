import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../domain/checkin_outcome.dart';
import '../domain/checkin_session.dart';
import 'checkin_providers.dart';

/// What the member gave the server: the QR text the camera read, or the 6 digits typed instead.
class ScanCode {
  const ScanCode.scanned(String this.payload) : shortCode = null;
  const ScanCode.typed(String this.shortCode) : payload = null;

  final String? payload;
  final String? shortCode;

  bool get isTyped => shortCode != null;

  @override
  bool operator ==(Object other) => other is ScanCode && other.payload == payload && other.shortCode == shortCode;

  @override
  int get hashCode => Object.hash(payload, shortCode);
}

/// Where the scan screen is: waiting for a code, talking to the server, asking which session,
/// done, or refused.
sealed class ScanState {
  const ScanState();
}

class ScanIdle extends ScanState {
  const ScanIdle();
}

class ScanSubmitting extends ScanState {
  const ScanSubmitting();
}

class ScanChoosing extends ScanState {
  const ScanChoosing({required this.code, required this.sessions});

  final ScanCode code;
  final List<CheckinSession> sessions;
}

class ScanDone extends ScanState {
  const ScanDone(this.result);

  final CheckedIn result;
}

class ScanFailed extends ScanState {
  const ScanFailed({required this.error, required this.code, this.sessionId});

  final ApiException error;
  final ScanCode code;
  final String? sessionId;

  CheckinAction get action => checkinActionOf(error);
}

/// Drives one scan: the camera hands over a code, the server decides.
///
/// Only the first code counts while idle: the camera keeps reporting the same QR many times a second.
/// A refused code is also ignored if it comes straight back (it would only be refused again) until the
/// member scans something different or asks to retry.
class CheckinScanController extends AutoDisposeNotifier<ScanState> {
  ScanCode? _lastRefused;

  @override
  ScanState build() => const ScanIdle();

  Future<void> onCode(String payload, {String? sessionId}) async {
    final code = ScanCode.scanned(payload);
    if (state is! ScanIdle || code == _lastRefused) return;
    await _submit(code, sessionId);
  }

  /// The 6 digits the member typed because they could not scan. Typing is deliberate, so unlike a camera read it
  /// is sent even if the same digits were refused a moment ago. Anything but exactly 6 digits is ignored.
  Future<void> onTypedCode(String digits, {String? sessionId}) async {
    if (state is! ScanIdle || !RegExp(r'^\d{6}$').hasMatch(digits)) return;
    _lastRefused = null;
    await _submit(ScanCode.typed(digits), sessionId);
  }

  /// The member picked one of the sessions offered after [ScanChoosing].
  Future<void> choose(String sessionId) async {
    final current = state;
    if (current is! ScanChoosing) return;
    await _submit(current.code, sessionId);
  }

  /// Sends a refused code again (a lost connection says nothing about the code itself).
  Future<void> retry() async {
    final current = state;
    if (current is! ScanFailed) return;
    _lastRefused = null;
    await _submit(current.code, current.sessionId);
  }

  /// Back to scanning.
  void scanAgain() => state = const ScanIdle();

  Future<void> _submit(ScanCode code, String? sessionId) async {
    state = const ScanSubmitting();
    try {
      final outcome = await ref.read(checkinRepositoryProvider).submit(payload: code.payload, shortCode: code.shortCode, sessionId: sessionId);
      switch (outcome) {
        case CheckedIn():
          _lastRefused = null;
          ref.invalidate(todayCheckinProvider); // the tab shows the session as checked in
          state = ScanDone(outcome);
        case ChooseSession(:final sessions):
          state = ScanChoosing(code: code, sessions: sessions);
      }
    } catch (e) {
      final error = e is ApiException ? e : ApiException(code: ApiErrorCodes.unknown, message: errorMessage(e));
      _lastRefused = code;
      state = ScanFailed(error: error, code: code, sessionId: sessionId);
    }
  }
}

final checkinScanProvider = NotifierProvider.autoDispose<CheckinScanController, ScanState>(CheckinScanController.new);
