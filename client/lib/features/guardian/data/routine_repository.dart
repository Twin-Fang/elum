import '../../../core/network/app_failure.dart';
import '../../../shared/models/routine.dart';
import '../../../shared/models/support_goal.dart';
import '../domain/routine_suggestion.dart';

/// 일과 저장소.
///
/// **절대 throw하지 않는다.** 데모는 어떤 실패에도 끝까지 진행되어야 한다 (docs 원칙 6번).
/// 화면은 에러 분기를 쓸 일이 없고, 따라서 빠뜨릴 수도 없다.
abstract interface class RoutineRepository {
  /// AI 추가 질문.
  ///
  /// - 서버가 응답은 했는데 실패면 **질문 없음**을 준다 — 카드 만들기로 넘어간다.
  /// - 서버에 **닿지 못했으면** [AppFailure] 를 던진다. 다음 단계(카드 만들기)도
  ///   어차피 실패하므로 흐름이 연결 안내와 다시 하기를 띄운다 (#393 S1 · #352).
  ///
  /// 어느 쪽이든 **입력과 무관한 대체 질문은 만들지 않는다** (#393 S1).
  Future<RoutineQuestion> generateQuestion(String rawInputText);

  /// 내가 만든 일과 목록 — 보호자_홈의 "최근 일과".
  /// 실패하면 빈 목록을 준다. 화면은 빈 상태 UI를 그린다.
  Future<List<Routine>> getMyRoutines();

  /// 오늘 할 일 — 아이 홈 목록 (이슈 #75, `GET /api/routines/today`).
  ///
  /// 서버가 오늘(KST) + CONFIRMED/COMPLETED만 진행률과 함께 예정 시각순으로 준다.
  /// 실패하면 [getMyRoutines]로 폴백한다 — 아이 목록이 비는 것보다
  /// 클라이언트 필터로라도 보여주는 쪽이 낫다 (docs 원칙 6번).
  Future<List<Routine>> getTodayRoutines();

  /// 추천 일과 — 보호자_홈 타일과 일과 만들기 화면의 칩.
  /// 실패하면 [RoutineSuggestion.fallback]을 준다. 추천이 비면 화면 한 블록이
  /// 통째로 사라져 빈 화면처럼 보이기 때문이다.
  Future<List<RoutineSuggestion>> getSuggestions();

  /// 일과 생성 → 카드 5장.
  ///
  /// [rewardText]는 보호자가 카드 생성 **전에** 정한 보상이다. 비워둘 수 있다.
  ///
  /// [idempotencyKey]는 `Idempotency-Key` 헤더로 간다 (#407). 같은 키로 다시 오면
  /// 서버가 AI 를 다시 부르지 않고 저장된 일과를 준다 — 재시도가 크레딧을 두 번
  /// 쓰지 않는다. 비우면 헤더를 보내지 않고 서버가 만든다(구버전 호환과 같은 길).
  Future<Routine> createRoutine({
    required String rawInputText,
    required Set<SupportGoal> goals,
    List<String> answers,
    String rewardText,
    String rewardPresetKey,
    String idempotencyKey,
  });

  /// 보호자 승인. 이후에만 아동 화면에 노출된다 (docs 원칙 3번).
  Future<Routine> confirm(Routine routine);

  /// 카드 한 장을 일과에서 뺀다 (이슈 #405).
  ///
  /// 카드확인의 X 는 화면에서만 지우고, **저장하기가 이것으로 서버에 반영한다** —
  /// 나가기 팝업이 "뺀 카드는 저장하기를 눌러야 빠져요"라고 약속하는 그 동작이다.
  /// 승인([confirm])은 본문 없이 상태만 바꾸므로 여기를 거치지 않으면 뺀 카드가
  /// 서버에 그대로 남는다.
  ///
  /// null 이면 성공. 실패하면 서버가 알려준 이유가 담겨 온다 (#352).
  Future<AppFailure?> deleteStep(String routineId, String stepId);

