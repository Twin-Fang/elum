package com.chuseok22.elumserver.routine.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

/**
 * 일과관리 묶음(폴더): 원본 일과 1개 이상을 차례대로 모음 (#806)
 * 구성원은 Routine.groupId · groupOrder 가 가리킴. 묶음을 지워도 일과는 지우지 않음
 */
@Entity
@Getter
@Setter
// V44 와 같은 이름
@Table(name = "routine_group", indexes = @Index(name = "idx_routine_group_profile_id", columnList = "profile_id"))
public class RoutineGroup extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  /// 묶음이 속한 이룸이. 이룸이를 지우면 묶음도 지움 (V44 ON DELETE CASCADE)
  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "profile_id", nullable = false)
  @OnDelete(action = OnDeleteAction.CASCADE)
  private Profile profile;

  /// 묶음을 만든 보호자 계정 ID. 외래키 없음 — 만든 사람이 나가도 묶음은 이룸이에 남음
  @Column(name = "created_by", nullable = false)
  private String createdBy;

  /// 묶음 이름. 서비스가 1~12자로 검사, 컬럼은 넉넉히 40
  @Column(name = "name", nullable = false, length = 40)
  private String name;

  /// 일과관리에서 묶음끼리의 순서. 작을수록 앞
  @Column(name = "display_order", nullable = false, columnDefinition = "integer not null default 0")
  private Integer displayOrder = 0;
}
