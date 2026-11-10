package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.core.TextProvider;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import java.util.List;
import java.util.Set;

/**
 * 일과·추가 질문 텍스트를 만드는 곳. 부르는 쪽은 어느 제공자인지 모른다.
 *
 * <p><b>왜 JSON 문자열을 돌려주나.</b> 호출부에 필요한 것은 언제나 JSON 한 덩어리라, 여기서 잘라야
 * 제공자별 응답 타입이 호출부에서 사라짐 (응답 객체를 올리면 제공자를 늘릴 때마다 호출부가 흔들림)
 *
 * <p>스키마 강제는 각 구현체의 책임이다. Gemini는 {@code responseSchema},
 * OpenAI는 {@code json_schema}로 길이 제약까지 다르게 표현해야 하기 때문이다.
 */
public interface TextGenerationClient {

  TextProvider provider();

  /**
   * 지금 쓸 수 있는 상태인가. API 키가 없으면 false.
   *
   * <p>관리자 화면이 이 값으로 전환 버튼을 막는다. 키 없는 제공자로 바꿔 놓으면
   * 일과 생성이 통째로 실패하므로 저장 단계에서 끊는다.
   */
  boolean available();

  /// 일과 생성. 반환값은 일과 제목·단계 배열이 담긴 JSON 문자열.
  ///
  /// @param includeImagePromptEn 카드마다 영어 장면 한 줄(imagePromptEn)도 받을지. 같은 호출이라 호출 수는
  ///                             그대로고 출력 토큰만 늘어, 만화 그림일 때만 켠다 (FLUX 와 그림 지시문의 sceneDetail 이 쓴다).
  String generateRoutineJson(
    String sanitizedInputText, String nickname, Set<SupportGoal> supportGoals, List<String> answers,
    boolean includeImagePromptEn
  );

  /// 도움 목표 기반 추가 질문 생성. 반환값은 questions 배열이 담긴 JSON 문자열.
  String generateQuestionJson(String nickname, Set<SupportGoal> supportGoals, String sanitizedInputText);

  /// 관리자 테스트 전용: 저장된 프롬프트 대신 전달받은 systemPrompt를 그대로 쓴다.
  String generateRoutineJsonForTest(String systemPrompt, String sampleInput);

  String generateQuestionJsonForTest(String systemPrompt, String sampleInput);

  /// 직접 추가한 카드에 붙일 무료 픽토그램 고르기. 반환값은 {"pictogramId": "..."|null} JSON 문자열.
  /// 카탈로그(id 목록)는 구현체가 요청에 싣는다. 검증·폴백은 부르는 쪽(PictogramPicker) 몫이다.
  String pickPictogramJson(String stepTitle, String stepDescription);

  /// AI 메모 갱신 (#1082). 입력은 처음 카드 <-> 확정 카드 비교 JSON(원문 없음), 반환값은 {"lines": [...]} JSON 문자열.
  /// 지시문·스키마는 RoutineMemorySpec 한 곳. 거르기·저장은 부르는 쪽(RoutineMemoryAi) 몫
  String buildRoutineMemoryJson(String memoryUserContent);

  /// 주간 리포트 정리 글. 입력은 집계 JSON(제목·횟수만, 이름은 {userName}), 반환값은 {"lines": [...]} JSON 문자열.
  /// 지시문·스키마는 WeeklyReportSummarySpec 한 곳(언어는 AiCallContext 일과 언어). 거르기·저장은 부르는 쪽 몫
  String buildWeeklyReportSummaryJson(String summaryUserContent);
}
