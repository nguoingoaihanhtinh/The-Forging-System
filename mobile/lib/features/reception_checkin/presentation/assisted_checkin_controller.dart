import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../../checkin/domain/checkin_outcome.dart';
import '../../checkin/presentation/checkin_providers.dart';
import 'reception_providers.dart';

/// Where a front-desk check-in is: filling the form, sending it, done, or refused.
sealed class AssistedState {
  const AssistedState();
}

class AssistedIdle extends AssistedState {
  const AssistedIdle();
}

class AssistedSubmitting extends AssistedState {
  const AssistedSubmitting();
}

class AssistedDone extends AssistedState {
  const AssistedDone(this.result);

  final CheckedIn result;
}

class AssistedFailed extends AssistedState {
  const AssistedFailed({required this.error, required this.memberId, required this.sessionId, required this.evidenceUrl});

  final ApiException error;
  final String memberId;
  final String sessionId;
  final String evidenceUrl;
}

/// Sends one front-desk check-in. The photo is uploaded beforehand (by the picker), so this only carries its URL.
class AssistedCheckinController extends AutoDisposeNotifier<AssistedState> {
  @override
  AssistedState build() => const AssistedIdle();

  Future<void> submit({required String memberId, required String sessionId, required String evidenceUrl}) async {
    if (state is AssistedSubmitting) return; // a double tap must not check in twice
    state = const AssistedSubmitting();
    try {
      final result = await ref.read(checkinRepositoryProvider).checkInFor(memberId: memberId, sessionId: sessionId, evidenceUrl: evidenceUrl);
      ref.invalidate(memberTodayProvider(memberId)); // the member's list shows the session as checked in
      state = AssistedDone(result);
    } catch (e) {
      final error = e is ApiException ? e : ApiException(code: ApiErrorCodes.unknown, message: errorMessage(e));
      state = AssistedFailed(error: error, memberId: memberId, sessionId: sessionId, evidenceUrl: evidenceUrl);
    }
  }

  /// Sends a refused request again (a lost connection says nothing about the request itself).
  Future<void> retry() async {
    final current = state;
    if (current is! AssistedFailed) return;
    await submit(memberId: current.memberId, sessionId: current.sessionId, evidenceUrl: current.evidenceUrl);
  }

  /// Back to the form, e.g. to retake the photo.
  void backToForm() => state = const AssistedIdle();
}

final assistedCheckinProvider = NotifierProvider.autoDispose<AssistedCheckinController, AssistedState>(AssistedCheckinController.new);
