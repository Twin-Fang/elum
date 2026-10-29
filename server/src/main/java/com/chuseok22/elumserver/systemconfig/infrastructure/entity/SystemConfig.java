package com.chuseok22.elumserver.systemconfig.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Convert;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter
@Setter
public class SystemConfig extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  // 이 버전이 모르는 키는 null 로 읽힘 (ConfigKeyConverter, 캐시 로드에서 건너뜀)
  @Convert(converter = ConfigKeyConverter.class)
  @Column(nullable = false, unique = true)
  private ConfigKey configKey;

  // "value"는 일부 DB에서 예약어라 컬럼명을 명시한다.
  @Column(name = "config_value", nullable = false, columnDefinition = "TEXT")
  private String configValue;
}
