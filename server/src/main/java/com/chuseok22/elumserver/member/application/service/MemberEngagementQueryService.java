package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileGuardian;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberDailyVisitRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 자동 알림(#1275, #1409)이 묻는 회원 사실 4개: 마지막 활동 기간으로 활성 회원 고르기, 보호자별 이룸이 이름,
 * 온보딩 마친 가입일 기간 보호자, 알림 뒤 복귀 근거(마지막 활동·방문 날짜)
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
  private final MemberDailyVisitRepository memberDailyVisitRepository;

  /// 회원 한 명의 복귀 근거: 마지막 활동 시각(없으면 null), 방문 날짜들
  public record ReturnEvidence(LocalDateTime lastActivityAt, Set<LocalDate> visitDates) {
  }

  /// 온보딩을 마친(이룸이 이름 있음) 활성 보호자 중 [from, to) 에 가입한 사람
  public List<String> findActiveOnboardedMemberIdsJoinedBetween(LocalDateTime from, LocalDateTime to) {
    return profileGuardianRepository.findOnboardedMemberIdsJoinedBetween(MemberStatus.ACTIVE, from, to);
  }

  /// 회원 id > 복귀 근거 (방문은 visitSince 이후만, 없는 회원은 빈 근거)
  public Map<String, ReturnEvidence> returnEvidenceOf(Collection<String> memberIds, LocalDate visitSince) {
    List<String> distinctMemberIds = memberIds.stream().distinct().toList();
    Map<String, LocalDateTime> lastActivityByMemberId = new HashMap<>();
    Map<String, Set<LocalDate>> visitDatesByMemberId = new HashMap<>();
    for (int from = 0; from < distinctMemberIds.size(); from += MEMBER_ID_CHUNK_SIZE) {
      List<String> chunk = distinctMemberIds.subList(from, Math.min(from + MEMBER_ID_CHUNK_SIZE, distinctMemberIds.size()));
      memberRepository.findLastActivitiesByIdIn(chunk).stream()
        .filter(row -> row.getLastActivityAt() != null)
        .forEach(row -> lastActivityByMemberId.put(row.getId(), row.getLastActivityAt()));
      memberDailyVisitRepository.findVisitsSince(chunk, visitSince).forEach(row ->
        visitDatesByMemberId.computeIfAbsent(row.getMemberId(), ignored -> new HashSet<>()).add(row.getVisitDate()));
    }
    Map<String, ReturnEvidence> evidenceByMemberId = new HashMap<>();
    for (String memberId : distinctMemberIds) {
      evidenceByMemberId.put(memberId, new ReturnEvidence(lastActivityByMemberId.get(memberId),
        Set.copyOf(visitDatesByMemberId.getOrDefault(memberId, Set.of()))));
    }
    return evidenceByMemberId;
  }

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
