package com.chuseok22.elumserver.link.core;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.util.HexFormat;

/**
 * 연결 암호·초대 코드가 함께 쓰는 규칙 — 저장용 해시와 유효 시간·실패 횟수.
 *
 * <p>두 코드는 사람이 불러주고 받아적는 같은 여섯 글자 체계({@link LinkCode})다. 규칙이 둘로 갈리면 한쪽만
 * 바뀌어 원문이 남거나 한쪽만 느슨해질 수 있으므로 한 곳에 둔다. 해시는 refresh_token 과 같은 방식이다.
 */
public final class CodeDigest {

  /** 불러주고 받아적는 시간. 카운트다운으로 쫓지 않되 하루 종일 살아 있지도 않게. */
  public static final Duration CODE_TTL = Duration.ofMinutes(10);

  /** 코드 하나에 허용하는 실패 횟수. 사람이 받아적다 틀리는 횟수로는 5회면 넉넉하다. */
  public static final int MAX_FAILED_ATTEMPTS = 5;

  private CodeDigest() {
  }

  /** 정규화한 코드를 해시한다. 원문은 어디에도 남기지 않는다. */
  public static String sha256(String normalizedCode) {
    try {
      MessageDigest digest = MessageDigest.getInstance("SHA-256");
      return HexFormat.of().formatHex(digest.digest(normalizedCode.getBytes(StandardCharsets.UTF_8)));
    } catch (NoSuchAlgorithmException e) {
      throw new IllegalStateException("SHA-256을 쓸 수 없습니다", e);
    }
  }
}
