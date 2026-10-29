package com.chuseok22.elumserver.notification.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import com.chuseok22.elumserver.notification.application.dto.request.PushDeviceRegisterRequest;
import com.chuseok22.elumserver.notification.core.PushPlatform;
import com.chuseok22.elumserver.notification.infrastructure.entity.PushDevice;
import com.chuseok22.elumserver.notification.infrastructure.repository.PushDeviceRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

/// 기기 주인이 안 옮겨지면 옛 계정에 푸시가 가고, 토큰 검사가 없으면 빈 토큰이 쌓이며, 남의 토큰을 지울 수 있다
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class PushDeviceServiceTest {

  private static final ZoneId ZONE = ZoneId.of("Asia/Seoul");
  private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-10-19T03:00:00Z"), ZONE);

  @Mock
  private PushDeviceRepository pushDeviceRepository;

  private PushDeviceService pushDeviceService;

  @BeforeEach
  void setUp() {
    pushDeviceService = new PushDeviceService(pushDeviceRepository, CLOCK);
  }

  @Test
  @DisplayName("같은 토큰이 다른 회원 것이면 소유자·언어·시각을 갱신한다")
  void sameTokenOtherMember_reassignsOwner() {
    PushDevice existing = new PushDevice();
    existing.setMemberId("old-member");
    existing.setToken("token-1");
    when(pushDeviceRepository.findByToken("token-1")).thenReturn(Optional.of(existing));

    CurrentLocale.runAs(AppLocale.EN, () ->
      pushDeviceService.register("new-member", new PushDeviceRegisterRequest("token-1", PushPlatform.ANDROID)));

    assertThat(existing.getMemberId()).isEqualTo("new-member");
    assertThat(existing.getLocale()).isEqualTo(AppLocale.EN);
    assertThat(existing.getPlatform()).isEqualTo(PushPlatform.ANDROID);
    assertThat(existing.getLastRegisteredAt()).isEqualTo(LocalDateTime.now(CLOCK));
    verify(pushDeviceRepository).save(existing);
  }

  @Test
  @DisplayName("빈 토큰은 PUSH_TOKEN_INVALID 로 거절한다")
  void blankToken_throwsPushTokenInvalid() {
    assertThatThrownBy(() -> pushDeviceService.register("m1", new PushDeviceRegisterRequest("  ", PushPlatform.IOS)))
      .isInstanceOf(CustomException.class)
      .extracting(e -> ((CustomException) e).getErrorCode())
      .isEqualTo(ErrorCode.PUSH_TOKEN_INVALID);
    verify(pushDeviceRepository, never()).save(any());
  }

  @Test
  @DisplayName("2048자를 넘는 토큰은 거절한다")
  void tooLongToken_throwsPushTokenInvalid() {
    String longToken = "a".repeat(PushDeviceService.TOKEN_MAX_LENGTH + 1);

    assertThatThrownBy(() -> pushDeviceService.register("m1", new PushDeviceRegisterRequest(longToken, PushPlatform.IOS)))
      .isInstanceOf(CustomException.class);
  }

  @Test
  @DisplayName("남의 토큰은 해제해도 지우지 않는다")
  void unregister_otherMembersToken_doesNothing() {
    PushDevice existing = new PushDevice();
    existing.setMemberId("someone-else");
    when(pushDeviceRepository.findByToken("token-1")).thenReturn(Optional.of(existing));

    pushDeviceService.unregister("m1", "token-1");

    verify(pushDeviceRepository, never()).delete(any());
  }

  @Test
  @DisplayName("내 토큰은 해제하면 지운다")
  void unregister_ownToken_deletes() {
    PushDevice existing = new PushDevice();
    existing.setMemberId("m1");
    when(pushDeviceRepository.findByToken("token-1")).thenReturn(Optional.of(existing));

    pushDeviceService.unregister("m1", "token-1");

    verify(pushDeviceRepository).delete(existing);
  }

  @Test
  @DisplayName("이룸이 기기로 등록하면 연결 ID 가 붙고, 같은 기기를 보호자로 다시 등록하면 지워진다")
  void register_elumiThenGuardian_switchesLinkId() {
    PushDevice existing = new PushDevice();
    when(pushDeviceRepository.findByToken("token-1")).thenReturn(Optional.of(existing));

    pushDeviceService.register("m1", "link-1", new PushDeviceRegisterRequest("token-1", PushPlatform.IOS));
    assertThat(existing.getLinkId()).isEqualTo("link-1");

    pushDeviceService.register("m1", new PushDeviceRegisterRequest("token-1", PushPlatform.IOS));
    assertThat(existing.getLinkId()).isNull();
  }

  @Test
  @DisplayName("이룸이 기기는 같은 회원의 보호자 토큰을 해제하지 못한다")
  void unregister_elumiCaller_cannotDeleteGuardianToken() {
    PushDevice guardianDevice = new PushDevice();
    guardianDevice.setMemberId("m1");
    when(pushDeviceRepository.findByToken("token-1")).thenReturn(Optional.of(guardianDevice));

    pushDeviceService.unregister("m1", "link-1", "token-1");

    verify(pushDeviceRepository, never()).delete(any());
  }
}
