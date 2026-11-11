package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.common.infrastructure.properties.ControlTowerAttentionProperties;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.List;
import org.springframework.stereotype.Component;

/**
 * 관제소 수집 토큰 검사: X-Control-Token <-> 설정 토큰(현재 + 이전), 상수 시간 비교
 * 설정 토큰이 하나도 없으면 늘 거절
 */
@Component
public class ControlTowerTokenVerifier {

  private final List<byte[]> acceptedTokenBytes;

  public ControlTowerTokenVerifier(ControlTowerAttentionProperties properties) {
    this.acceptedTokenBytes = properties.acceptedTokens().stream()
      .map(acceptedToken -> acceptedToken.getBytes(StandardCharsets.UTF_8))
      .toList();
  }

  public boolean isTokenConfigured() {
    return !acceptedTokenBytes.isEmpty();
  }

  public boolean isAccepted(String presentedToken) {
    if (presentedToken == null || presentedToken.isEmpty()) {
      return false;
    }
    byte[] presentedBytes = presentedToken.getBytes(StandardCharsets.UTF_8);
    boolean isMatched = false;
    for (byte[] acceptedBytes : acceptedTokenBytes) {
      // 일치해도 끝까지 비교 (어느 토큰과 맞았는지 시간으로 드러나지 않게)
      isMatched |= MessageDigest.isEqual(acceptedBytes, presentedBytes);
    }
    return isMatched;
  }
}
