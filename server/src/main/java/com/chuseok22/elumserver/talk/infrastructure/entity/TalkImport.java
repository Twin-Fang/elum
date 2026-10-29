package com.chuseok22.elumserver.talk.infrastructure.entity;

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

/** 일과관리로 가져간 기록 1건: 누가 어느 프로필의 어떤 일과로 가져갔는가 (글쓴이 알림·횟수 판정에 사용) */
@Entity
@Getter
@Setter
@Table(
  name = "talk_import",
  indexes = {
    @Index(name = "idx_talk_import_post_created", columnList = "post_id, created_at"),
    @Index(name = "idx_talk_import_member_id", columnList = "member_id")
  }
)
public class TalkImport extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "post_id", nullable = false)
  private String postId;

  @Column(name = "member_id", nullable = false)
  private String memberId;

  @Column(name = "profile_id", nullable = false)
  private String profileId;

  // 가져와 만든 일과
  @Column(name = "routine_id", nullable = false)
  private String routineId;
}
