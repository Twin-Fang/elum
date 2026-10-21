package com.chuseok22.elumserver.admin.application.dto.response;

import java.util.List;

/**
 * 관리자 회원 상세의 연결 정보: 이룸이 카드 전부(먼저 합류한 차례), 푸시 기기
 *
 * @param isLoadFailed 조회 실패 (화면은 오류 코드와 함께 이 영역만 비움)
 */
public record AdminMemberConnections(
  List<AdminMemberProfileCard> profiles,
  List<AdminPushDeviceLine> pushDevices,
  boolean isLoadFailed
) {

  // 조회 실패 시 화면에 보이는 오류 코드
  public static final String LOAD_FAILED_ERROR_CODE = "E-ADM-CONN-001";

  public static AdminMemberConnections empty() {
    return new AdminMemberConnections(List.of(), List.of(), false);
  }

  public static AdminMemberConnections failed() {
    return new AdminMemberConnections(List.of(), List.of(), true);
  }

  public String loadFailedErrorCode() {
    return LOAD_FAILED_ERROR_CODE;
  }
}
