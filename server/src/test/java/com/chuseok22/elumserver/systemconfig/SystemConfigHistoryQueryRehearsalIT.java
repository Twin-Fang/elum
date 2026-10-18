package com.chuseok22.elumserver.systemconfig;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigHistoryCondition;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigHistoryService;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.chuseok22.elumserver.systemconfig.infrastructure.entity.SystemConfigHistory;
import java.time.LocalDateTime;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.context.ActiveProfiles;

/**
 * 실제 Postgres 로 하는 설정 이력 조회 리허설: 키별 최신 1줄(group by), 조건 검색(LIKE 이스케이프·기간·정렬). 평소 빌드에서는 건너뜀
 *
 * <pre>
 * docker run -d --name elum-750-pg -e POSTGRES_USER=elum -e POSTGRES_PASSWORD=pw -e POSTGRES_DB=elum -p 54750:5432 postgres:17-alpine
 * ELUM_IT_DB_URL=jdbc:postgresql://localhost:54750/elum ./gradlew test --tests '*SystemConfigHistoryQueryRehearsalIT'
 * </pre>
 */
@SpringBootTest(properties = {
  "spring.flyway.enabled=false",
  "spring.jpa.hibernate.ddl-auto=update",
  "spring.datasource.url=${ELUM_IT_DB_URL:jdbc:postgresql://localhost:5432/elum}",
  "spring.datasource.username=elum",
  "spring.datasource.password=pw",
  "gemini.api-key=rehearsal-invalid"
})
@ActiveProfiles("dev")
@EnabledIfEnvironmentVariable(named = "ELUM_IT_DB_URL", matches = ".+")
class SystemConfigHistoryQueryRehearsalIT {

  @Autowired private SystemConfigService systemConfigService;
  @Autowired private SystemConfigHistoryService historyService;

  @Test
  @DisplayName("키별 최신 1줄 · 값 검색의 % 이스케이프 · 기간 · 정렬이 실제 DB 에서 돈다")
  void latestPerKey_andSearch() {
    systemConfigService.update(ConfigKey.FREE_ADS_REMOVED, "true", "admin", "첫 변경");
    systemConfigService.update(ConfigKey.FREE_ADS_REMOVED, "false", "kimchi", "100% 되돌림");
    systemConfigService.update(ConfigKey.MAINTENANCE_MODE, "true", "admin", null);

    Map<String, SystemConfigHistory> latest = historyService.latestByKey();
    assertThat(latest.get("FREE_ADS_REMOVED").getNewValue()).isEqualTo("false");
    assertThat(latest.get("FREE_ADS_REMOVED").getChangedBy()).isEqualTo("kimchi");
    assertThat(latest.get("MAINTENANCE_MODE").getNewValue()).isEqualTo("true");
    assertThat(historyService.latestOf("FREE_ADS_REMOVED")).isPresent();
    assertThat(historyService.recentOf("FREE_ADS_REMOVED")).hasSize(2);

    var percentSearch = historyService.search(
      new SystemConfigHistoryCondition("%100\\%%", null, null, null, null),
      PageRequest.of(0, 20, SystemConfigHistoryService.sortOf("createdAt", false)));
    assertThat(percentSearch.getTotalElements()).isEqualTo(1);

    var byUserAndPeriod = historyService.search(
      new SystemConfigHistoryCondition(null, null, "admin", LocalDateTime.now().minusDays(1), LocalDateTime.now().plusDays(1)),
      PageRequest.of(0, 20, SystemConfigHistoryService.sortOf("configKey", true)));
    assertThat(byUserAndPeriod.getContent()).extracting(SystemConfigHistory::getConfigKey)
      .containsExactly("FREE_ADS_REMOVED", "MAINTENANCE_MODE");
  }
}
