package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileGuardian;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 자동 알림(#1275)이 묻는 회원 사실 2개: 마지막 활동 기간으로 활성 회원 고르기, 보호자별 이룸이 이름
 * 마지막 활동 = Member.lastActivityAt (앱이 인증 요청을 보낼 때마다 60초 스로틀로 갱신, MemberAccessGuard)
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class MemberEngagementQueryService {

  // 한 번에 묻는 회원 id 수 (in 절 길이 제한)
  private static final int MEMBER_ID_CHUNK_SIZE = 500;

  private final MemberRepository memberRepository;
  private final ProfileGuardianRepository profileGuardianRepository;

  /// 마지막 활동이 [from, to) 인 활성 회원 id
  public List<String> findActiveMemberIdsLastActiveBetween(LocalDateTime from, LocalDateTime to) {
    return memberRepository.findIdsByStatusAndLastActivityBetween(MemberStatus.ACTIVE, from, to);
  }

  /// 보호자 id > (이룸이 id > 이름), 먼저 합류한 차례 (이룸이가 없는 보호자는 빠짐)
  public Map<String, Map<String, String>> profileNamesByMemberId(Collection<String> memberIds) {
    List<String> distinctMemberIds = memberIds.stream().distinct().toList();
    Map<String, Map<String, String>> namesByMemberId = new HashMap<>();
    for (int from = 0; from < distinctMemberIds.size(); from += MEMBER_ID_CHUNK_SIZE) {
      List<String> chunk = new ArrayList<>(
        distinctMemberIds.subList(from, Math.min(from + MEMBER_ID_CHUNK_SIZE, distinctMemberIds.size())));
      for (ProfileGuardian guardianship : profileGuardianRepository.findAllWithProfileByMemberIdIn(chunk)) {
        namesByMemberId.computeIfAbsent(guardianship.getMember().getId(), ignored -> new LinkedHashMap<>())
          .put(guardianship.getProfile().getId(), guardianship.getProfile().getNickname());
      }
    }
    return namesByMemberId;
  }
}
