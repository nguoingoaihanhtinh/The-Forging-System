import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../domain/checkin_outcome.dart';
import '../domain/checkin_session.dart';
import 'checkin_providers.dart';

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
  const ScanChoosing({required this.payload, required this.sessions});

  final String payload;
  final List<CheckinSession> sessions;
}

class ScanDone extends ScanState {
  const ScanDone(this.result);

  final CheckedIn result;
}

class ScanFailed extends ScanState {
  const ScanFailed({required this.error, required this.payload, this.sessionId});

  final ApiException error;
  final String payload;
  final String? sessionId;

  CheckinAction get action => checkinActionOf(error);
}

/// Drives one scan: the camera hands over a code, the server decides.
///
/// Only the first code counts while idle: the camera keeps reporting the same QR many times a second.
/// A refused code is also ignored if it comes straight back (it would only be refused again) until the
/// member scans something different or asks to retry.
class CheckinScanController extends AutoDisposeNotifier<ScanState> {
  String? _lastRefused;

  @override
  ScanState build() => const ScanIdle();

  Future<void> onCode(String payload, {String? sessionId}) async {
    if (state is! ScanIdle || payload == _lastRefused) return;
    await _submit(payload, sessionId);
  }

  /// The member picked one of the sessions offered after [ScanChoosing].
  Future<void> choose(String sessionId) async {
    final current = state;
    if (current is! ScanChoosing) return;
    await _submit(current.payload, sessionId);
  }

  /// Sends a refused code again (a lost connection says nothing about the code itself).
  Future<void> retry() async {
    final current = state;
    if (current is! ScanFailed) return;
    _lastRefused = null;
    await _submit(current.payload, current.sessionId);
  }

  /// Back to scanning.
  void scanAgain() => state = const ScanIdle();

  Future<void> _submit(String payload, String? sessionId) async {
    state = const ScanSubmitting();
    try {
      final outcome = await ref.read(checkinRepositoryProvider).submit(payload: payload, sessionId: sessionId);
      switch (outcome) {
        case CheckedIn():
          _lastRefused = null;
          ref.invalidate(todayCheckinProvider); // the tab shows the session as checked in
          state = ScanDone(outcome);
        case ChooseSession(:final sessions):
          state = ScanChoosing(payload: payload, sessions: sessions);
      }
    } catch (e) {
      final error = e is ApiException ? e : ApiException(code: ApiErrorCodes.unknown, message: errorMessage(e));
      _lastRefused = payload;
      state = ScanFailed(error: error, payload: payload, sessionId: sessionId);
    }
  }
}

final checkinScanProvider = NotifierProvider.autoDispose<CheckinScanController, ScanState>(CheckinScanController.new);
