package com.chuseok22.elumserver.auth.infrastructure.entity;

import com.chuseok22.elumserver.auth.infrastructure.oauth.OAuthProvider;
import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Getter;
import lombok.Setter;

/**
 * 계정에 연결된 소셜 신원. 한 계정에 여러 제공자를 붙일 수 있다.
 *
 * <p><b>계정을 찾는 키는 {@code provider + providerUserId}</b>다. 이메일이 아니다.
 * 애플은 숨기기 기능으로 privaterelay 주소를 주고, 카카오는 이메일이 선택 동의라
 * 아예 안 줄 수 있다. 같은 사람인데 제공자마다 이메일이 다르거나 없다.
 *
 * <p>이메일로 자동 병합하지 않는 이유는 그것이 탈취 경로가 되기 때문이다.
 * 검증되지 않은 이메일로 계정을 만들어 기존 계정에 올라탈 수 있다.
 * 연결은 <b>이미 로그인한 상태에서만</b> 허용한다.
 */
@Entity
@Getter
@Setter
@Table(
  name = "auth_identity",
  uniqueConstraints = @UniqueConstraint(
    name = "uk_auth_identity_provider_user",
    columnNames = {"provider", "provider_user_id"}
  ),
  indexes = @Index(name = "idx_auth_identity_member", columnList = "member_id")
)
public class AuthIdentity extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "member_id", nullable = false)
  private String memberId;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private OAuthProvider provider;

  @Column(name = "provider_user_id", nullable = false)
  private String providerUserId;

  /** 제공자가 준 이메일. 참고용이며 계정 조회 키로 쓰지 않는다. */
  private String email;

  @Column(nullable = false)
  private boolean emailVerified;
}
