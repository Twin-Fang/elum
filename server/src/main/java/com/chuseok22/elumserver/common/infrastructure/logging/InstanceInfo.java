package com.chuseok22.elumserver.common.infrastructure.logging;

import java.lang.management.ManagementFactory;
import java.time.Instant;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.info.BuildProperties;
import org.springframework.stereotype.Component;

/**
 * 지금 이 JVM 이 어느 배포인지. 배포 워크플로가 ELUM_INSTANCE(blue|green) · ELUM_PORT 를 넘긴다.
 * 관리자 화면의 "지금 응답 중" 카드와 배포 이력 한 줄이 이 값을 쓴다.
 */
@Component
public class InstanceInfo {

  private static final String UNKNOWN = "unknown";

  private final String instance;
  private final String port;
  private final String version;
  private final Instant startedAt;

  @Autowired
  public InstanceInfo(
    @Value("${ELUM_INSTANCE:local}") String instance,
    @Value("${ELUM_PORT:}") String port,
    ObjectProvider<BuildProperties> buildProperties
  ) {
    this(
      instance,
      port,
      // build-info.properties 는 Gradle bootJar 빌드에만 있다. IDE·테스트 실행에서는 없다.
      buildProperties.stream().findFirst().map(BuildProperties::getVersion).orElse(UNKNOWN),
      Instant.ofEpochMilli(ManagementFactory.getRuntimeMXBean().getStartTime())
    );
  }

  public InstanceInfo(String instance, String port, String version, Instant startedAt) {
    this.instance = LogInstance.normalize(instance);
    this.port = port == null || port.isBlank() ? "-" : port.trim();
    this.version = version == null || version.isBlank() ? UNKNOWN : version;
    this.startedAt = startedAt;
  }

  public String instance() {
    return instance;
  }

  public String port() {
    return port;
  }

  public String version() {
    return version;
  }

  public Instant startedAt() {
    return startedAt;
  }
}
