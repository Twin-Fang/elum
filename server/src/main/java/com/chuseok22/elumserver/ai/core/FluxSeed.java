package com.chuseok22.elumserver.ai.core;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

/**
 * FLUX seed — 한 일과의 카드들을 같은 seed 로 그린다 (#373).
 *
 * <p>schnell 은 참조 그림을 받지 못해 카드마다 캐릭터가 달라진다. 2차 시험에서 일과마다 seed 를
 * 고정하니 카드끼리 같은 캐릭터가 나왔다.
 *
 * <h2>왜 일과 id 가 아니라 이룸이 + 일과 제목인가</h2>
 * 일과 만들기는 그림을 <b>저장 전에</b> 그린다 — 그 시점에 일과 id 가 아직 없다(id 는 저장할 때
 * DB 가 만든다). 나중에 보호자가 카드를 더할 때도 같은 seed 여야 같은 캐릭터가 나오므로, 두 때에
 * 모두 알 수 있는 값으로 정한다. 일과 제목은 만든 뒤 바꾸는 길이 없다. 같은 이룸이의 같은 제목
 * 일과(복제 포함)는 같은 seed 를 쓰는데, 같은 캐릭터가 나오는 쪽이라 해가 없다.
 */
public final class FluxSeed {

  private FluxSeed() {
  }

  /// 일과 하나를 가리키는 열쇠. 어느 쪽이든 비면 null — seed 없이(fal 이 고름) 그린다.
  public static String routineKey(String profileId, String routineTitle) {
    if (profileId == null || profileId.isBlank() || routineTitle == null || routineTitle.isBlank()) {
      return null;
    }
    return profileId + "|" + routineTitle.trim();
  }

  /// 열쇠에서 음이 아닌 정수 seed 를 만든다. 같은 열쇠는 언제나 같은 값이다.
  public static Integer of(String key) {
    if (key == null || key.isBlank()) {
      return null;
    }
    try {
      byte[] hash = MessageDigest.getInstance("SHA-256").digest(key.getBytes(StandardCharsets.UTF_8));
      int value = ((hash[0] & 0xff) << 24) | ((hash[1] & 0xff) << 16) | ((hash[2] & 0xff) << 8) | (hash[3] & 0xff);
      return value & 0x7fffffff;
    } catch (NoSuchAlgorithmException e) {
      // 모든 JVM 이 SHA-256 을 갖는다. 그래도 seed 가 없다고 그림을 포기할 일은 아니다.
      return null;
    }
  }
}
