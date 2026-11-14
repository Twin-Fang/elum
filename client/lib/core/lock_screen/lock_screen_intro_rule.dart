/// 잠금화면 소개 시트 노출 판정 (과한 권유 금지): 처음 1번 + 닫은 지 7일 뒤 1번, 그 뒤 없음
/// 조건 4개: 기능 사용 가능(Android), 아직 안 켬, 이룸이가 일과를 한 번이라도 끝냄, 노출 기록
abstract final class LockScreenIntroRule {
  // 소개 시트 최대 노출 횟수 (처음 + 다시 한 번)
  static const int maximumShownCount = 2;
  // 두 번째 노출까지 기다리는 기간
  static const Duration secondShowDelay = Duration(days: 7);

  static bool shouldShow({
    required bool isAvailable,
    required bool isEnabled,
    required bool hasElumiCompletedRoutine,
    required int shownCount,
    required DateTime? lastShownAt,
    required DateTime now,
  }) {
    if (!isAvailable || isEnabled || !hasElumiCompletedRoutine) return false;
    if (shownCount >= maximumShownCount) return false;
    if (shownCount == 0 || lastShownAt == null) return true;
    return now.difference(lastShownAt) >= secondShowDelay;
  }
}
