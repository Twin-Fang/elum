package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberAccessInfo;
import com.chuseok22.elumserver.admin.application.list.AdminMemberList;
import com.chuseok22.elumserver.auth.application.service.AuthIdentityQueryService;
import com.chuseok22.elumserver.auth.infrastructure.oauth.OAuthProvider;
import com.chuseok22.elumserver.feedback.application.service.FeedbackService;
import java.util.List;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * 관리자 회원 상세 접속 정보 조회: 로그인 제공자 1회 + 최근 의견 1회 (#656)
 */
@Service
@RequiredArgsConstructor
public class AdminMemberAccessService {

  /// 소셜 신원이 없는 계정 = 아이디·비밀번호 가입
  private static final String USERNAME_LOGIN_TEXT = "아이디";
  private static final String PROVIDER_DELIMITER = ", ";

  private final AuthIdentityQueryService authIdentityQueryService;
  private final FeedbackService feedbackService;

  /// 회원 id > 로그인 방식 + 마지막으로 알려진 앱 버전·OS
  public AdminMemberAccessInfo getAccessInfo(String memberId) {
    List<OAuthProvider> providers =
      authIdentityQueryService.providersByMemberIds(List.of(memberId)).getOrDefault(memberId, List.of());
    return new AdminMemberAccessInfo(
      loginMethodTextOf(providers),
      feedbackService.findLatestAppReport(memberId).orElse(null),
      false);
  }

  private static String loginMethodTextOf(List<OAuthProvider> providers) {
    if (providers.isEmpty()) {
      return USERNAME_LOGIN_TEXT;
    }
    return providers.stream().map(AdminMemberList::providerLabel).collect(Collectors.joining(PROVIDER_DELIMITER));
  }
}
