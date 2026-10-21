package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.common.application.exception.JsonErrorResponse;
import com.chuseok22.elumserver.member.application.dto.response.MemberPickerItem;
import com.chuseok22.elumserver.member.application.service.MemberPickerService;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigValueValidator;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 설정 화면 회원 고르기 JSON: 회원 검색(최대 10명), 저장된 회원 ID > 회원 정보(칩 이름·없는 ID 표시)
 * AdminConfigController(화면)와 분리: @JsonErrorResponse 가 클래스 단위라 섞으면 화면 오류도 JSON 이 됨
 * @LogMonitoring 없음: 입력할 때마다 불려 로그만 채움 (AdminStatsApiController 와 같음)
 */
@RestController
@JsonErrorResponse
@RequiredArgsConstructor
public class AdminConfigMemberApiController {

  // 한 번에 조회하는 회원 ID 최대 개수 (설정값 500자 안에 UUID 약 13개)
  private static final int MAXIMUM_LOOKUP_ID_COUNT = 50;

  private final MemberPickerService memberPickerService;

  /// 검색어(회원 id, 아이디·보호자 닉네임 일부) > 최근 가입순 최대 10명. 2글자 미만이면 빈 목록
  @GetMapping("/admin/settings/api/members")
  public List<MemberPickerItem> searchMembers(@RequestParam(name = "keyword", required = false) String keyword) {
    return memberPickerService.search(keyword);
  }

  /// 쉼표 목록 회원 ID > 있는 회원 (형식이 틀린 항목·없는 회원은 빠짐 > 화면이 "없는 회원"으로 표시)
  @GetMapping("/admin/settings/api/members/by-ids")
  public List<MemberPickerItem> membersByIds(@RequestParam(name = "ids", required = false) String ids) {
    List<String> memberIds = SystemConfigValueValidator.splitListItems(ids).stream()
      .filter(SystemConfigValueValidator::isMemberIdFormat)
      .limit(MAXIMUM_LOOKUP_ID_COUNT)
      .toList();
    return memberPickerService.findExisting(memberIds);
  }
}
