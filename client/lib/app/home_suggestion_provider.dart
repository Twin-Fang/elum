import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logger/app_logger.dart';
import '../core/storage/local_storage.dart';
import '../shared/models/routine.dart';
import '../features/guardian/application/routine_providers.dart';
import '../features/guardian/application/routine_schedule_controller.dart';
import '../features/guardian/domain/home_suggestion.dart';
import '../features/guardian/domain/home_suggestion_finder.dart';
import '../features/member/application/plan_access.dart';
import '../features/subscription/domain/plan_benefit.dart';
import '../features/talk/application/talk_my_shared_posts_provider.dart';

/// 홈 권유의 본 기록: 닫은 (종류, 일과) 열쇠들 + 종류별 마지막 표시 시각
typedef HomeSuggestionHistory = ({Set<String> dismissedKeys, Map<String, DateTime> shownAtByKind});

final homeSuggestionHistoryProvider = NotifierProvider<HomeSuggestionHistoryNotifier, HomeSuggestionHistory>(
  HomeSuggestionHistoryNotifier.new,
);

/// 권유를 닫거나 버튼으로 이동했을 때 기록: 종류별 표시 시각 저장, 닫았으면 (종류, 일과)도 저장
class HomeSuggestionHistoryNotifier extends Notifier<HomeSuggestionHistory> {
  @override
  HomeSuggestionHistory build() {
    final storage = ref.read(localStorageProvider);
    return (
      dismissedKeys: storage.homeSuggestionDismissedKeys,
      shownAtByKind: storage.homeSuggestionShownAtByKind,
    );
  }

  /// 닫기(x): 다시 나오지 않음 + 표시 시각
  Future<void> markDismissed(HomeSuggestion suggestion) => _record(suggestion, isDismissed: true);

  /// 버튼으로 이동: 표시 시각만 (조건이 그대로면 한 달 뒤 다시 나올 수 있음)
  Future<void> markActedOn(HomeSuggestion suggestion) => _record(suggestion, isDismissed: false);

  Future<void> _record(HomeSuggestion suggestion, {required bool isDismissed}) async {
    final shownAtByKind = {...state.shownAtByKind, suggestion.kind.name: DateTime.now()};
    final dismissedKeys = {...state.dismissedKeys, if (isDismissed) suggestion.dismissedKey};
    state = (dismissedKeys: dismissedKeys, shownAtByKind: shownAtByKind);
    try {
      final storage = ref.read(localStorageProvider);
      await storage.setHomeSuggestionShownAtByKind(shownAtByKind);
      if (isDismissed) await storage.setHomeSuggestionDismissedKeys(dismissedKeys);
    } catch (e, stack) {
      // 안내용 기록이라 저장 실패로 화면 동작을 막지 않음 (이번 실행에서는 숨김 유지)
      AppLogger.error('homeSuggestion', e, stack, {'step': 'saveHistory'});
    }
  }
}

/// 지금 홈에 보일 권유 하나 (없으면 null)
///
/// 데이터: 오늘·지난 일과(보낸 기록), 일과관리 원본, 주간 반복 계획, 내가 올린 이야기
/// 하나라도 못 받았거나 실패하면 null (실패는 로그만, 어림으로 세지 않음)
final homeSuggestionProvider = Provider<HomeSuggestion?>((ref) {
  final history = ref.watch(homeSuggestionHistoryProvider);
  final now = DateTime.now();

  // 보낸 일과 (오늘 + 지난): 지난 일과는 서버가 최근 10건만 줘서 센 값이 실제보다 적을 수는 있어도 많지는 않음
  final todayRoutines = ref.watch(todayRoutinesProvider).value;
  final pastRoutines = ref.watch(pastRoutinesProvider).value;
  if (todayRoutines == null || pastRoutines == null) return null;
  final usageByOriginId = countRoutineSendUsage([...todayRoutines, ...pastRoutines]);

  // 권유 후보가 될 사용량이 없으면 일과관리 목록은 받지 않음
  final isAnyOriginPossible = usageByOriginId.values.any(
    (usage) =>
        usage.sentDays.length >= autoSendSuggestionStreakDays || usage.sendCount > talkShareSuggestionSendCount,
  );
  if (!isAnyOriginPossible) return null;

  final libraryAsync = ref.watch(routineLibraryProvider);
  final libraryRoutines = libraryAsync.value;
  if (libraryRoutines == null) {
    if (libraryAsync.hasError) {
      AppLogger.error('homeSuggestion', libraryAsync.error, libraryAsync.stackTrace, {'step': 'fetchLibrary'});
    }
    return null;
  }

  // 우선순위 순: 자동 보내기 > 이야기 올리기 > 일과 더 만들기
  final candidates = [
    ..._autoSendCandidates(ref, libraryRoutines, usageByOriginId, now),
    ..._talkShareCandidates(ref, libraryRoutines, usageByOriginId),
    ?findCreateMoreSuggestion(libraryRoutines: libraryRoutines, usageByOriginId: usageByOriginId),
  ];
  for (final candidate in candidates) {
    final isHidden = isSuggestionHidden(
      candidate,
      dismissedKeys: history.dismissedKeys,
      shownAtByKind: history.shownAtByKind,
      now: now,
    );
    if (!isHidden) return candidate;
  }
  return null;
});

/// 자동 보내기 후보: 반복이 이미 정해진 일과는 빼고, 앱에서 반복을 정하거나 Pro 로 갈 수 있을 때만
List<HomeSuggestion> _autoSendCandidates(
  Ref ref,
  List<Routine> libraryRoutines,
  Map<String, RoutineSendUsage> usageByOriginId,
  DateTime now,
) {
  final suggestions = findAutoSendSuggestions(
    libraryRoutines: libraryRoutines,
    usageByOriginId: usageByOriginId,
    now: now,
  );
  if (suggestions.isEmpty) return const [];
  if (!ref.watch(planAccessProvider).shouldShowEntryFor(PlanBenefit.routineSchedule)) return const [];
  final plan = ref.watch(routineSchedulePlanProvider);
  final schedulePlan = plan.value;
  if (schedulePlan == null) {
    if (plan.hasError) AppLogger.error('homeSuggestion', plan.error, plan.stackTrace, {'step': 'fetchSchedulePlan'});
    return const [];
  }
  return [
    for (final suggestion in suggestions)
      if (schedulePlan.scheduleOf(suggestion.routine.id) == null) suggestion,
  ];
}

/// 이야기 올리기 후보: 이미 올린 일과는 빼고, 올린 글을 못 받았으면 후보 없음
List<HomeSuggestion> _talkShareCandidates(
  Ref ref,
  List<Routine> libraryRoutines,
  Map<String, RoutineSendUsage> usageByOriginId,
) {
  final suggestions = findTalkShareSuggestions(libraryRoutines: libraryRoutines, usageByOriginId: usageByOriginId);
  if (suggestions.isEmpty) return const [];
  final sharedPosts = ref.watch(talkMySharedPostsProvider);
  final sharedPostIdByRoutineId = sharedPosts.value;
  if (sharedPostIdByRoutineId == null) {
    if (sharedPosts.hasError) {
      AppLogger.error('homeSuggestion', sharedPosts.error, sharedPosts.stackTrace, {'step': 'fetchSharedPosts'});
    }
    return const [];
  }
  return [
    for (final suggestion in suggestions)
      if (!sharedPostIdByRoutineId.containsKey(suggestion.routine.id)) suggestion,
  ];
}
