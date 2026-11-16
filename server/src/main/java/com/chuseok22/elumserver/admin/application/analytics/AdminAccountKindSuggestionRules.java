package com.chuseok22.elumserver.admin.application.analytics;

import com.chuseok22.elumserver.admin.application.dto.response.AdminAccountKindSuggestion;
import com.chuseok22.elumserver.admin.application.format.AdminMemberDisplayNames;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.SuggestionCandidate;
import com.chuseok22.elumserver.member.core.MemberAccountKind;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

/**
 * 계정 종류 분류 제안 규칙 2개 (#1436, 상수 한곳): 내부 의심(메모 낱말), 스토어 심사 의심(Apple 가리기·일과 0·방문 1일 이하·가입 7일 지남)
 * 둘 다 맞으면 내부 의심 먼저 (관리자가 직접 남긴 근거)
 */
public final class AdminAccountKindSuggestionRules {

  /// 내부 의심: 관리자 메모 낱말 2개
  static final List<String> INTERNAL_MEMO_KEYWORDS = List.of("내부", "테스트");
  /// 스토어 심사 의심: Apple 이메일 가리기 주소 끝 (소문자 비교)
  static final String APPLE_PRIVATE_RELAY_EMAIL_SUFFIX = "@privaterelay.appleid.com";
  /// 스토어 심사 의심: 가입 뒤 지나야 하는 일수 (7일), 방문한 날 상한 (1일), 사용자 일과 상한 (0개)
  static final int STORE_REVIEW_MINIMUM_DAYS_SINCE_JOIN = 7;
  static final int STORE_REVIEW_MAXIMUM_VISIT_DAYS = 1;
  static final int STORE_REVIEW_MAXIMUM_USER_ROUTINES = 0;

  private AdminAccountKindSuggestionRules() {
  }

  /** 쿼리 like 패턴: 이메일 가리기 주소 (소문자) */
  public static String privateRelayEmailLikePattern() {
    return "%" + APPLE_PRIVATE_RELAY_EMAIL_SUFFIX;
  }

  /** 후보 1명 > 제안 (규칙에 안 맞으면 빈 값) */
  public static Optional<AdminAccountKindSuggestion> suggest(SuggestionCandidate candidate, LocalDateTime now) {
    if (hasInternalMemoKeyword(candidate.adminMemo())) {
      return Optional.of(toSuggestion(candidate, MemberAccountKind.INTERNAL,
        "관리자 메모에 " + String.join("·", INTERNAL_MEMO_KEYWORDS) + " 낱말"));
    }
    if (isStoreReviewLike(candidate, now)) {
      return Optional.of(toSuggestion(candidate, MemberAccountKind.STORE_REVIEW,
        "Apple 이메일 가리기 · 일과 0개 · 방문 " + candidate.visitDayCount() + "일 · 가입 7일 지남"));
    }
    return Optional.empty();
  }

  static boolean hasInternalMemoKeyword(String adminMemo) {
    return adminMemo != null && INTERNAL_MEMO_KEYWORDS.stream().anyMatch(adminMemo::contains);
  }

  static boolean isStoreReviewLike(SuggestionCandidate candidate, LocalDateTime now) {
    return candidate.hasAppleLogin()
      && candidate.hasPrivateRelayEmail()
      && candidate.userRoutineCount() <= STORE_REVIEW_MAXIMUM_USER_ROUTINES
      && candidate.visitDayCount() <= STORE_REVIEW_MAXIMUM_VISIT_DAYS
      && candidate.createdAt() != null
      && candidate.createdAt().isBefore(now.minusDays(STORE_REVIEW_MINIMUM_DAYS_SINCE_JOIN));
  }

  private static AdminAccountKindSuggestion toSuggestion(
    SuggestionCandidate candidate, MemberAccountKind suggestedKind, String reason
  ) {
    return new AdminAccountKindSuggestion(candidate.memberId(),
      AdminMemberDisplayNames.of(candidate.nickname(), candidate.memberId()), candidate.createdAt(), suggestedKind, reason);
  }
}
