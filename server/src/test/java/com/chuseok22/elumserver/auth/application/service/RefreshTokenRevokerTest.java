package com.chuseok22.elumserver.auth.application.service;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;

import com.chuseok22.elumserver.auth.infrastructure.entity.RevokeReason;
import com.chuseok22.elumserver.auth.infrastructure.repository.RefreshTokenRepository;
import com.chuseok22.elumserver.link.core.ElumiDeviceId;
import java.time.LocalDateTime;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class RefreshTokenRevokerTest {

  @Mock
  private RefreshTokenRepository refreshTokenRepository;

  @InjectMocks
  private RefreshTokenRevoker refreshTokenRevoker;

  @Test
  @DisplayName("D1 재사용 감지로 끊은 보호자 세션에는 재사용 감지 사유를 남긴다 — 회전 사유가 붙으면 다시 올 때 또 전부 끊는다")
  void d1_revokeGuardianSessions_recordsReuseDetected() {
    LocalDateTime now = LocalDateTime.now();

    refreshTokenRevoker.revokeGuardianSessionsInNewTransaction("m1", now);

    verify(refreshTokenRepository).revokeGuardianSessions(
      eq("m1"), eq(ElumiDeviceId.LIKE_PATTERN), eq(now), eq(RevokeReason.REUSE_DETECTED));
  }

  @Test
  @DisplayName("기기 하나를 끊을 때 부른 쪽이 준 사유를 그대로 남긴다")
  void revokeDevice_recordsGivenReason() {
    LocalDateTime now = LocalDateTime.now();

    refreshTokenRevoker.revokeDeviceInNewTransaction("m1", "elumi-l1", now, RevokeReason.DEVICE_UNLINKED);

    verify(refreshTokenRepository).revokeByMemberIdAndDeviceId(
      eq("m1"), eq("elumi-l1"), eq(now), eq(RevokeReason.DEVICE_UNLINKED));
  }
}
