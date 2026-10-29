package com.chuseok22.elumserver.common.application.alert;

import com.chuseok22.elumserver.common.infrastructure.properties.IncidentAlertProperties;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Comparator;
import java.util.Deque;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * 5xx 급증 판정: 응답 1건 기록 > 창 밖 정리 > 창 안 건수가 기준 이상이면 묶음 알림 (#648)
 * 집계 제외: 5xx 아님, 503 (점검 모드·AI 비용 상한·제공자 꺼짐 등 의도한 멈춤, AI 는 별도 알림)
 * 반복 억제는 IncidentAlertService 쿨다운이 맡음 (원인 키 하나로 묶음)
 */
@Component
public class ServerErrorSurgeDetector {

  // 창 안 보관 최대 건수 (폭주 시 메모리 상한)
  static final int MAX_EVENTS_IN_WINDOW = 10_000;
  // 알림에 싣는 대표 항목 수 (상태·경로 각각)
  private static final int TOP_ENTRY_COUNT = 3;
  private static final int SERVER_ERROR_STATUS_MIN = 500;
  private static final int SERVICE_UNAVAILABLE_STATUS = 503;
  // 5xx 급증은 원인을 하나로 묶음 (경로별로 따로 울리지 않게)
  private static final String SURGE_CAUSE_KEY = "all";
  private static final String NO_ERROR_CODE = "-";

  private final int threshold;
  private final Duration window;
  private final Clock clock;
  private final Deque<ServerErrorEvent> events = new ArrayDeque<>();

  @Autowired
  public ServerErrorSurgeDetector(IncidentAlertProperties properties) {
    this(properties, Clock.systemUTC());
  }

  ServerErrorSurgeDetector(IncidentAlertProperties properties, Clock clock) {
    this.threshold = properties.serverErrorThreshold();
    this.window = properties.serverErrorWindow();
    this.clock = clock;
  }

  /**
   * 응답 1건 기록 > 기준 이상이면 알림
   * pathTemplate: 매핑 패턴 (/api/routines/{routineId}), 실제 주소·쿼리는 받지 않음
   */
  public synchronized Optional<IncidentAlert> record(
    int status, String httpMethod, String pathTemplate, String errorCode
  ) {
    if (!isCountedServerError(status)) {
      return Optional.empty();
    }
    Instant now = clock.instant();
    events.addLast(new ServerErrorEvent(now, status, httpMethod, pathTemplate,
      errorCode == null ? NO_ERROR_CODE : errorCode));
    pruneOutsideWindow(now);
    if (events.size() < threshold) {
      return Optional.empty();
    }
    return Optional.of(toSurgeAlert());
  }

  static boolean isCountedServerError(int status) {
    return status >= SERVER_ERROR_STATUS_MIN && status != SERVICE_UNAVAILABLE_STATUS;
  }

  // 창 밖 + 상한 초과분 정리 (오래된 것부터)
  private void pruneOutsideWindow(Instant now) {
    Instant cutoff = now.minus(window);
    while (!events.isEmpty() && events.peekFirst().occurredAt().isBefore(cutoff)) {
      events.pollFirst();
    }
    while (events.size() > MAX_EVENTS_IN_WINDOW) {
      events.pollFirst();
    }
  }

  // 항목 3개: 건수, 대표 오류(상태 + 에러 코드), 대표 경로(메서드 + 템플릿)
  private IncidentAlert toSurgeAlert() {
    List<IncidentAlert.Detail> details = List.of(
      new IncidentAlert.Detail("건수", "최근 " + toWindowText() + " " + events.size() + "건 (기준 " + threshold + "건)"),
      new IncidentAlert.Detail("대표 오류", toTopEntriesText(event -> event.status() + " " + event.errorCode())),
      new IncidentAlert.Detail("대표 경로", toTopEntriesText(event -> event.httpMethod() + " " + event.pathTemplate()))
    );
    return new IncidentAlert(IncidentAlertType.SERVER_ERROR_SURGE, SURGE_CAUSE_KEY, details);
  }

  // 같은 값끼리 세어 많은 순 상위 3개: "{값} {n}건, ..."
  private String toTopEntriesText(Function<ServerErrorEvent, String> keyOfEvent) {
    Map<String, Long> countByKey = events.stream()
      .collect(Collectors.groupingBy(keyOfEvent, Collectors.counting()));
    return countByKey.entrySet().stream()
      .sorted(Map.Entry.<String, Long>comparingByValue(Comparator.reverseOrder())
        .thenComparing(Map.Entry.comparingByKey()))
      .limit(TOP_ENTRY_COUNT)
      .map(entry -> entry.getKey() + " " + entry.getValue() + "건")
      .collect(Collectors.joining(", "));
  }

  private String toWindowText() {
    long windowSeconds = window.toSeconds();
    return windowSeconds % 60 == 0 ? (windowSeconds / 60) + "분" : windowSeconds + "초";
  }

  private record ServerErrorEvent(
    Instant occurredAt, int status, String httpMethod, String pathTemplate, String errorCode
  ) {
  }
}
