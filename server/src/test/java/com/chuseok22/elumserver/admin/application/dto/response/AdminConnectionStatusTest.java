package com.chuseok22.elumserver.admin.application.dto.response;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.link.core.CodeDigest;
import com.chuseok22.elumserver.link.infrastructure.entity.DeviceLink;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileInvite;
import java.time.LocalDateTime;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 관리자 회원 상세의 초대 코드·기기 연결 상태 판정
 * 깨지면 운영자가 "시도 초과로 막힘"을 단순 폐기·만료로 보고 보호자에게 엉뚱한 안내를 한다
 */
class AdminConnectionStatusTest {

  private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 21, 12, 0);

  private ProfileInvite invite(LocalDateTime expiresAt, LocalDateTime redeemedAt, LocalDateTime revokedAt, int failed) {
    ProfileInvite invite = new ProfileInvite();
    invite.setExpiresAt(expiresAt);
    invite.setRedeemedAt(redeemedAt);
    invite.setRevokedAt(revokedAt);
    invite.setFailedAttempts(failed);
    return invite;
  }

  private DeviceLink link(LocalDateTime expiresAt, LocalDateTime redeemedAt, LocalDateTime revokedAt, int failed) {
    DeviceLink link = new DeviceLink();
    link.setExpiresAt(expiresAt);
    link.setRedeemedAt(redeemedAt);
    link.setRevokedAt(revokedAt);
    link.setFailedAttempts(failed);
    return link;
  }

  @Test
  @DisplayName("초대 코드: 시도 초과 폐기는 막힘, 그냥 폐기는 폐기, 시간 지남은 만료, 쓴 코드는 사용됨")
  void inviteStatus() {
    LocalDateTime future = NOW.plusMinutes(5);
    LocalDateTime past = NOW.minusMinutes(5);
    int limit = CodeDigest.MAX_FAILED_ATTEMPTS;

    assertThat(AdminInviteStatus.of(invite(future, null, null, 0), NOW)).isEqualTo(AdminInviteStatus.REDEEMABLE);
    assertThat(AdminInviteStatus.of(invite(past, null, null, 0), NOW)).isEqualTo(AdminInviteStatus.EXPIRED);
    assertThat(AdminInviteStatus.of(invite(future, null, past, limit), NOW)).isEqualTo(AdminInviteStatus.BLOCKED);
    assertThat(AdminInviteStatus.of(invite(future, null, past, limit - 1), NOW)).isEqualTo(AdminInviteStatus.REVOKED);
    // 쓴 뒤 남이 두드려 폐기돼도 합류 기록이 우선
    assertThat(AdminInviteStatus.of(invite(past, past, past, limit), NOW)).isEqualTo(AdminInviteStatus.REDEEMED);
  }

  @Test
  @DisplayName("기기 연결: 연결 중은 연결됨, 끊긴 연결은 끊김, 시도 초과 폐기는 막힘, 시간 지난 암호는 만료")
  void deviceLinkStatus() {
    LocalDateTime future = NOW.plusMinutes(5);
    LocalDateTime past = NOW.minusMinutes(5);
    int limit = CodeDigest.MAX_FAILED_ATTEMPTS;

    assertThat(AdminDeviceLinkStatus.of(link(past, past, null, 0), NOW)).isEqualTo(AdminDeviceLinkStatus.LINKED);
    assertThat(AdminDeviceLinkStatus.of(link(past, past, past, 0), NOW)).isEqualTo(AdminDeviceLinkStatus.UNLINKED);
    assertThat(AdminDeviceLinkStatus.of(link(future, null, null, 0), NOW)).isEqualTo(AdminDeviceLinkStatus.PENDING);
    assertThat(AdminDeviceLinkStatus.of(link(past, null, null, 0), NOW)).isEqualTo(AdminDeviceLinkStatus.CODE_EXPIRED);
    assertThat(AdminDeviceLinkStatus.of(link(future, null, past, limit), NOW)).isEqualTo(AdminDeviceLinkStatus.BLOCKED);
    assertThat(AdminDeviceLinkStatus.of(link(future, null, past, 0), NOW)).isEqualTo(AdminDeviceLinkStatus.CODE_REVOKED);
  }
}
