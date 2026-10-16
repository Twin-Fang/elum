import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../data/credit_repository.dart';
import '../domain/credit_history.dart';

/// 사용 내역 화면의 목록 상태: 지금까지 받은 줄 + 다음 쪽 진행.
@immutable
class CreditHistoryState {
  const CreditHistoryState({
    required this.entries,
    required this.hasNext,
    required this.nextPage,
    this.isLoadingMore = false,
    this.moreFailure,
  });

  final List<CreditHistoryEntry> entries;
  final bool hasNext;
  final int nextPage;
  final bool isLoadingMore;

  /// 다음 쪽을 못 받았을 때의 실패. 이미 받은 줄은 그대로 둔다.
  final AppFailure? moreFailure;

  CreditHistoryState copyWith({
    List<CreditHistoryEntry>? entries,
    bool? hasNext,
    int? nextPage,
    bool? isLoadingMore,
    AppFailure? Function()? moreFailure,
  }) => CreditHistoryState(
    entries: entries ?? this.entries,
    hasNext: hasNext ?? this.hasNext,
    nextPage: nextPage ?? this.nextPage,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    moreFailure: moreFailure != null ? moreFailure() : this.moreFailure,
  );
}

/// 사용 내역: 첫 쪽 조회 > 끝에 닿을 때마다 다음 쪽 이어 붙이기
class CreditHistoryNotifier extends AsyncNotifier<CreditHistoryState> {
  @override
  Future<CreditHistoryState> build() async {
    final page = await ref.watch(creditRepositoryProvider).getHistory(page: 0);
    return CreditHistoryState(
      entries: page.entries,
      hasNext: page.hasNext,
      nextPage: page.page + 1,
    );
  }

  /// 다음 쪽을 이어 붙인다. 이미 받는 중이거나 끝이면 아무것도 하지 않는다.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasNext || current.isLoadingMore) return;

    state = AsyncData(
      current.copyWith(isLoadingMore: true, moreFailure: () => null),
    );
    try {
      final page = await ref
          .read(creditRepositoryProvider)
          .getHistory(page: current.nextPage);
      // 쪽 경계에서 같은 줄이 겹쳐 와도 한 번만 보인다
      final knownIds = {for (final entry in current.entries) entry.id};
      state = AsyncData(
        current.copyWith(
          entries: [
            ...current.entries,
            for (final entry in page.entries)
              if (!knownIds.contains(entry.id)) entry,
          ],
          hasNext: page.hasNext,
          nextPage: page.page + 1,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      state = AsyncData(
        current.copyWith(
          isLoadingMore: false,
          moreFailure: () => AppFailure.of(e),
        ),
      );
    }
  }
}

/// 화면을 떠나면 버린다 — 다음에 열 때 새로 받는다. 저절로 다시 시도하지 않는다(`retry`):
/// 실패 화면이 로딩으로 깜빡이고 요청이 쌓이기 때문이다.
final creditHistoryProvider =
    AsyncNotifierProvider.autoDispose<CreditHistoryNotifier, CreditHistoryState>(
      CreditHistoryNotifier.new,
      retry: (_, _) => null,
    );
