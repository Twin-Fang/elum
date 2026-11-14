package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.notification.core.NotificationTime;
import com.chuseok22.elumserver.routine.core.ElumiStreak;
import com.chuseok22.elumserver.routine.core.ElumiStreakCalculator;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository.ProfileCompletionRow;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 이룸이 연속 기록 (#1409): 한 이룸이의 기록(보호자·이룸이 홈), 오늘 끊길 수 있는 이룸이 찾기(자동 알림)
 * 마친 날 = 일과 완료 시각의 한국 날짜, 요금제와 무관 (Free 포함)
 */
@Service
@Transactional(readOnly = true)
public class ElumiStreakService {

  // 거슬러 보는 최대 일수 (기록은 이 일수에서 멈춤)
  static final int STREAK_LOOKBACK_DAYS = 366;
  // 한 번에 묻는 이룸이 id 수 (in 절 길이 제한)
  private static final int PROFILE_ID_CHUNK_SIZE = 500;

  private final RoutineRepository routineRepository;
  private final Clock clock;

  @Autowired
  public ElumiStreakService(RoutineRepository routineRepository) {
    this(routineRepository, Clock.system(NotificationTime.ZONE_ID));
  }

  ElumiStreakService(RoutineRepository routineRepository, Clock clock) {
    this.routineRepository = routineRepository;
    this.clock = clock;
  }

  /// 오늘 끊길 수 있는 이룸이 한 명: 이룸이 id, 어제까지 이어진 일수
  public record ProfileStreak(String profileId, int streakDays) {
  }

  /// 이룸이 한 명의 지금 기록 (이룸이가 없으면 기록 없음)
  public ElumiStreak streakOf(String profileId) {
    if (profileId == null) {
      return ElumiStreak.NONE;
    }
    LocalDate today = LocalDate.now(clock);
    List<LocalDate> completionDates = routineRepository.findCompletedAtsByProfileSince(profileId,
        RoutineStatus.COMPLETED, lookbackStartOf(today)).stream()
      .map(LocalDateTime::toLocalDate)
      .toList();
    return ElumiStreakCalculator.calculate(completionDates, today);
  }

  /// 어제 마친 이룸이 > 기록 계산 > 오늘 아직 안 마쳤고 minimumStreakDays 일 이상 이어진 이룸이
  public List<ProfileStreak> findProfilesAtRiskToday(LocalDate today, int minimumStreakDays) {
    LocalDateTime todayStart = today.atStartOfDay();
    List<String> profileIds = routineRepository.findProfileIdsCompletedBetween(RoutineStatus.COMPLETED,
      todayStart.minusDays(1), todayStart);
    Map<String, Set<LocalDate>> completionDatesByProfileId = completionDatesOf(profileIds, lookbackStartOf(today));
    List<ProfileStreak> atRisk = new ArrayList<>();
    for (String profileId : profileIds) {
      ElumiStreak streak = ElumiStreakCalculator.calculate(
        completionDatesByProfileId.getOrDefault(profileId, Set.of()), today);
      if (streak.isStreakAtRiskToday() && streak.currentStreakDays() >= minimumStreakDays) {
        atRisk.add(new ProfileStreak(profileId, streak.currentStreakDays()));
      }
    }
    return atRisk;
  }

  private Map<String, Set<LocalDate>> completionDatesOf(List<String> profileIds, LocalDateTime since) {
    Map<String, Set<LocalDate>> datesByProfileId = new HashMap<>();
    for (int from = 0; from < profileIds.size(); from += PROFILE_ID_CHUNK_SIZE) {
      List<String> chunk = profileIds.subList(from, Math.min(from + PROFILE_ID_CHUNK_SIZE, profileIds.size()));
      for (ProfileCompletionRow row : routineRepository.findCompletedAtsByProfilesSince(chunk,
        RoutineStatus.COMPLETED, since)) {
        datesByProfileId.computeIfAbsent(row.getProfileId(), ignored -> new HashSet<>())
          .add(row.getCompletedAt().toLocalDate());
      }
    }
    return datesByProfileId;
  }

  private static LocalDateTime lookbackStartOf(LocalDate today) {
    return today.minusDays(STREAK_LOOKBACK_DAYS).atStartOfDay();
  }
}
