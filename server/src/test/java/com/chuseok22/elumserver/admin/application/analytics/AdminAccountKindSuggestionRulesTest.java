package com.chuseok22.elumserver.admin.application.analytics;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.response.AdminAccountKindSuggestion;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.SuggestionCandidate;
import com.chuseok22.elumserver.member.core.MemberAccountKind;
import java.time.LocalDateTime;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 분류 제안 규칙 (#1436): 실제 사용자가 제안에 잘못 뜨거나(숫자에서 빠질 위험) 심사 계정이 안 뜨는 결함을 잡음
 */
class AdminAccountKindSuggestionRulesTest {

  private static final LocalDateTime NOW = LocalDateTime.of(2026, 11, 16, 12, 0);
  private static final LocalDateTime JOINED_TEN_DAYS_AGO = NOW.minusDays(10);

  @Test
  @DisplayName("스토어 심사 의심: Apple + 이메일 가리기 + 일과 0개 + 방문 1일 이하 + 가입 7일 지남이면 제안한다")
  void suggestsStoreReviewWhenAllConditionsMatch() {
    Optional<AdminAccountKindSuggestion> suggestion = AdminAccountKindSuggestionRules.suggest(
      candidate(null, true, true, 0, 1, JOINED_TEN_DAYS_AGO), NOW);

    assertThat(suggestion).map(AdminAccountKindSuggestion::suggestedKind).contains(MemberAccountKind.STORE_REVIEW);
  }

  @Test
  @DisplayName("스토어 심사 의심은 조건 하나만 어긋나도 제안하지 않는다 (실제 사용자 보호)")
  void doesNotSuggestStoreReviewWhenAnyConditionFails() {
    assertThat(AdminAccountKindSuggestionRules.suggest(candidate(null, true, false, 0, 1, JOINED_TEN_DAYS_AGO), NOW))
      .as("이메일을 가리지 않음").isEmpty();
    assertThat(AdminAccountKindSuggestionRules.suggest(candidate(null, true, true, 1, 1, JOINED_TEN_DAYS_AGO), NOW))
      .as("직접 만든 일과 있음").isEmpty();
    assertThat(AdminAccountKindSuggestionRules.suggest(candidate(null, true, true, 0, 2, JOINED_TEN_DAYS_AGO), NOW))
      .as("이틀 이상 방문").isEmpty();
    assertThat(AdminAccountKindSuggestionRules.suggest(candidate(null, true, true, 0, 0, NOW.minusDays(6)), NOW))
      .as("가입 7일 안 지남").isEmpty();
    assertThat(AdminAccountKindSuggestionRules.suggest(candidate(null, false, true, 0, 0, JOINED_TEN_DAYS_AGO), NOW))
      .as("Apple 로그인 아님").isEmpty();
  }

  @Test
  @DisplayName("내부 의심: 관리자 메모에 내부·테스트가 있으면 다른 조건과 상관없이 내부로 제안한다")
  void suggestsInternalFromAdminMemo() {
    assertThat(AdminAccountKindSuggestionRules.suggest(candidate("운영팀 테스트 폰", false, false, 5, 30, JOINED_TEN_DAYS_AGO), NOW))
      .map(AdminAccountKindSuggestion::suggestedKind).contains(MemberAccountKind.INTERNAL);
    assertThat(AdminAccountKindSuggestionRules.suggest(candidate("내부", true, true, 0, 0, JOINED_TEN_DAYS_AGO), NOW))
      .as("심사 조건도 맞지만 메모 근거가 먼저").map(AdminAccountKindSuggestion::suggestedKind)
      .contains(MemberAccountKind.INTERNAL);
    assertThat(AdminAccountKindSuggestionRules.suggest(candidate("문의 답변함", false, false, 0, 0, JOINED_TEN_DAYS_AGO), NOW))
      .isEmpty();
  }

  private static SuggestionCandidate candidate(
    String adminMemo, boolean hasAppleLogin, boolean hasPrivateRelayEmail, long userRoutineCount, long visitDayCount,
    LocalDateTime createdAt
  ) {
    return new SuggestionCandidate("member-1", "보호자", createdAt, adminMemo, hasAppleLogin, hasPrivateRelayEmail,
      userRoutineCount, visitDayCount);
  }
}
