package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository.SentRoutineRow;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 자동 알림(#1275, #1409)이 묻는 일과 사실 6개: 어제 보냈는데 오늘 안 보낸 보호자, 이룸이 첫 완료, 보호자별 최근 보낸 일과,
 * 오늘 보냈는데 진행 없음, 일과를 만든 적 있는 보호자, 처음 보낸 일과
 * 보낸 일과 = 확정·완료 (임시저장·예시·일과관리 복사본 제외), 날짜는 한국 시각 기준 예정 시각
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RoutineEngagementQueryService {

  // 보낸 일과로 보는 상태 (임시저장 제외)
  private static final List<RoutineStatus> SENT_STATUSES = List.of(RoutineStatus.CONFIRMED, RoutineStatus.COMPLETED);
  // 한 번에 묻는 회원 id 수 (in 절 길이 제한)
  private static final int MEMBER_ID_CHUNK_SIZE = 500;

  private final RoutineRepository routineRepository;

  /// 보호자 한 명의 보낸 일과 한 줄: 보낸 보호자, 이룸이, 일과 제목
  public record SentRoutineSummary(String memberId, String profileId, String routineTitle) {
  }

  /// 어제 보냈는데 오늘 아직 안 보낸 보호자 > 어제 마지막 일과 (반복 일과 보호자 제외, 보호자당 한 줄)
  public List<SentRoutineSummary> findMembersSentYesterdayNotToday(LocalDate today) {
    LocalDateTime todayStart = today.atStartOfDay();
    List<SentRoutineRow> rows = routineRepository.findSentYesterdayNotToday(SENT_STATUSES,
      todayStart.minusDays(1), todayStart, todayStart.plusDays(1));
    return firstPerMember(rows);
  }

  /// since 이후 이룸이가 처음으로 끝낸 일과 > 그 일과를 만든 보호자 (보호자당 한 줄)
  public List<SentRoutineSummary> findFirstCompletionsSince(LocalDateTime since) {
    return firstPerMember(routineRepository.findFirstCompletionsSince(RoutineStatus.COMPLETED, since));
  }

  /// 보호자별 since 이후 가장 최근에 보낸 일과 (없는 보호자는 빠짐)
  public Map<String, SentRoutineSummary> findLatestSentByMembers(Collection<String> memberIds, LocalDateTime since) {
    List<String> distinctMemberIds = memberIds.stream().distinct().toList();
    List<SentRoutineRow> rows = new ArrayList<>();
    for (int from = 0; from < distinctMemberIds.size(); from += MEMBER_ID_CHUNK_SIZE) {
      List<String> chunk = distinctMemberIds.subList(from, Math.min(from + MEMBER_ID_CHUNK_SIZE, distinctMemberIds.size()));
      rows.addAll(routineRepository.findRecentSentByMembers(chunk, SENT_STATUSES, since));
    }
    // 청크를 이어 붙여 순서가 섞이므로 예정 시각 최신순으로 다시 정렬
    rows.sort((left, right) -> right.getScheduledAt().compareTo(left.getScheduledAt()));
    Map<String, SentRoutineSummary> latestByMemberId = new LinkedHashMap<>();
    for (SentRoutineSummary summary : firstPerMember(rows)) {
      latestByMemberId.put(summary.memberId(), summary);
    }
    return latestByMemberId;
  }

  /// 오늘 보낸 일과를 이룸이가 아직 하나도 안 마친 보호자 > 오늘 마지막 일과 (보호자당 한 줄)
  public List<SentRoutineSummary> findMembersSentTodayWithoutProgress(LocalDate today) {
    LocalDateTime todayStart = today.atStartOfDay();
    return firstPerMember(routineRepository.findSentTodayWithoutProgress(RoutineStatus.CONFIRMED, todayStart,
      todayStart.plusDays(1)));
  }

  /// 이 보호자들 중 일과를 하나라도 만든 사람 (예시 제외, 임시저장 포함)
  public Set<String> findCreatorIdsAmong(Collection<String> memberIds) {
    List<String> distinctMemberIds = memberIds.stream().distinct().toList();
    Set<String> creatorIds = new HashSet<>();
    for (int from = 0; from < distinctMemberIds.size(); from += MEMBER_ID_CHUNK_SIZE) {
      creatorIds.addAll(routineRepository.findCreatorIdsAmong(
        distinctMemberIds.subList(from, Math.min(from + MEMBER_ID_CHUNK_SIZE, distinctMemberIds.size()))));
    }
    return creatorIds;
  }

  /// 처음 보낸 일과가 [from, to) 에 만들어진 보호자 > 그 첫 일과 (그 이룸이에 마친 일과가 있으면 제외, 보호자당 한 줄)
  public List<SentRoutineSummary> findMembersFirstSentBetween(LocalDateTime from, LocalDateTime to) {
    return firstPerMember(routineRepository.findFirstSentBetween(SENT_STATUSES, RoutineStatus.COMPLETED, from, to));
  }

  // 줄 순서를 지키며 보호자마다 첫 줄만
  private static List<SentRoutineSummary> firstPerMember(List<SentRoutineRow> rows) {
    Map<String, SentRoutineSummary> firstByMemberId = new LinkedHashMap<>();
    for (SentRoutineRow row : rows) {
      firstByMemberId.putIfAbsent(row.getMemberId(),
        new SentRoutineSummary(row.getMemberId(), row.getProfileId(), row.getTitle()));
    }
    return List.copyOf(firstByMemberId.values());
  }
}
