package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.notification.core.AdminMessageRoute;
import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import com.chuseok22.elumserver.notification.core.NotificationQuietHours;
import com.chuseok22.elumserver.notification.infrastructure.entity.AdminMessage;
import com.chuseok22.elumserver.notification.infrastructure.entity.AutoNotificationRule;
import com.chuseok22.elumserver.notification.infrastructure.repository.AutoNotificationRuleRepository;
import java.time.LocalTime;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 자동 알림 규칙 관리 (#1275): 목록(보내는 차례), 저장(검사 > 덮어쓰기)
 * 검사 5개: 제목·본문 길이, 모르는 변수, 갈 화면, 보내는 시각(야간 21~08시 금지, 시각 없는 종류는 안 봄), 간격 1~90일
 */
@Service
@RequiredArgsConstructor
public class AutoNotificationRuleService {

  // 같은 사람 최소 간격 허용 범위 (일)
  public static final int MINIMUM_INTERVAL_DAYS = 1;
  public static final int MAXIMUM_INTERVAL_DAYS = 90;
  // 문구 안의 {...} 변수
  private static final Pattern TEMPLATE_VARIABLE = Pattern.compile("\\{[^{}]*}");

  private final AutoNotificationRuleRepository autoNotificationRuleRepository;

  /// 저장 요청: 켜짐, 제목·본문 틀, 갈 화면 wire, 보내는 시·분(KST), 최소 간격(일)
  public record RuleUpdate(boolean isEnabled, String titleTemplate, String bodyTemplate, String routeWire,
    Integer sendHour, Integer sendMinute, Integer minIntervalDays) {
  }

  /// 저장 결과: 저장했으면 바뀐 내용 요약(관리자 기록용), 거절이면 사유 문구
  public record RuleUpdateResult(boolean isSaved, String rejectionMessage, String changeSummary) {

    static RuleUpdateResult rejected(String rejectionMessage) {
      return new RuleUpdateResult(false, rejectionMessage, null);
    }
  }

  /// 규칙 전부, 보내는 차례(종류 순서)
  @Transactional(readOnly = true)
  public List<AutoNotificationRule> findAll() {
    return autoNotificationRuleRepository.findAll().stream()
      .sorted(Comparator.comparing(AutoNotificationRule::getType))
      .toList();
  }

  /// 저장: 검사 > 덮어쓰기 (오늘 실행 기록은 그대로: 같은 날 시각을 늦춰도 다시 보내지 않음)
  @Transactional
  public RuleUpdateResult update(AutoNotificationType type, RuleUpdate update, String adminUsername) {
    Optional<AutoNotificationRule> found = autoNotificationRuleRepository.findById(type);
    if (found.isEmpty()) {
      return RuleUpdateResult.rejected("규칙을 찾지 못했어요. 새로고침해 주세요");
    }
    Optional<String> rejection = rejectionOf(type, update);
    if (rejection.isPresent()) {
      return RuleUpdateResult.rejected(rejection.get());
    }
    AutoNotificationRule rule = found.get();
    rule.setEnabled(update.isEnabled());
    rule.setTitleTemplate(update.titleTemplate().strip());
    rule.setBodyTemplate(update.bodyTemplate().strip());
    rule.setRoute(AdminMessageRoute.fromWire(update.routeWire()).orElseThrow());
    if (type.isHasFixedSendTime()) {
      rule.setSendHour(update.sendHour());
      rule.setSendMinute(update.sendMinute());
    }
    rule.setMinIntervalDays(update.minIntervalDays());
    rule.setUpdatedBy(adminUsername);
    return new RuleUpdateResult(true, null, changeSummaryOf(rule));
  }

  /// 검사 > 거절 사유 (통과면 빈 값)
  static Optional<String> rejectionOf(AutoNotificationType type, RuleUpdate update) {
    if (!isTextWithin(update.titleTemplate(), AdminMessage.TITLE_MAX_LENGTH)) {
      return Optional.of("제목은 1~" + AdminMessage.TITLE_MAX_LENGTH + "자로 써 주세요");
    }
    if (!isTextWithin(update.bodyTemplate(), AdminMessage.BODY_MAX_LENGTH)) {
      return Optional.of("본문은 1~" + AdminMessage.BODY_MAX_LENGTH + "자로 써 주세요");
    }
    Optional<String> unknownVariable = firstUnknownVariable(update.titleTemplate() + " " + update.bodyTemplate());
    if (unknownVariable.isPresent()) {
      return Optional.of("모르는 변수 " + unknownVariable.get() + " 가 있어요. "
        + String.join(" ", AutoNotificationTemplate.VARIABLES) + " 만 쓸 수 있어요");
    }
    if (AdminMessageRoute.fromWire(update.routeWire()).isEmpty()) {
      return Optional.of("누르면 갈 화면을 골라 주세요");
    }
    if (type.isHasFixedSendTime() && !isAllowedSendTime(update.sendHour(), update.sendMinute())) {
      return Optional.of("보내는 시각은 아침 8시부터 밤 9시 전까지만 고를 수 있어요");
    }
    Integer intervalDays = update.minIntervalDays();
    if (intervalDays == null || intervalDays < MINIMUM_INTERVAL_DAYS || intervalDays > MAXIMUM_INTERVAL_DAYS) {
      return Optional.of("최소 간격은 " + MINIMUM_INTERVAL_DAYS + "~" + MAXIMUM_INTERVAL_DAYS + "일로 정해 주세요");
    }
    return Optional.empty();
  }

  /// 보내는 시각: 0~23시·0~59분이고 야간(21~08시)이 아님
  static boolean isAllowedSendTime(Integer hour, Integer minute) {
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return false;
    }
    return !NotificationQuietHours.isQuietTime(LocalTime.of(hour, minute));
  }

  private static Optional<String> firstUnknownVariable(String text) {
    Matcher matcher = TEMPLATE_VARIABLE.matcher(text);
    while (matcher.find()) {
      if (!AutoNotificationTemplate.VARIABLES.contains(matcher.group())) {
        return Optional.of(matcher.group());
      }
    }
    return Optional.empty();
  }

  private static boolean isTextWithin(String text, int maximumLength) {
    return text != null && !text.isBlank() && text.strip().length() <= maximumLength;
  }

  // 관리자 기록 한 줄: "켜짐 · 08:00 · 간격 1일 · 화면 home · 제목 {앞 40자}"
  private static String changeSummaryOf(AutoNotificationRule rule) {
    String titlePreview = rule.getTitleTemplate().length() > 40
      ? rule.getTitleTemplate().substring(0, 40) + "…" : rule.getTitleTemplate();
    String timeText = rule.getType().isHasFixedSendTime()
      ? String.format("%02d:%02d", rule.getSendHour(), rule.getSendMinute()) : "시각 없음";
    return String.join(" · ", Arrays.asList(rule.isEnabled() ? "켜짐" : "꺼짐", timeText,
      "간격 " + rule.getMinIntervalDays() + "일", "화면 " + rule.getRoute().getWire(), "제목 " + titlePreview));
  }
}
