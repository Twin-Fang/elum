package com.chuseok22.elumserver.notification.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.AppLocaleConverter;
import com.chuseok22.elumserver.notification.core.PushPlatform;
import jakarta.persistence.Column;
import jakarta.persistence.Convert;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;

/** 푸시를 받을 기기 한 대: 토큰 하나가 한 줄, member 에 외래키 없음. link_id 가 있으면 이룸이 기기 */
@Entity
@Getter
@Setter
@Table(
  name = "push_device",
  uniqueConstraints = @UniqueConstraint(name = "uk_push_device_token", columnNames = "token"),
  indexes = {
    @Index(name = "idx_push_device_member_id", columnList = "member_id"),
    @Index(name = "idx_push_device_link_id", columnList = "link_id")
  }
)
public class PushDevice extends BaseEntity {

  public static final int TOKEN_MAX_LENGTH = 4096;

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "member_id", nullable = false)
  private String memberId;

  // 이룸이 기기면 그 연결 ID, 보호자 기기면 null (이룸이 기기도 member_id 는 붙여 준 보호자)
  @Column(name = "link_id")
  private String linkId;

  @Column(nullable = false, length = TOKEN_MAX_LENGTH)
  private String token;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private PushPlatform platform;

  // 푸시 문구 언어. columnDefinition 은 로컬(ddl-auto: update)에서 NOT NULL 을 더할 때 필요
  @Convert(converter = AppLocaleConverter.class)
  @Column(name = "locale", nullable = false, length = 8, columnDefinition = "varchar(8) not null default 'ko'")
  private AppLocale locale = AppLocale.KO;

  @Column(name = "last_registered_at", nullable = false)
  private LocalDateTime lastRegisteredAt;
}
