package com.chuseok22.elumserver.common.infrastructure.logging;

import java.util.Locale;
import java.util.Optional;

/**
 * Blue/Green 인스턴스 이름. 배포 워크플로가 ELUM_INSTANCE 로 넘긴다.
 * 로그 폴더 이름이 되므로 알려진 값만 쓰고, 그 밖은 전부 local 로 본다.
 */
public final class LogInstance {

  public static final String BLUE = "blue";
  public static final String GREEN = "green";
  public static final String LOCAL = "local";

  private LogInstance() {
  }

  public static String normalize(String raw) {
    if (raw == null) {
      return LOCAL;
    }
    String value = raw.trim().toLowerCase(Locale.ROOT);
    return BLUE.equals(value) || GREEN.equals(value) ? value : LOCAL;
  }

  /** 배포마다 번갈아 뜨는 반대 색. local 은 짝이 없다. */
  public static Optional<String> opposite(String instance) {
    return switch (normalize(instance)) {
      case BLUE -> Optional.of(GREEN);
      case GREEN -> Optional.of(BLUE);
      default -> Optional.empty();
    };
  }
}
