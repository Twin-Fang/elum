package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.feedback.core.FeedbackAppReport;

/**
 * 관리자 회원 상세의 접속 정보: 로그인 방식, 마지막으로 알려진 앱 버전·OS (#656)
 * 앱 버전·OS 는 따로 저장하지 않음 > 가장 최근 의견에 실린 값 (의견이 없으면 null)
 *
 * @param loginMethodText 소셜 제공자 이름 목록 ("카카오, 애플"), 소셜 신원이 없으면 아이디 로그인
 * @param lastAppReport   가장 최근 의견의 앱 버전·OS·보낸 시각. 의견이 없으면 null
 * @param isLoadFailed    조회 실패 (화면은 오류 코드와 함께 이 영역만 비움)
 */
public record AdminMemberAccessInfo(
  String loginMethodText,
  FeedbackAppReport lastAppReport,
  boolean isLoadFailed
) {

  // 조회 실패 시 화면에 보이는 오류 코드
  public static final String LOAD_FAILED_ERROR_CODE = "E-ADM-MEMBER-001";

  public static AdminMemberAccessInfo failed() {
    return new AdminMemberAccessInfo(null, null, true);
  }

  public String loadFailedErrorCode() {
    return LOAD_FAILED_ERROR_CODE;
  }
}
