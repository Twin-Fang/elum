package com.chuseok22.elumserver.link.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.link.infrastructure.entity.DeviceLink;
import com.chuseok22.elumserver.link.infrastructure.repository.DeviceLinkRepository;
import java.time.LocalDateTime;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 연결이 끊기면 <b>그 즉시</b> 막혀야 한다 (이슈 #200).
 *
 * <p>리프레시 토큰만 폐기하면 이미 받아 둔 액세스 토큰으로 만료(하루)까지 계속 본다.
 * 잃어버린 휴대폰을 끊는 것이 이 기능의 이유인데 하루를 기다려야 하면 의미가 없다.
 */
@ExtendWith(MockitoExtension.class)
class LinkAccessGuardTest {

  @Mock private DeviceLinkRepository deviceLinkRepository;

  @InjectMocks private LinkAccessGuard guard;

  private DeviceLink linked() {
    DeviceLink l = new DeviceLink();
    l.setId("l1");
    l.setMemberId("m1");
    l.setCodeHash("hash");
    l.setExpiresAt(LocalDateTime.now().minusMinutes(1));
    l.setRedeemedAt(LocalDateTime.now().minusMinutes(1));
    return l;
  }

  @Test
  @DisplayName("연결이 살아 있으면 통과한다")
  void active() {
    when(deviceLinkRepository.findById("l1")).thenReturn(Optional.of(linked()));

    assertThat(guard.isLinkActive("l1")).isTrue();
  }

  @Test
  @DisplayName("끊긴 연결이면 막는다 — 액세스 토큰이 아직 살아 있어도")
  void revoked() {
    DeviceLink l = linked();
    l.setRevokedAt(LocalDateTime.now());
    when(deviceLinkRepository.findById("l1")).thenReturn(Optional.of(l));

    assertThat(guard.isLinkActive("l1")).isFalse();
  }

  @Test
  @DisplayName("없는 연결이면 막는다")
  void missing() {
    when(deviceLinkRepository.findById("l1")).thenReturn(Optional.empty());

    assertThat(guard.isLinkActive("l1")).isFalse();
  }

  @Test
  @DisplayName("linkId가 없는 이룸이 토큰은 막는다 — 끊을 방법이 없는 세션은 두지 않는다")
  void missingClaim() {
    assertThat(guard.isLinkActive(null)).isFalse();
    assertThat(guard.isLinkActive("")).isFalse();
  }

  @Test
  @DisplayName("아직 아무도 쓰지 않은 암호의 링크로는 통과하지 못한다")
  void notRedeemed() {
    DeviceLink l = linked();
    l.setRedeemedAt(null);
    when(deviceLinkRepository.findById("l1")).thenReturn(Optional.of(l));

    assertThat(guard.isLinkActive("l1")).isFalse();
  }
}
