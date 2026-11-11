import 'package:flutter/foundation.dart';

import '../../../shared/models/routine.dart';

/// 보호자 홈 권유 종류 3개: 선언 순서가 우선순위 (자동 보내기 > 이야기 올리기 > 일과 더 만들기)
enum HomeSuggestionKind { autoSend, talkShare, createMore }

/// 자동 보내기: 같은 일과를 이어서 보낸 날 수 (이상이면 권유)
const autoSendSuggestionStreakDays = 3;

/// 이야기 올리기: 같은 일과를 보낸 횟수 (넘으면 권유)
const talkShareSuggestionSendCount = 5;

/// 일과 더 만들기: 일과가 하나뿐일 때 그 일과를 보낸 날 수 (넘으면 권유)
const createMoreSuggestionSentDays = 3;

/// 같은 종류를 다시 보이기까지 기간 (마지막으로 보인 뒤)
const homeSuggestionRepeatIntervalDays = 30;

/// 홈에 보일 권유 하나: 종류 + 대상 일과(일과관리 원본) + 보낸 날 수(문구용)
@immutable
class HomeSuggestion {
  const HomeSuggestion({required this.kind, required this.routine, required this.sentDayCount});

  final HomeSuggestionKind kind;
  final Routine routine;

  /// 자동 보내기는 이어서 보낸 날 수, 그 밖에는 보낸 날 수
  final int sentDayCount;

  /// 닫은 기록 열쇠 `{종류}:{일과 id}`
  String get dismissedKey => '${kind.name}:${routine.id}';
}

/// 보낸 일과(오늘 + 지난) 중 한 원본의 사용 기록: 보낸 횟수와 보낸 날들
@immutable
class RoutineSendUsage {
  const RoutineSendUsage({this.sendCount = 0, this.sentDays = const {}});

  final int sendCount;

  /// 시각을 뺀 날짜들
  final Set<DateTime> sentDays;
}

/// 보낸 일과 목록 > 원본 일과 id 별 사용 기록
///
/// 원본 id = 보내기로 만든 일과의 `sourceRoutineId`, 없으면 그 일과 자신. 날짜를 모르는 일과는 날 수에서 뺀다
Map<String, RoutineSendUsage> countRoutineSendUsage(List<Routine> sentRoutines) {
  final usageByOriginId = <String, RoutineSendUsage>{};
  for (final routine in sentRoutines) {
    final originId = routine.sourceRoutineId ?? routine.id;
    final previous = usageByOriginId[originId] ?? const RoutineSendUsage();
    final scheduledAt = routine.scheduledAt;
    usageByOriginId[originId] = RoutineSendUsage(
      sendCount: previous.sendCount + 1,
      sentDays: {
        ...previous.sentDays,
        if (scheduledAt != null) DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day),
      },
    );
  }
  return usageByOriginId;
}

/// 오늘(없으면 어제)부터 거꾸로 이어서 보낸 날 수. 어제도 안 보냈으면 0
int countSendStreakDays(Set<DateTime> sentDays, DateTime now) {
  var day = DateTime(now.year, now.month, now.day);
  if (!sentDays.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
  var streak = 0;
  while (sentDays.contains(day)) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return streak;
}

/// 권유를 이미 보였거나 닫았는가: 닫은 (종류, 일과)는 다시 안 나오고, 같은 종류는 [homeSuggestionRepeatIntervalDays] 안에 다시 안 나옴
bool isSuggestionHidden(
  HomeSuggestion suggestion, {
  required Set<String> dismissedKeys,
  required Map<String, DateTime> shownAtByKind,
  required DateTime now,
}) {
  if (dismissedKeys.contains(suggestion.dismissedKey)) return true;
  final shownAt = shownAtByKind[suggestion.kind.name];
  return shownAt != null && now.difference(shownAt) < const Duration(days: homeSuggestionRepeatIntervalDays);
}
