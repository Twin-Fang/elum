package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.core.TextProvider;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import java.util.List;
import java.util.Set;

/**
 * 일과·추가 질문 텍스트를 만드는 곳. 부르는 쪽은 어느 제공자인지 모른다.
 *
 * <p><b>왜 JSON 문자열을 돌려주나.</b> 호출부는 예전부터 제공자 응답 객체에서
 * {@code candidates[0].content.parts[0].text}를 꺼내 곧바로 {@code ObjectMapper}에
 * 넘기고 있었다. 즉 실제로 필요한 것은 언제나 JSON 한 덩어리였다. 그 지점에서 잘라야
 * 제공자별 응답 타입이 호출부에서 사라진다 — 응답 객체를 인터페이스로 끌어올리면
 * 제공자를 늘릴 때마다 호출부가 함께 흔들린다.
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
  String generateRoutineJson(
    String sanitizedInputText, String nickname, Set<SupportGoal> supportGoals, List<String> answers
  );

  /// 도움 목표 기반 추가 질문 생성. 반환값은 questions 배열이 담긴 JSON 문자열.
  String generateQuestionJson(String nickname, Set<SupportGoal> supportGoals, String sanitizedInputText);

  /// 관리자 테스트 전용: 저장된 프롬프트 대신 전달받은 systemPrompt를 그대로 쓴다.
  String generateRoutineJsonForTest(String systemPrompt, String sampleInput);

  String generateQuestionJsonForTest(String systemPrompt, String sampleInput);
}
