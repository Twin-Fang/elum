package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 관리자 화면용 회원 찾기: 검색어 > 회원 id 목록, 회원 id > 표시 이름 (읽기 전용)
 * 다른 도메인의 관리자 목록(광고 보상·알림)이 회원 조건과 이름을 붙일 때 쓴다
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class MemberAdminLookupService {

  private final MemberRepository memberRepository;

  /// 검색어 > 회원 id 최대 maximumCount 건 (회원 id 그대로, 아이디 일부, 이룸이 호칭 일부. %·_ 는 글자로 취급)
  public List<String> findMemberIdsByKeyword(String keyword, int maximumCount) {
    if (keyword == null || keyword.isBlank() || maximumCount <= 0) {
      return List.of();
    }
    String trimmed = keyword.strip();
    return memberRepository.findIdsByKeywordPattern(
      trimmed, "%" + MemberPickerService.escapeLike(trimmed) + "%", PageRequest.of(0, maximumCount));
  }

  /// 회원 id > 표시 이름 (닉네임, 없으면 아이디). 없는 회원(완전 삭제)은 빠짐
  public Map<String, String> displayNamesOf(Collection<String> memberIds) {
    if (memberIds == null || memberIds.isEmpty()) {
      return Map.of();
    }
    Map<String, String> displayNameById = new HashMap<>();
    for (Member member : memberRepository.findAllById(memberIds)) {
      displayNameById.put(member.getId(), displayNameOf(member));
    }
    return displayNameById;
  }

  /// 회원 id > 회원 (탈퇴 회원 포함, 완전 삭제됐으면 빈 값)
  public Optional<Member> findMember(String memberId) {
    if (memberId == null || memberId.isBlank()) {
      return Optional.empty();
    }
    return memberRepository.findById(memberId);
  }

  /// 회원 > 표시 이름 (보호자 닉네임, 없으면 아이디)
  public static String displayNameOf(Member member) {
    String nickname = member.getNickname();
    return nickname != null && !nickname.isBlank() ? nickname : member.getUsername();
  }
}
