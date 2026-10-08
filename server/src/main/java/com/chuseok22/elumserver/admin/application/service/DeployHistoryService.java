package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.DeployHistoryResponse;
import com.chuseok22.elumserver.admin.application.dto.response.DeployHistoryResponse.Deployment;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * deploy-history.log 를 배포 단위로 묶어 상태를 판정한다.
 *
 * <p>같은 색의 STARTED 부터 다음 STARTED 전까지가 한 배포다.
 * READY 없이 끝났거나(STOPPED·같은 색 재기동) 헬스체크 시간을 넘겨도 READY 가 없으면 실패로 본다.
 * 옛 컨테이너는 docker rm -f 로 지워지면 STOPPED 를 못 남기므로, 다른 배포가 READY 가 되면 종료로 본다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class DeployHistoryService {

  // 워크플로 헬스체크가 최대 120초를 기다린다. 여유를 두고 넘으면 실패로 판정한다.
  static final Duration READY_TIMEOUT = Duration.ofMinutes(3);
  static final int MAX_DEPLOYMENTS = 100;

  private final LogFileLocator locator;

  public DeployHistoryResponse list(Instant now) {
    Path file = locator.resolve(LogFileLocator.DEPLOY_HISTORY);
    if (!Files.exists(file)) {
      return new DeployHistoryResponse(locator.instance(), List.of());
    }
    List<String> lines;
    try {
      lines = Files.readAllLines(file, StandardCharsets.UTF_8);
    } catch (IOException e) {
      log.warn("[배포 이력] 읽기 실패: file={}", file, e);
      throw new CustomException(ErrorCode.LOG_FILE_READ_FAILED);
    }
    return new DeployHistoryResponse(locator.instance(), judge(lines, now));
  }

  List<Deployment> judge(List<String> lines, Instant now) {
    List<Draft> all = new ArrayList<>();
    Map<String, Draft> open = new HashMap<>();
    for (String line : lines) {
      Event event = Event.parse(line);
      if (event == null) {
        continue;
      }
      switch (event.type) {
        case "STARTED" -> {
          Draft previous = open.remove(event.instance);
          if (previous != null) {
            previous.superseded = true;
          }
          Draft draft = new Draft(event);
          all.add(draft);
          open.put(event.instance, draft);
        }
        case "READY" -> {
          Draft draft = open.get(event.instance);
          if (draft != null && draft.readyAt == null) {
            draft.readyAt = event.time;
            // 새 배포가 트래픽을 받기 시작했으니 다른 색의 준비된 배포는 곧 내려간다.
            open.values().stream()
              .filter(other -> other != draft && other.readyAt != null)
              .forEach(other -> other.replaced = true);
          }
        }
        case "STOPPED" -> {
          Draft draft = open.remove(event.instance);
          if (draft != null) {
            draft.stoppedAt = event.time;
          }
        }
        default -> {
          // 알 수 없는 이벤트는 건너뛴다.
        }
      }
    }

    String me = locator.instance();
    Draft myLatest = all.stream().filter(d -> d.instance.equals(me)).reduce((a, b) -> b).orElse(null);
    return all.stream()
      .sorted(Comparator.comparing((Draft d) -> d.startedAt).reversed())
      .limit(MAX_DEPLOYMENTS)
      .map(d -> {
        // 이 화면에 응답하고 있는 배포는 판정과 무관하게 실행 중이다
        // (새 배포가 READY 뒤 전환에 실패해 지워지면 옛 배포가 계속 응답한다).
        boolean current = d == myLatest && d.readyAt != null && d.stoppedAt == null;
        String status = current ? "RUNNING" : d.status(now);
        return new Deployment(d.instance, d.version, d.port, d.startedAt, d.readyAt, d.stoppedAt, status, current);
      })
      .toList();
  }

  private record Event(OffsetDateTime time, String instance, String version, String port, String type) {

    static Event parse(String line) {
      String[] parts = line.trim().split("\\s+");
      if (parts.length != 5) {
        return null;
      }
      try {
        return new Event(OffsetDateTime.parse(parts[0]), parts[1], parts[2], parts[3], parts[4]);
      } catch (DateTimeParseException e) {
        return null;
      }
    }
  }

  private static final class Draft {

    private final String instance;
    private final String version;
    private final String port;
    private final OffsetDateTime startedAt;
    private OffsetDateTime readyAt;
    private OffsetDateTime stoppedAt;
    private boolean superseded;
    private boolean replaced;

    Draft(Event started) {
      this.instance = started.instance;
      this.version = started.version;
      this.port = started.port;
      this.startedAt = started.time;
    }

    String status(Instant now) {
      if (readyAt == null) {
        if (stoppedAt != null || superseded || startedAt.toInstant().plus(READY_TIMEOUT).isBefore(now)) {
          return "FAILED";
        }
        return "STARTING";
      }
      return stoppedAt != null || superseded || replaced ? "STOPPED" : "RUNNING";
    }
  }
}
