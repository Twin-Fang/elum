package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import com.chuseok22.elumserver.notification.core.NotificationDispatchSource;
import com.chuseok22.elumserver.notification.core.NotificationQuietHours;
import com.chuseok22.elumserver.notification.core.NotificationTime;
import com.chuseok22.elumserver.notification.infrastructure.entity.AutoNotificationRule;
import com.chuseok22.elumserver.notification.infrastructure.entity.NotificationSetting;
import com.chuseok22.elumserver.notification.infrastructure.repository.AutoNotificationRuleRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationDispatchRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationSettingRepository;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * 자동 알림 한 번 실행 (#1275): 야간이면 멈춤 > 켜진 규칙을 차례대로 > 시각·오늘 선점 > 받을 사람 > 거르기 > 받는 사람 언어로 문구 > 보내기
 * 거르기 4개: 알림 끔(전체·종류), 같은 종류 최소 간격(첫 일과는 평생 한 번), 하루 1개(자동 알림 전체, 운영자 발송 제외)
 */
@Slf4j
@Service
public class AutoNotificationRunner {

  // 한 번에 묻는 회원 id 수 (in 절 길이 제한)
  private static final int MEMBER_ID_CHUNK_SIZE = 500;
  // 평생 한 번 판정의 시작 (이보다 이른 기록은 없음)
  private static final LocalDateTime BEGINNING_OF_RECORDS = LocalDateTime.of(2000, 1, 1, 0, 0);

  private final AutoNotificationRuleRepository autoNotificationRuleRepository;
  private final AutoNotificationCandidateFinder autoNotificationCandidateFinder;
  private final NotificationSettingRepository notificationSettingRepository;
  private final NotificationDispatchRepository notificationDispatchRepository;
  private final AdminMessageService adminMessageService;
  private final AutoNotificationCopyResolver autoNotificationCopyResolver;
  private final Clock clock;

  @Autowired
  public AutoNotificationRunner(AutoNotificationRuleRepository autoNotificationRuleRepository,
    AutoNotificationCandidateFinder autoNotificationCandidateFinder,
    NotificationSettingRepository notificationSettingRepository,
    NotificationDispatchRepository notificationDispatchRepository, AdminMessageService adminMessageService,
    AutoNotificationCopyResolver autoNotificationCopyResolver) {
    this(autoNotificationRuleRepository, autoNotificationCandidateFinder, notificationSettingRepository,
      notificationDispatchRepository, adminMessageService, autoNotificationCopyResolver,
      Clock.system(NotificationTime.ZONE_ID));
  }

  AutoNotificationRunner(AutoNotificationRuleRepository autoNotificationRuleRepository,
    AutoNotificationCandidateFinder autoNotificationCandidateFinder,
    NotificationSettingRepository notificationSettingRepository,
    NotificationDispatchRepository notificationDispatchRepository, AdminMessageService adminMessageService,
    AutoNotificationCopyResolver autoNotificationCopyResolver, Clock clock) {
    this.autoNotificationRuleRepository = autoNotificationRuleRepository;
    this.autoNotificationCandidateFinder = autoNotificationCandidateFinder;
    this.notificationSettingRepository = notificationSettingRepository;
    this.notificationDispatchRepository = notificationDispatchRepository;
    this.adminMessageService = adminMessageService;
    this.autoNotificationCopyResolver = autoNotificationCopyResolver;
    this.clock = clock;
  }

  /// 한 번 실행 > 보낸 사람 수 (야간이면 0, 규칙 하나의 실패는 다음 규칙을 막지 않음)
  public int runOnce() {
    LocalDateTime now = LocalDateTime.now(clock);
    if (NotificationQuietHours.isQuietTime(now)) {
      return 0;
    }
    List<AutoNotificationRule> rules = new ArrayList<>(autoNotificationRuleRepository.findAllEnabled());
    rules.sort(Comparator.comparing(AutoNotificationRule::getType));
    int sentMemberCount = 0;
    for (AutoNotificationRule rule : rules) {
      try {
        sentMemberCount += runRule(rule, now);
      } catch (RuntimeException exception) {
        log.warn("[auto notification] rule failed type={} : {}", rule.getType(), exception.getClass().getSimpleName());
        log.debug("[auto notification] failure detail", exception);
      }
    }
    return sentMemberCount;
  }

  // 시각 확인 > 오늘 선점 (정한 시각 종류만) > 받을 사람 > 거르기 > 사람마다 보내기
  private int runRule(AutoNotificationRule rule, LocalDateTime now) {
    AutoNotificationType type = rule.getType();
    if (type.isHasFixedSendTime()) {
      if (now.toLocalTime().isBefore(LocalTime.of(rule.getSendHour(), rule.getSendMinute()))) {
        return 0;
      }
      if (autoNotificationRuleRepository.claimTodayRun(type, now.toLocalDate()) != 1) {
        return 0;
      }
    }
    List<AutoNotificationCandidate> candidates = filterReceivable(rule, autoNotificationCandidateFinder.find(type, now), now);
    Map<String, AppLocale> localeByMemberId = autoNotificationCopyResolver.localesOf(
      candidates.stream().map(AutoNotificationCandidate::memberId).toList());
    int sentMemberCount = 0;
    for (AutoNotificationCandidate candidate : candidates) {
      try {
        sendTo(rule, candidate, localeByMemberId.getOrDefault(candidate.memberId(), AppLocale.KO));
        sentMemberCount++;
      } catch (RuntimeException exception) {
        log.warn("[auto notification] send failed type={} : {}", type, exception.getClass().getSimpleName());
      }
    }
    log.info("[auto notification] ran type={} : candidates={}, sent={}", type, candidates.size(), sentMemberCount);
    return sentMemberCount;
  }

  /// 거르기: 같은 사람 한 줄 > 알림 끔 > 최소 간격 > 오늘 이미 자동 알림 받음
  List<AutoNotificationCandidate> filterReceivable(AutoNotificationRule rule, List<AutoNotificationCandidate> candidates,
    LocalDateTime now) {
    Map<String, AutoNotificationCandidate> candidateByMemberId = new LinkedHashMap<>();
    candidates.forEach(candidate -> candidateByMemberId.putIfAbsent(candidate.memberId(), candidate));
    if (candidateByMemberId.isEmpty()) {
      return List.of();
    }
    List<String> memberIds = List.copyOf(candidateByMemberId.keySet());
    Set<String> blockedMemberIds = new HashSet<>();
    blockedMemberIds.addAll(optedOutMemberIds(rule.getType(), memberIds));
    blockedMemberIds.addAll(memberIdsWithin(memberIds,
      chunk -> notificationDispatchRepository.findMemberIdsWithAutoTypeSince(rule.getType(), chunk,
        intervalStartOf(rule, now))));
    blockedMemberIds.addAll(memberIdsWithin(memberIds,
      chunk -> notificationDispatchRepository.findMemberIdsWithSourceSince(NotificationDispatchSource.AUTO_RULE, chunk,
        now.toLocalDate().atStartOfDay())));
    return candidateByMemberId.values().stream()
      .filter(candidate -> !blockedMemberIds.contains(candidate.memberId()))
      .toList();
  }

  /// 최소 간격 시작: 오늘 포함 간격 일수 (1이면 오늘만), 첫 일과 축하는 평생
  static LocalDateTime intervalStartOf(AutoNotificationRule rule, LocalDateTime now) {
    if (rule.getType() == AutoNotificationType.FIRST_ROUTINE_DONE) {
      return BEGINNING_OF_RECORDS;
    }
    int intervalDays = Math.max(rule.getMinIntervalDays(), 1);
    return now.toLocalDate().atStartOfDay().minusDays(intervalDays - 1L);
  }

  // 설정 행이 있고 전체 끔이거나 그 종류 칸이 꺼진 회원 (행 없으면 모두 켜짐)
  private Set<String> optedOutMemberIds(AutoNotificationType type, List<String> memberIds) {
    Set<String> optedOut = new HashSet<>();
    for (List<String> chunk : chunksOf(memberIds)) {
      for (NotificationSetting setting : notificationSettingRepository.findAllById(chunk)) {
        if (!AutoNotificationOptOut.isReceiving(setting, type)) {
          optedOut.add(setting.getMemberId());
        }
      }
    }
    return optedOut;
  }

  private Set<String> memberIdsWithin(List<String> memberIds,
    Function<List<String>, List<String>> queryByChunk) {
    Set<String> found = new HashSet<>();
    for (List<String> chunk : chunksOf(memberIds)) {
      found.addAll(queryByChunk.apply(chunk));
    }
    return found;
  }

  // 받는 사람 언어 문구 > 운영자 알림으로 한 사람에게 (알림함 제목·본문이 사람마다 다름)
  private void sendTo(AutoNotificationRule rule, AutoNotificationCandidate candidate, AppLocale locale) {
    AutoNotificationCopyResolver.RenderedCopy copy = autoNotificationCopyResolver.render(rule, candidate, locale);
    adminMessageService.send(copy.title(), copy.body(), rule.getRoute(), List.of(candidate.memberId()),
      AdminMessageOrigin.autoRule(rule.getType()));
  }

  private static List<List<String>> chunksOf(List<String> memberIds) {
    List<List<String>> chunks = new ArrayList<>();
    for (int start = 0; start < memberIds.size(); start += MEMBER_ID_CHUNK_SIZE) {
      chunks.add(memberIds.subList(start, Math.min(start + MEMBER_ID_CHUNK_SIZE, memberIds.size())));
    }
    return chunks;
  }
}
