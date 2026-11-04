package com.chuseok22.elumserver.ai.core;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

/**
 * 일과 만들기 요청에 붙는 이룸이 맞춤 정보 (#1082, Pro): AI 메모 줄 + 보호자가 고쳐 확정한 지난 일과 예시
 * 보호자 입력 원문은 들지 않음 (확정 카드 글만). 이름은 부르는 쪽이 자리표시로 바꿔 넣음
 *
 * @param instruction       모델에게 이 정보를 어떻게 쓰는지 알려 주는 한 단락 (운영 DB 지시문과 무관하게 코드에서 붙음)
 * @param memoryNotes       AI 메모 줄 (최대 10줄)
 * @param confirmedExamples 최근 확정 일과 예시 (최대 3개)
 */
@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record RoutinePersonalization(
  String instruction,
  List<String> memoryNotes,
  List<ConfirmedExample> confirmedExamples
) {

  /**
   * 사용 안내: 쪼개기 크기·쓰는 말은 따르고, 이번 입력에 없는 행동·물건은 가져오지 않음
   * 실측(#1082)으로 고친 문장이라 바꾸면 prompt-eval 로 다시 비교
   */
  public static final String INSTRUCTION = """
    이 아이의 보호자가 지난 카드를 직접 고쳐 확정한 방식입니다. 이번 일과도 이 방식에 맞춰 만듭니다.
    - memoryNotes 와 confirmedExamples 의 카드 수·한 카드에 담는 행동 크기·바꿔 쓴 낱말·문장 길이를 따릅니다.
    - 메모에 "A 대신 B" 가 있으면 이번 카드에서도 A 를 쓰지 않고 B 를 씁니다. 메모에 적힌 대상에만 씁니다 (손 > 얼굴·몸으로 넓히지 않음).
    - 예시에서 행동·물건·장소를 가져오지 않습니다. 단계 내용은 이번 routineText 와 additionalAnswers 에서만 만듭니다.
    - 이번 일과와 상관없는 메모는 무시합니다.
    - 출력 형식과 글자 수·단계 수 규칙은 원래 지시를 그대로 지킵니다.""";

  public static RoutinePersonalization of(List<String> memoryNotes, List<ConfirmedExample> confirmedExamples) {
    return new RoutinePersonalization(INSTRUCTION, List.copyOf(memoryNotes), List.copyOf(confirmedExamples));
  }

  /** 넣을 것이 없으면 요청에서 필드째 빠짐 (Free·새 Pro 는 지금 하네스 그대로) */
  public boolean isEmpty() {
    return (memoryNotes == null || memoryNotes.isEmpty())
      && (confirmedExamples == null || confirmedExamples.isEmpty());
  }

  /// 확정 일과 하나: 제목 + 카드("제목 / 설명") 순서대로
  public record ConfirmedExample(String title, List<String> cards) {

  }
}