  /// 카드 한 장을 직접 추가한다 (#444 · 시안 1197:6044 `새로운 카드 추가`).
  ///
  /// **그림은 만들지 않는다.** 서버는 `generateImage` 를 줄 때만 그림을 그리고(#407),
  /// 시안에는 그림을 고르는 자리가 없다.
  ///
  /// [failure]가 null이 아니면 서버에 못 넣었다는 뜻이고 [routine]은 그대로다 — 수정과 달리
  /// **로컬에만 넣지 않는다.** 새 카드는 서버가 준 id 가 있어야 이후에 고치고 옮길 수 있다.
  /// (서버가 없는 로컬 데모 일과는 로컬에 넣는다.)
  Future<({Routine routine, AppFailure? failure})> addStep(
    Routine routine, {
    required String title,
    required String description,
  });

  /// 카드 문장 수정.
  ///
  /// [failure]가 null이 아니면 서버 반영에 실패해 **로컬에만** 반영됐다는 뜻이다.
  /// 그 안에 서버가 알려준 이유가 들어 있다 — 화면이 그대로 띄운다 (#352).
  /// 화면이 이 값으로 "서버 저장 실패" 안내를 띄운다 — 실패를 조용히 삼키면
  /// 보호자는 저장된 줄 알고 앱을 끈다.
  Future<({Routine routine, AppFailure? failure})> updateStep(
    Routine routine,
    String stepId, {
    required String title,
    required String description,
  });

  // --- 보상(강화물) · 일과 정리 (이슈 #148~150) ---

  /// 보호자가 정한 보상을 저장한다. [rewardText]가 비면 **보상을 지운다**.
  ///
  /// 실패하면 로컬 반영만 하고 실패 이유를 함께 준다 — 보상은 선택 항목이라
  /// 저장에 실패했다고 일과 만들기를 막지 않는다. 대신 화면이 안내는 띄운다.
  Future<({Routine routine, AppFailure? failure})> updateReward(
    Routine routine, {
    required String rewardText,
    String rewardPresetKey,
  });

  /// 최근에 정한 보상 — 보상 설정 화면 상단의 재사용 칩.
  /// 실패하면 **빈 목록**이다. 화면은 섹션을 통째로 숨긴다 (없어도 되는 기능이다).
  Future<List<RecentReward>> getRecentRewards();

  /// 지난 일과 — 보호자 홈의 접힌 구역. 실패하면 빈 목록.
  Future<List<Routine>> getPastRoutines();

  /// 임시저장 — 카드는 만들었지만 아직 아이에게 보내지 않은 것. 실패하면 빈 목록.
  Future<List<Routine>> getDraftRoutines();

  /// 지난 일과 다시 하기. 서버가 오늘 날짜로 복제해 돌려준다.
  /// 실패하면 **null** — 화면이 토스트로 알리고 목록은 그대로 둔다.
  /// 성공하면 복제된 일과, 실패하면 **이유**가 담겨 온다 (#352).
  Future<Attempt<Routine>> duplicate(String routineId);

  /// 일과 삭제. 성공 여부를 돌려준다. 실패해도 throw하지 않는다.
  /// null 이면 성공. 실패하면 서버가 알려준 이유가 담겨 온다 (#352).
  Future<AppFailure?> delete(String routineId);

  /// 홈 목록의 순서를 통째로 저장한다.
  ///
  /// 화면에 보이는 **전체**를 차례대로 보낸다. 일부만 보내는 방식이 아니다 —
  /// 부분 갱신은 두 곳에서 동시에 순서를 바꿀 때 뒤엉킨다.
  /// null 이면 성공. 실패하면 서버가 알려준 이유가 담겨 온다 (#352).
  Future<AppFailure?> reorder(List<String> routineIds);

  /// 일과 안의 행동 단계 순서를 바꾼다.
  ///
  /// 일과 순서([reorder])와 같은 방식이다 — **화면에 보이는 단계 전체를 차례대로**
  /// 보낸다. 실패하면 false를 주고, 부르는 쪽이 화면을 되돌린다.
  /// null 이면 성공. 실패하면 서버가 알려준 이유가 담겨 온다 (#352).
  Future<AppFailure?> reorderSteps(String routineId, List<String> stepIds);
}

