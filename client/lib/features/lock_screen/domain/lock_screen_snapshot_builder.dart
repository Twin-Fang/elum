import '../../../core/lock_screen/lock_screen_snapshot.dart';
import '../../../shared/models/action_card.dart';
import '../../../shared/models/routine.dart';

/// 일과 시각 (시·분, 알림 시각 또는 보낸 일과의 예정 시각)
typedef RoutineClockTime = ({int hour, int minute});

/// 오늘 일과 목록 > 잠금화면 요약: 끝낸 수/전체 수 > 다음 일과 > (이룸이 모드) 지금 할 카드 · 띄울 시간대
/// 카드 그림 파일 경로는 기기 저장소를 봐야 해서 응용 계층이 나중에 채움
abstract final class LockScreenSnapshotBuilder {
  // 일과 시각 앞뒤로 카드를 띄우는 범위 (시작 10분 전 ~ 60분 뒤)
  static const Duration windowLeadTime = Duration(minutes: 10);
  static const Duration windowTrailTime = Duration(minutes: 60);
  // 시작했지만 못 끝낸 일과: 요약을 만든 때부터 2시간 동안 계속 띄움
  static const Duration inProgressWindow = Duration(hours: 2);
  // 시각을 모르는 일과: 낮 시간(7시~21시)에만 띄움 (밤에 이룸이를 깨우지 않게)
  static const int daytimeStartHour = 7;
  static const int daytimeEndHour = 21;

  static LockScreenSnapshot build({
    required LockScreenMode mode,
    required List<Routine> routines,
    required bool Function(Routine routine, ActionCard card) isCardDone,
    required Map<String, RoutineClockTime> reminderTimeByRoutineId,
    required DateTime now,
  }) {
    bool isRoutineDone(Routine routine) =>
        routine.steps.isNotEmpty &&
        routine.steps.every((card) => isCardDone(routine, card));
    final unfinishedRoutines = routines
        .where((routine) => !isRoutineDone(routine))
        .toList();
    final doneCount = routines.length - unfinishedRoutines.length;
    final windowsByRoutineId = {
      for (final routine in unfinishedRoutines)
        routine.id: _activeWindowsOf(
          routine,
          reminderTime: reminderTimeByRoutineId[routine.id],
          hasStarted: routine.steps.any((card) => isCardDone(routine, card)),
          now: now,
        ),
    };
    final nextRoutine = unfinishedRoutines.isEmpty
        ? null
        : unfinishedRoutines.first;
    return LockScreenSnapshot(
      mode: mode,
      dateKey: LockScreenSnapshot.dateKeyOf(now),
      doneCount: doneCount,
      totalCount: routines.length,
      nextRoutineTitle: nextRoutine?.displayTitle,
      elumiCard: mode == LockScreenMode.elumi
          ? _elumiCardOf(
              _routineToShowNow(unfinishedRoutines, windowsByRoutineId, now),
              isCardDone,
            )
          : null,
      activeWindows: mode == LockScreenMode.elumi
          ? [for (final windows in windowsByRoutineId.values) ...windows]
          : const [],
    );
  }

  /// 지금 할 일과: 지금 시간대 안의 첫 일과 > 없으면 남은 첫 일과
  static Routine? _routineToShowNow(
    List<Routine> unfinishedRoutines,
    Map<String, List<({DateTime start, DateTime end})>> windowsByRoutineId,
    DateTime now,
  ) {
    for (final routine in unfinishedRoutines) {
      final windows = windowsByRoutineId[routine.id] ?? const [];
      if (windows.any((window) => _isInside(window, now))) return routine;
    }
    return unfinishedRoutines.isEmpty ? null : unfinishedRoutines.first;
  }

  /// 일과 > 아직 안 한 첫 카드 한 장 (카드 글은 제목 > 설명)
  static LockScreenElumiCard? _elumiCardOf(
    Routine? routine,
    bool Function(Routine routine, ActionCard card) isCardDone,
  ) {
    if (routine == null) return null;
    final sortedCards = [...routine.steps]
      ..sort((first, second) => first.stepOrder.compareTo(second.stepOrder));
    final nextCard = sortedCards
        .where((card) => !isCardDone(routine, card))
        .firstOrNull;
    if (nextCard == null) return null;
    return LockScreenElumiCard(
      routineId: routine.id,
      cardId: nextCard.id,
      routineTitle: routine.displayTitle,
      cardText: nextCard.displayTitle,
      contentLanguage: routine.language,
      pictogramId: nextCard.pictogramId,
      exampleImageId: nextCard.exampleImageId,
    );
  }

  /// 일과 하나의 시간대: 알림 시각 > 예정 시각(자정이 아닐 때) > 시작한 일과 > 시각 모름(낮 시간)
  static List<({DateTime start, DateTime end})> _activeWindowsOf(
    Routine routine, {
    required RoutineClockTime? reminderTime,
    required bool hasStarted,
    required DateTime now,
  }) {
    final scheduledTime = _scheduledClockTimeOf(routine);
    final windows = <({DateTime start, DateTime end})>[
      if (reminderTime != null) _aroundClockTime(reminderTime, now),
      if (scheduledTime != null && scheduledTime != reminderTime)
        _aroundClockTime(scheduledTime, now),
      if (hasStarted) (start: now, end: now.add(inProgressWindow)),
    ];
    if (windows.isNotEmpty) return windows;
    return [
      (
        start: DateTime(now.year, now.month, now.day, daytimeStartHour),
        end: DateTime(now.year, now.month, now.day, daytimeEndHour),
      ),
    ];
  }

  // 서버 scheduledAt 의 시·분 (자정이면 날짜만 정한 일과로 보고 null)
  static RoutineClockTime? _scheduledClockTimeOf(Routine routine) {
    final scheduledAt = routine.scheduledAt?.toLocal();
    if (scheduledAt == null) return null;
    if (scheduledAt.hour == 0 && scheduledAt.minute == 0) return null;
    return (hour: scheduledAt.hour, minute: scheduledAt.minute);
  }

  static ({DateTime start, DateTime end}) _aroundClockTime(
    RoutineClockTime clockTime,
    DateTime now,
  ) {
    final at = DateTime(
      now.year,
      now.month,
      now.day,
      clockTime.hour,
      clockTime.minute,
    );
    return (start: at.subtract(windowLeadTime), end: at.add(windowTrailTime));
  }

  static bool _isInside(({DateTime start, DateTime end}) window, DateTime now) =>
      !now.isBefore(window.start) && !now.isAfter(window.end);
}
