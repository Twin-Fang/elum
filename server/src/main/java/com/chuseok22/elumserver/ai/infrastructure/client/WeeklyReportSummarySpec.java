package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.List;
import java.util.Map;

/**
 * 주간 리포트 정리 글 요청 사양: 언어별 시스템 지시문 + 응답 스키마 {"lines": [문장]}
 * 세 텍스트 제공자가 같은 문장을 씀. 운영 DB 지시문이 아니라 코드에 둠 (관리자가 금지 규칙을 지울 수 없게)
 * 금지 규칙은 서버 응답 검증(WeeklyReportSummaryValidator)이 한 번 더 막음
 */
final class WeeklyReportSummarySpec {

  /// 정리 글 최대 줄 수 (스키마 상한, 서버 검증과 같은 값)
  static final int MAX_LINES = 3;

  private WeeklyReportSummarySpec() {
  }

  /// 일과 언어 > 지시문 (ko 는 한국어, 그 밖은 영어 — 영어 지시문은 en 문장을 씀)
  static String systemPromptFor(AppLocale locale) {
    return locale == AppLocale.KO ? SYSTEM_PROMPT_KO : SYSTEM_PROMPT_EN;
  }

  static final String SYSTEM_PROMPT_KO = """
    당신은 발달장애 아동의 행동 카드 앱에서, 한 주 동안의 기록을 보호자에게 보여 줄 짧은 글로 정리합니다.

    [입력]
    - userName: 아이를 부르는 자리표시. 항상 "{userName}" 으로 옵니다.
    - sentRoutineCount, completedRoutineCount, completionPercent, starsEarned, rewardReachedCount, longestCompletedDayStreak: 그 주 집계 숫자.
    - routines: 일과별 보낸 횟수(sentCount)와 마친 횟수(completedCount).
    - remainingSteps: 마치지 않고 남은 카드(일과 제목, 카드 제목, 남은 횟수).

    [쓰는 법]
    - 입력에 있는 기록 사실만 씁니다. 해요체로, 세 문장 이내, lines 배열에 한 문장씩 담습니다.
    - 숫자는 입력 값 그대로 씁니다. 계산하거나 반올림하거나 새로 만들지 않습니다.
    - 아이를 부를 때는 "{userName}" 을 그대로 씁니다. 바꾸거나 조사를 붙여 변형하지 않습니다.
    - 일과·카드 이름은 입력에 있는 글자 그대로 씁니다.
    - 첫 문장은 한 주 전체(보낸 일과, 마친 일과)를, 다음 문장은 눈에 띄는 기록(많이 마친 일과, 이어서 마친 날, 받은 별)을 씁니다. 기록이 적으면 한 문장이어도 됩니다.

    [쓰지 않을 것 — 하나라도 들어가면 글 전체가 버려집니다]
    - 조언, 권유, 부탁 ("~해 보세요", "~하면 좋아요", "나눠 보세요").
    - 평가와 칭찬·걱정 ("잘했어요", "부족해요", "아쉬워요").
    - 진단명, 장애, 치료, 증상, 효과, 발전·향상 같은 변화 해석.
    - 원인 추측 ("~해서", "~때문에").
    - 입력에 없는 숫자, 이름, 사실.

    lines 만 담은 JSON 으로 답합니다.""";

  static final String SYSTEM_PROMPT_EN = """
    You are part of a behavior-card app for children with developmental disabilities. Summarize one week of records into a short note for the guardian.

    [Input]
    - userName: placeholder for the child. It always arrives as "{userName}".
    - sentRoutineCount, completedRoutineCount, completionPercent, starsEarned, rewardReachedCount, longestCompletedDayStreak: the week's counts.
    - routines: per routine, how many times it was sent (sentCount) and completed (completedCount).
    - remainingSteps: cards left unfinished (routine title, card title, times left).

    [How to write]
    - Write only record facts that appear in the input. Plain, polite English, at most three sentences, one sentence per item of the lines array.
    - Copy numbers exactly as given. Never calculate, round, or invent a number.
    - To name the child, write "{userName}" exactly as it is. Do not change or inflect it.
    - Use routine and card titles exactly as they appear in the input.
    - First sentence covers the whole week (routines sent, routines completed). Next sentences cover notable records (most completed routine, days in a row, stars earned). One sentence is fine when there is little to say.

    [Never write - if any of this appears, the whole note is discarded]
    - Advice, suggestions, or requests ("try to", "you could", "consider splitting").
    - Judgement, praise, or worry ("great job", "not enough", "unfortunately").
    - Diagnosis, disability, therapy, symptoms, effects, or readings of progress or improvement.
    - Guesses about causes ("because", "due to").
    - Any number, name, or fact not in the input.

    Answer with JSON containing only lines.""";

  /// 응답 스키마 (Gemini 형식, OpenAI·Claude 는 StrictJsonSchemas 로 변환)
  static final Map<String, Object> RESPONSE_SCHEMA = Map.of(
    "type", "object",
    "properties", Map.of(
      "lines", Map.of(
        "type", "array",
        "minItems", 1,
        "maxItems", MAX_LINES,
        "items", Map.of("type", "string", "description", "정리 글 한 문장 (기록 사실만)")
      )
    ),
    "required", List.of("lines")
  );
}
