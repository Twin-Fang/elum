package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.DashboardErrorsView;
import com.chuseok22.elumserver.admin.application.dto.response.LogInstanceResponse;
import com.chuseok22.elumserver.admin.application.dto.response.RecentErrorsResponse;
import com.chuseok22.elumserver.common.infrastructure.logging.InstanceInfo;
import com.chuseok22.elumserver.common.infrastructure.logging.RecentErrorStore;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/** 관리자 로그 화면 상단 카드 · 사이드바 배지 · 대시보드가 쓰는 요약. */
@Service
@RequiredArgsConstructor
public class AdminLogOverviewService {

  private static final int DASHBOARD_ITEMS = 5;
  private static final ZoneId KST = ZoneId.of("Asia/Seoul");
  private static final DateTimeFormatter SINCE_FORMAT = DateTimeFormatter.ofPattern("MM/dd HH:mm").withZone(KST);
  private static final DateTimeFormatter TIME_FORMAT = DateTimeFormatter.ofPattern("MM/dd HH:mm:ss").withZone(KST);

  private final InstanceInfo instanceInfo;
  private final LogFileLocator locator;

  public LogInstanceResponse instance() {
    String opposite = locator.oppositeInstance().orElse(null);
    return new LogInstanceResponse(
      instanceInfo.instance(),
      instanceInfo.port(),
      instanceInfo.version(),
      instanceInfo.startedAt(),
      opposite,
      opposite == null ? null : lastWrite(opposite + "/elum.log")
    );
  }

  public RecentErrorsResponse recentErrors(Instant now) {
    RecentErrorStore.Snapshot snapshot = RecentErrorStore.global().snapshot(now);
    return new RecentErrorsResponse(
      snapshot.last24h(),
      snapshot.since(),
      snapshot.recent().stream()
        .map(e -> new RecentErrorsResponse.Item(e.time(), e.logger(), e.message(), e.exceptionClass()))
        .toList()
    );
  }

  public DashboardErrorsView dashboardErrors(Instant now) {
    RecentErrorsResponse errors = recentErrors(now);
    return new DashboardErrorsView(
      errors.last24h(),
      SINCE_FORMAT.format(errors.since()),
      errors.recent().stream()
        .limit(DASHBOARD_ITEMS)
        .map(e -> new DashboardErrorsView.Item(TIME_FORMAT.format(e.time()), e.logger(), e.message()))
        .toList()
    );
  }

  // 반대 색 폴더는 첫 배포 직후 비어 있다. 없으면 null 로 두고 화면이 "아직 기록이 없어요"를 띄운다.
  private Instant lastWrite(String relativePath) {
    Path file = locator.resolve(relativePath);
    try {
      return Files.exists(file) ? Files.getLastModifiedTime(file).toInstant() : null;
    } catch (IOException e) {
      return null;
    }
  }
}
