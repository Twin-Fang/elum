package com.chuseok22.elumserver.common.infrastructure.logging;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.nio.file.StandardOpenOption;
import java.time.Clock;
import java.time.OffsetDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.boot.context.event.ApplicationStartedEvent;
import org.springframework.context.event.ContextClosedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/**
 * 서버가 뜨고(STARTED) · 요청을 받을 준비가 되고(READY) · 내려갈 때(STOPPED) logs/deploy-history.log 에
 * 한 줄씩 남긴다. 줄 형식: {시각} {인스턴스} {버전} {포트} {이벤트}.
 *
 * <p>헬스체크에 실패한 컨테이너는 docker rm 으로 지워져 docker logs 가 사라진다. READY 없이 끝난 배포를
 * 이 파일로 알아본다. 두 JVM 이 함께 append 해도 줄이 짧아 줄 단위로 섞이지 않는다.
 * 기록 실패는 서버 기동을 막지 않는다.
 */
@Slf4j
@Component
public class DeployHistoryRecorder {

  public static final String FILE_NAME = "deploy-history.log";
  static final int MAX_LINES = 1000;
  // OffsetDateTime.toString() 은 0초를 빼고(09:00+09:00) 찍어 줄마다 길이가 달라진다. 초까지 고정한다.
  private static final DateTimeFormatter TIME_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ssXXX");

  private final Path file;
  private final InstanceInfo info;
  private final Clock clock;

  @Autowired
  public DeployHistoryRecorder(@Value("${ELUM_LOG_DIR:logs}") String logDir, InstanceInfo info) {
    this(Path.of(logDir).resolve(FILE_NAME), info, Clock.systemDefaultZone());
  }

  DeployHistoryRecorder(Path file, InstanceInfo info, Clock clock) {
    this.file = file;
    this.info = info;
    this.clock = clock;
  }

  @EventListener(ApplicationStartedEvent.class)
  public void onStarted() {
    append("STARTED");
  }

  @EventListener(ApplicationReadyEvent.class)
  public void onReady() {
    append("READY");
    trim();
  }

  @EventListener
  public void onClosed(ContextClosedEvent event) {
    // 자식 컨텍스트가 닫힐 때는 서버가 내려가는 것이 아니다.
    if (event.getApplicationContext().getParent() == null) {
      append("STOPPED");
    }
  }

  void append(String event) {
    String line = String.join(" ",
      TIME_FORMAT.format(OffsetDateTime.now(clock)),
      info.instance(), info.version(), info.port(), event) + "\n";
    try {
      Files.createDirectories(file.getParent());
      Files.writeString(file, line, StandardCharsets.UTF_8, StandardOpenOption.CREATE, StandardOpenOption.APPEND);
    } catch (IOException | RuntimeException e) {
      log.warn("[배포 이력] 기록 실패: event={}, file={}", event, file, e);
    }
  }

  // 무한히 자라지 않게 최근 MAX_LINES 줄만 남긴다. 임시 파일로 쓰고 바꿔 끼워 반쯤 쓴 파일이 남지 않게 한다.
  void trim() {
    try {
      if (!Files.exists(file)) {
        return;
      }
      List<String> lines = Files.readAllLines(file, StandardCharsets.UTF_8);
      if (lines.size() <= MAX_LINES) {
        return;
      }
      Path temp = file.resolveSibling(FILE_NAME + ".tmp");
      Files.write(temp, lines.subList(lines.size() - MAX_LINES, lines.size()), StandardCharsets.UTF_8);
      Files.move(temp, file, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
    } catch (IOException | RuntimeException e) {
      log.warn("[배포 이력] 정리 실패: file={}", file, e);
    }
  }
}
