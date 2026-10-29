package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.member.application.service.MemberAdminLookupService;
import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * 다른 도메인 관리자 목록의 회원 조건: 회원 id 필터 + 검색어(아이디·호칭) > 회원 id 목록, 회원 id > 표시 이름
 * 둘 다 있으면 교집합. 검색어에 맞는 회원이 너무 많으면 앞 N명만 쓰고 잘렸다고 알린다
 */
@Component
@RequiredArgsConstructor
public class AdminMemberFilter {

  /// 검색어로 찾은 회원 id 를 IN 조건에 넣는 최대 수
  static final int MAX_KEYWORD_MEMBER_COUNT = 500;

  private final MemberAdminLookupService memberAdminLookupService;

  /**
   * 회원 조건 결과
   *
   * @param memberIds   null 이면 회원 조건 없음, 비어 있으면 맞는 회원 없음
   * @param isTruncated 검색어에 맞는 회원이 많아 앞 N명만 썼는지
   */
  public record Resolved(Collection<String> memberIds, boolean isTruncated) {

    public static Resolved none() {
      return new Resolved(null, false);
    }
  }

  /// 회원 id 필터·검색어 > 회원 조건
  public Resolved resolve(String memberId, String keyword) {
    boolean hasMemberId = memberId != null && !memberId.isBlank();
    boolean hasKeyword = keyword != null && !keyword.isBlank();
    if (!hasKeyword) {
      return hasMemberId ? new Resolved(List.of(memberId.strip()), false) : Resolved.none();
    }
    Set<String> keywordMemberIds = new LinkedHashSet<>(memberAdminLookupService.findMemberIdsByKeyword(keyword, MAX_KEYWORD_MEMBER_COUNT + 1));
    if (hasMemberId) {
      return new Resolved(keywordMemberIds.contains(memberId.strip()) ? List.of(memberId.strip()) : List.of(), false);
    }
    boolean isTruncated = keywordMemberIds.size() > MAX_KEYWORD_MEMBER_COUNT;
    List<String> limited = new ArrayList<>(keywordMemberIds).subList(0,
      Math.min(keywordMemberIds.size(), MAX_KEYWORD_MEMBER_COUNT));
    return new Resolved(List.copyOf(limited), isTruncated);
  }

  /// 회원 id > 표시 이름 (닉네임, 없으면 아이디). 없는 회원은 빠짐
  public Map<String, String> displayNamesOf(Collection<String> memberIds) {
    return memberAdminLookupService.displayNamesOf(memberIds);
  }
}
