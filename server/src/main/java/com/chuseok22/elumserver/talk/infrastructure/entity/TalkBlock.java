package com.chuseok22.elumserver.talk.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Getter;
import lombok.Setter;

/** 차단 1건: 차단한 사람 > 차단당한 사람 (blocker_member_id, blocked_member_id 유니크) */
@Entity
@Getter
@Setter
@Table(
  name = "talk_block",
  uniqueConstraints = @UniqueConstraint(
    name = "uk_talk_block_blocker_blocked",
    columnNames = {"blocker_member_id", "blocked_member_id"})
)
public class TalkBlock extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "blocker_member_id", nullable = false)
  private String blockerMemberId;

  @Column(name = "blocked_member_id", nullable = false)
  private String blockedMemberId;
}
