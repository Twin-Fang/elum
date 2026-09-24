package com.chuseok22.elumserver.systemconfig.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/**
 * 시스템 설정 변경 이력 한 줄 (#407, V26). 누가 언제 무엇을 무엇으로 바꿨는지 — 크레딧을 끄고 켠 기록도 남는다.
 *
 * <p>추가만 한다. 비밀값은 평문도 암호문도 남기지 않고 가림 표시만 적는다.
 */
@Entity
@Getter
@Setter
@Table(
  name = "system_config_history",
  indexes = @Index(name = "idx_system_config_history_key_created", columnList = "config_key, created_at")
)
public class SystemConfigHistory extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  /// ConfigKey 이름. 나중에 키가 없어져도 이력은 읽혀야 해서 enum 이 아니라 문자열로 둔다.
  @Column(name = "config_key", nullable = false)
  private String configKey;

  @Column(name = "old_value", columnDefinition = "TEXT")
  private String oldValue;

  @Column(name = "new_value", columnDefinition = "TEXT")
  private String newValue;

  /// 바꾼 관리자 로그인 아이디(회원이 아니다). 코드가 바꾸면 system.
  @Column(name = "changed_by")
  private String changedBy;

  @Column(length = 500)
  private String reason;
}
