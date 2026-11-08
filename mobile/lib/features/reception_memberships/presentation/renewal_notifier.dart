import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/error_mapper.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../domain/renewal_models.dart';
import 'reception_memberships_providers.dart';

/// Search text and status of the inbox.
class RenewalFilter {
  const RenewalFilter({this.q = '', this.status = 'PENDING'});

  final String q;
  final String status;

  @override
  bool operator ==(Object other) =>
      other is RenewalFilter && other.q == q && other.status == status;

  @override
  int get hashCode => Object.hash(q, status);
}

class RenewalFilterNotifier extends Notifier<RenewalFilter> {
  @override
  RenewalFilter build() {
    ref.watch(currentUserIdProvider);
    return const RenewalFilter();
  }

  void setQuery(String q) => state = RenewalFilter(q: q, status: state.status);

  void setStatus(String status) =>
      state = RenewalFilter(q: state.q, status: status);
}

final renewalFilterProvider =
    NotifierProvider<RenewalFilterNotifier, RenewalFilter>(
        RenewalFilterNotifier.new);

/// Loaded pages of the inbox.
class RenewalListState {
  const RenewalListState(
      {required this.items,
      required this.page,
      required this.hasMore,
      this.loadingMore = false,
      this.loadMoreError});

  final List<RenewalRequest> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final String? loadMoreError;
}

/// Paginated inbox. Rebuilds (page 1) when the filter or the user changes.
class RenewalListNotifier extends AutoDisposeAsyncNotifier<RenewalListState> {
  static const int pageSize = 20;

  @override
  Future<RenewalListState> build() async {
    ref.watch(currentUserIdProvider);
    final filter = ref.watch(renewalFilterProvider);
    final page = await ref
        .read(receptionMembershipsRepositoryProvider)
        .renewals(q: filter.q, status: filter.status, page: 1, limit: pageSize);
    return RenewalListState(
        items: page.items, page: page.page, hasMore: page.hasMore);
  }

  /// Appends the next page; an error keeps the loaded rows on screen.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    final filter = ref.read(renewalFilterProvider);
    state = AsyncData<RenewalListState>(
      RenewalListState(
          items: current.items,
          page: current.page,
          hasMore: true,
          loadingMore: true),
    );
    try {
      final page = await ref
          .read(receptionMembershipsRepositoryProvider)
          .renewals(
              q: filter.q,
              status: filter.status,
              page: current.page + 1,
              limit: pageSize);
      // The filter changed while loading: this notifier was rebuilt, drop the stale page.
      if (ref.read(renewalFilterProvider) != filter) return;
      state = AsyncData<RenewalListState>(
        RenewalListState(
            items: <RenewalRequest>[...current.items, ...page.items],
            page: page.page,
            hasMore: page.hasMore),
      );
    } catch (e) {
      if (ref.read(renewalFilterProvider) != filter) return;
      state = AsyncData<RenewalListState>(
        RenewalListState(
            items: current.items,
            page: current.page,
            hasMore: true,
            loadMoreError: errorMessage(e)),
      );
    }
  }
}

final renewalListProvider =
    AsyncNotifierProvider.autoDispose<RenewalListNotifier, RenewalListState>(
        RenewalListNotifier.new);
