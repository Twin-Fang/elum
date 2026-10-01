package com.chuseok22.elumserver.member.infrastructure.entity;

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
 * 연결된 보호자가 다른 보호자를 이룸이에 부르는 초대 코드 하나 (다중 보호자 명세 4-6, 이슈 #361).
 *
 * <p>{@code DeviceLink} 와 같은 모양이다 — 발급 → (10분 안에) 사용 → 끝의 한 줄기를 행 하나가 들고 있다.
 * 쓴 뒤에도 행을 지우지 않는다("누가 누구를 불렀나"). <b>코드 원문은 저장하지 않는다</b> — SHA-256 만 남고
 * 원문은 발급 응답 한 번에만 나간다.
 *
 * <p>이룸이·사람은 외래키 컬럼만 들고 있다(관계 객체 없음). 이 행의 상태는 이룸이 행을 잠근 채로만 바꾸므로
 * (발급·입력·나가기 모두 같은 잠금 순서) 객체 그래프를 끌고 다닐 이유가 없다.
 */
@Entity
@Getter
@Setter
@Table(
  name = "profile_invite",
  indexes = {
    @Index(name = "idx_profile_invite_code_hash", columnList = "code_hash"),
    @Index(name = "idx_profile_invite_profile", columnList = "profile_id")
  }
)
public class ProfileInvite extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  /** 코드 원문의 SHA-256. 조회는 이 값으로만 한다. */
  @Column(name = "code_hash", nullable = false, length = 64)
  private String codeHash;

  /** 어느 이룸이에 부르는 코드인가. 그 이룸이가 지워지면 DB 가 이 행도 지운다(CASCADE). */
  @Column(name = "profile_id", nullable = false)
  private String profileId;

  /** 코드를 만든 보호자. 나가면 이 사람이 만든 코드는 폐기된다 (E4). */
  @Column(name = "issued_by", nullable = false)
  private String issuedBy;

  @Column(name = "expires_at", nullable = false)
  private LocalDateTime expiresAt;

  /** 코드를 넣어 합류한 보호자. 그 사람이 탈퇴하면 DB 가 비운다(SET NULL) — 기록만 남는다. */
  @Column(name = "redeemed_by")
  private String redeemedBy;

  /** 합류한 시각. null 이면 아직 아무도 쓰지 않았다. */
  @Column(name = "redeemed_at")
  private LocalDateTime redeemedAt;

  /** 폐기한 시각. 새 코드로 갈아치웠거나, 만든 사람이 나갔거나, 5번 틀려 막았을 때. */
  @Column(name = "revoked_at")
  private LocalDateTime revokedAt;

  /** 이 코드에 틀린 횟수. 쓰이거나 폐기된 코드를 두드린 것만 센다. */
  @Column(name = "failed_attempts", nullable = false)
  private int failedAttempts;

  /** 쓰이지도 폐기되지도 않았는가 (만료는 따로 본다). */
  public boolean isOpen() {
    return redeemedAt == null && revokedAt == null;
  }

  /** 지금 넣어서 합류할 수 있는 코드인가. */
  public boolean isRedeemable(LocalDateTime now) {
    return isOpen() && expiresAt.isAfter(now);
  }
}
