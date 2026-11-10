package com.chuseok22.elumserver.routine.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/// (이룸이, 보호자)별 AI 메모리 켜짐 (V71). 행이 없으면 켜짐. 끄면 찾지도 넣지도 않고 규칙은 남음
@Entity
@Getter
@Setter
@Table(name = "routine_memory_setting")
public class RoutineMemorySetting extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "profile_id", nullable = false)
  private String profileId;

  @Column(name = "member_id", nullable = false)
  private String memberId;

  @Column(nullable = false)
  private boolean enabled = true;
}
