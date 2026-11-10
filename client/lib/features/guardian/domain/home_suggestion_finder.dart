import '../../../shared/models/routine.dart';
import 'home_suggestion.dart';

/// 자동 보내기 후보: 일과관리 원본 중 내가 고칠 수 있고 [autoSendSuggestionStreakDays] 일 이어서 보낸 것, 이어서 보낸 날이 많은 순
/// 이미 반복이 정해진 일과는 부르는 쪽이 뺌
List<HomeSuggestion> findAutoSendSuggestions({
  required List<Routine> libraryRoutines,
  required Map<String, RoutineSendUsage> usageByOriginId,
  required DateTime now,
}) {
  final suggestions = [
    for (final routine in libraryRoutines)
      if (routine.isEditableByMe)
        if (usageByOriginId[routine.id] case final usage?)
          if (countSendStreakDays(usage.sentDays, now) >= autoSendSuggestionStreakDays)
            HomeSuggestion(
              kind: HomeSuggestionKind.autoSend,
              routine: routine,
              sentDayCount: countSendStreakDays(usage.sentDays, now),
            ),
  ];
  return suggestions..sort((a, b) => b.sentDayCount.compareTo(a.sentDayCount));
}

/// 이야기 올리기 후보 중 이야기에 올릴 수 있는 원본인가 (예시 · 이야기에서 가져온 일과 제외)
bool isTalkShareableOrigin(Routine routine) => !routine.isExample && routine.talkPostId == null;

/// 이야기 올리기 후보: 올릴 수 있는 원본 중 [talkShareSuggestionSendCount] 번 넘게 보낸 것, 많이 보낸 순
/// 이미 이야기에 올린 일과는 부르는 쪽이 뺌
List<HomeSuggestion> findTalkShareSuggestions({
  required List<Routine> libraryRoutines,
  required Map<String, RoutineSendUsage> usageByOriginId,
}) {
  final suggestions = [
    for (final routine in libraryRoutines)
      if (isTalkShareableOrigin(routine))
        if (usageByOriginId[routine.id] case final usage?)
          if (usage.sendCount > talkShareSuggestionSendCount)
            HomeSuggestion(kind: HomeSuggestionKind.talkShare, routine: routine, sentDayCount: usage.sentDays.length),
  ];
  return suggestions..sort((a, b) {
    final aCount = usageByOriginId[a.routine.id]?.sendCount ?? 0;
    final bCount = usageByOriginId[b.routine.id]?.sendCount ?? 0;
    return bCount.compareTo(aCount);
  });
}

/// 일과 더 만들기 후보: 일과관리에 일과가 하나뿐이고 [createMoreSuggestionSentDays] 일 넘게 보낸 경우
HomeSuggestion? findCreateMoreSuggestion({
  required List<Routine> libraryRoutines,
  required Map<String, RoutineSendUsage> usageByOriginId,
}) {
  if (libraryRoutines.length != 1) return null;
  final onlyRoutine = libraryRoutines.single;
  final sentDayCount = usageByOriginId[onlyRoutine.id]?.sentDays.length ?? 0;
  if (sentDayCount <= createMoreSuggestionSentDays) return null;
  return HomeSuggestion(kind: HomeSuggestionKind.createMore, routine: onlyRoutine, sentDayCount: sentDayCount);
}
