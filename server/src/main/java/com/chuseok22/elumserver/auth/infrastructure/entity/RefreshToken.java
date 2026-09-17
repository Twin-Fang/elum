package com.chuseok22.elumserver.auth.infrastructure.entity;

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
 * 리프레시 토큰. 액세스 토큰이 만료돼도 다시 로그인하지 않게 한다.
 *
 * <p>보호자는 일과를 한 번 만들면 며칠 앱을 안 열 수 있다. 그때마다 로그인을
 * 요구하면 쓰지 않게 된다. 액세스는 짧게, 리프레시는 길게 두고 쓸 때마다 갱신한다.
 *
 * <p><b>원문을 저장하지 않는다.</b> DB가 새도 토큰 자체는 새지 않도록 해시만 남긴다.
 *
 * <p><b>회전(rotation)</b> — 갱신할 때마다 새 리프레시를 발급하고 쓴 것은 즉시 만료시킨다.
 * 이미 쓴 토큰이 또 오면 탈취로 보고 그 체인 전체를 끊는다. 회전이 없으면 탈취당해도
 * 아무도 모른다.
 */
@Entity
@Getter
@Setter
@Table(
  name = "refresh_token",
  indexes = {
    @Index(name = "idx_refresh_token_hash", columnList = "token_hash"),
    @Index(name = "idx_refresh_token_member", columnList = "member_id")
  }
)
public class RefreshToken extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "member_id", nullable = false)
  private String memberId;

  /** 토큰 원문의 SHA-256. 조회는 이 값으로 한다. */
  @Column(name = "token_hash", nullable = false, unique = true, length = 64)
  private String tokenHash;

  /**
   * 발급 대상 기기. 폰을 바꿔도 이전 기기의 세션이 남지 않게 하고,
   * 나중에 "로그인된 기기 목록"을 보여줄 때 쓴다.
   */
  private String deviceId;

  @Column(nullable = false)
  private LocalDateTime expiresAt;

  /** 회전이나 로그아웃으로 무효화된 시각. null이면 살아 있다. */
  private LocalDateTime revokedAt;

  /** 회전으로 이 토큰을 대체한 토큰. 재사용 감지 시 체인을 따라 전부 끊는다. */
  private String replacedById;

  private LocalDateTime lastUsedAt;

  public boolean isUsable(LocalDateTime now) {
    return revokedAt == null && expiresAt.isAfter(now);
  }
}
