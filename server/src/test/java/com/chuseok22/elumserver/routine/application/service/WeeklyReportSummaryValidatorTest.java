package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// AI 정리 글 검증: 걸러지지 않으면 보호자 화면에 조언·평가·없는 숫자가 사실처럼 나간다
class WeeklyReportSummaryValidatorTest {

  private static final Set<String> NUMBERS = Set.of("5", "4", "80", "2", "3", "0");

  @Test
  @DisplayName("기록 사실만 담은 글은 통과한다 — 막히면 AI 글이 한 번도 안 나간다")
  void factsOnly_isAccepted() {
    WeeklyReportSummaryValidator.Result result = WeeklyReportSummaryValidator.validate(
      List.of("{userName}는 일과 5개 중 4개를 마쳤어요.", "받은 별은 3개예요."), NUMBERS);

    assertThat(result.isAccepted()).isTrue();
    assertThat(result.lines()).hasSize(2);
  }

  @Test
  @DisplayName("권유 문장(카드를 나눠 보세요)이 들어 있으면 글 전체를 버린다 — 조언이 기록처럼 보이지 않게")
  void advice_isRejected() {
    WeeklyReportSummaryValidator.Result result = WeeklyReportSummaryValidator.validate(
      List.of("{userName}는 일과 5개 중 4개를 마쳤어요.", "카드를 나눠 보세요."), NUMBERS);

    assertThat(result.isAccepted()).isFalse();
    assertThat(result.lines()).isEmpty();
  }

  @Test
  @DisplayName("진단·치료·평가·원인 낱말은 영어든 한국어든 버린다")
  void diagnosisJudgementAndCause_areRejected() {
    for (String line : List.of(
      "자폐 때문에 일과 4개를 마쳤어요.", "치료 효과로 일과 4개를 마쳤어요.", "정말 잘했어요, 일과 4개를 마쳤어요.",
      "You should finish 4 routines.", "Great job on 4 routines.", "Elumi improved to 4 routines.")) {
      assertThat(WeeklyReportSummaryValidator.validate(List.of(line), NUMBERS).isAccepted()).as(line).isFalse();
    }
  }

  @Test
  @DisplayName("입력에 없는 숫자가 나오면 버린다 — 지어낸 횟수가 사실로 보이지 않게")
  void numberNotInInput_isRejected() {
    WeeklyReportSummaryValidator.Result result = WeeklyReportSummaryValidator.validate(
      List.of("{userName}는 일과 7개를 마쳤어요."), NUMBERS);

    assertThat(result.isAccepted()).isFalse();
    assertThat(result.rejectionReason()).isEqualTo("number not in input");
  }

  @Test
  @DisplayName("줄이 없거나 4줄 이상이면 버린다")
  void lineCount_mustBeOneToThree() {
    assertThat(WeeklyReportSummaryValidator.validate(List.of(), NUMBERS).isAccepted()).isFalse();
    assertThat(WeeklyReportSummaryValidator.validate(List.of("a", "b", "c", "d"), NUMBERS).isAccepted()).isFalse();
  }

  @Test
  @DisplayName("{userName} 말고 다른 중괄호 틀이 남아 있으면 버린다 — 틀 문자가 화면에 그대로 뜨지 않게")
  void unknownPlaceholder_isRejected() {
    assertThat(WeeklyReportSummaryValidator.validate(List.of("{childName}는 일과 4개를 마쳤어요."), NUMBERS).isAccepted())
      .isFalse();
  }

  @Test
  @DisplayName("입력 JSON 속 숫자(집계와 제목 속 숫자)가 허용 숫자가 된다")
  void numbersIn_collectsEveryNumberToken() {
    assertThat(WeeklyReportSummaryValidator.numbersIn("{\"sentRoutineCount\":5,\"title\":\"10분 운동\"}"))
      .containsExactlyInAnyOrder("5", "10");
  }
}
