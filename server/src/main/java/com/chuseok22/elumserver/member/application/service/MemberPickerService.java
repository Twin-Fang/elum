package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.member.application.dto.response.MemberPickerItem;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.util.Collection;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 관리자 설정 회원 고르기 (읽기 전용): 검색어 > 회원 최대 10명, 회원 id 목록 > 있는 회원
 * 광고 항상 노출 회원(ADS_ALWAYS_SHOWN_MEMBER_IDS)처럼 회원 ID 를 설정값으로 저장할 때 씀
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class MemberPickerService {

  // 검색 결과 최대 건수 (고르기 목록이라 많을 필요 없음)
  static final int MAXIMUM_SEARCH_RESULT_COUNT = 10;
  // 검색어 최소 글자 수 (1글자는 거의 모든 회원이 걸림)
  static final int MINIMUM_KEYWORD_LENGTH = 2;
  // 검색어 최대 글자 수 (긴 입력으로 like 를 무겁게 만들지 않게)
  static final int MAXIMUM_KEYWORD_LENGTH = 100;
  private static final char LIKE_ESCAPE = '\\';

  private final MemberRepository memberRepository;

  /// 검색어(회원 id 그대로, 아이디·보호자 닉네임 일부) > 최근 가입순 최대 10명. 짧거나 비면 빈 목록
  public List<MemberPickerItem> search(String keyword) {
    String trimmed = keyword == null ? "" : keyword.strip();
    if (trimmed.length() < MINIMUM_KEYWORD_LENGTH) {
      return List.of();
    }
    if (trimmed.length() > MAXIMUM_KEYWORD_LENGTH) {
      trimmed = trimmed.substring(0, MAXIMUM_KEYWORD_LENGTH);
    }
    return memberRepository.findForAdminPicker(
        trimmed, "%" + escapeLike(trimmed) + "%", PageRequest.of(0, MAXIMUM_SEARCH_RESULT_COUNT))
      .stream()
      .map(MemberPickerService::toPickerItem)
      .toList();
  }

  /// 회원 id 목록 > 있는 회원 (없는 id 는 빠짐, 탈퇴 보관 중인 회원은 포함)
  public List<MemberPickerItem> findExisting(Collection<String> memberIds) {
    if (memberIds == null || memberIds.isEmpty()) {
      return List.of();
    }
    return memberRepository.findAllById(memberIds).stream()
      .map(MemberPickerService::toPickerItem)
      .toList();
  }

  private static MemberPickerItem toPickerItem(Member member) {
    return new MemberPickerItem(
      member.getId(), member.getUsername(), member.getNickname(),
      member.getStatus().name(), member.getStatus().getLabel());
  }

  /// like 검색어의 와일드카드(%, _)와 이스케이프 문자 자체를 글자로 취급
  static String escapeLike(String keyword) {
    StringBuilder escaped = new StringBuilder(keyword.length());
    for (char character : keyword.toCharArray()) {
      if (character == '%' || character == '_' || character == LIKE_ESCAPE) {
        escaped.append(LIKE_ESCAPE);
      }
      escaped.append(character);
    }
    return escaped.toString();
  }
}
