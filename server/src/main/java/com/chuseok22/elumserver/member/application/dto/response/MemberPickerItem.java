package com.chuseok22.elumserver.member.application.dto.response;

/**
 * 관리자 회원 고르기 한 줄: id, 아이디, 보호자 닉네임(없으면 null), 상태 표시 이름(활성·정지·탈퇴)
 */
public record MemberPickerItem(
  String id,
  String username,
  String nickname,
  String status,
  String statusLabel
) {

}
