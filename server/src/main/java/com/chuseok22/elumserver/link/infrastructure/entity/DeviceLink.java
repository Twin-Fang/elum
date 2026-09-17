package com.chuseok22.elumserver.link.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;

/**
 * 보호자 계정과 이룸이 휴대폰을 잇는 연결 하나.
 *
 * <p>발급 → (10분 안에) 사용 → 연결 유지 → 끊김의 한 줄기를 이 행 하나가 들고 있다.
 * 암호를 쓴 뒤에도 행을 지우지 않는다 — "언제부터 연결됐나"를 보여줘야 하고(§8-5),
 * 끊긴 이력도 남아야 한다.
 *
 * <p><b>암호 원문은 저장하지 않는다.</b> 연결 암호는 그 자체로 계정에 붙는 자격증명이라
 * refresh_token과 같은 규율을 따른다 — SHA-256만 남기고 원문은 발급 응답 한 번에만 나간다.
 */
@Entity
@Getter
@Setter
@Table(
  name = "device_link",
  indexes = {
    @Index(name = "idx_device_link_code_hash", columnList = "code_hash"),
    @Index(name = "idx_device_link_member", columnList = "member_id")
  }
)
public class DeviceLink extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "member_id", nullable = false)
  private String memberId;

  /** 어느 프로필(이룸이)의 일과를 보게 되는가. 프로필이 여럿이 되면 이 값이 갈린다. */
  @Column(name = "profile_id")
  private String profileId;

  /** 연결 암호 원문의 SHA-256. 조회는 이 값으로만 한다. */
  @Column(name = "code_hash", nullable = false, length = 64)
  private String codeHash;

  @Column(name = "expires_at", nullable = false)
  private LocalDateTime expiresAt;

  /** 이룸이 휴대폰이 암호를 넣은 시각. null이면 아직 아무도 쓰지 않았다. */
  @Column(name = "redeemed_at")
  private LocalDateTime redeemedAt;

  /** 연결된 기기. 끊을 때 이 기기의 토큰만 폐기한다 — 보호자 세션은 살아 있어야 한다. */
  @Column(name = "linked_device_id")
  private String linkedDeviceId;

  /** 연결이 끊긴 시각. 보호자가 끊었거나, 새 암호를 만들어 이전 연결을 갈아치웠을 때. */
  @Column(name = "revoked_at")
  private LocalDateTime revokedAt;

  /**
   * 이 암호에 틀린 횟수.
   *
   * <p>redeem은 로그인 전에 부르므로 인증이 없다. 횟수를 세지 않으면 7억 가지라도
   * 온라인으로 두드릴 수 있고, 뚫리면 남의 가정 당사자의 일과가 그대로 보인다.
   */
  @Column(name = "failed_attempts", nullable = false)
  private int failedAttempts;

  /** 아직 쓸 수 있는 암호인가. */
  public boolean isRedeemable(LocalDateTime now) {
    return redeemedAt == null && revokedAt == null && expiresAt.isAfter(now);
  }

  /** 지금 연결되어 있는가. */
  public boolean isLinked() {
    return redeemedAt != null && revokedAt == null;
  }
}
