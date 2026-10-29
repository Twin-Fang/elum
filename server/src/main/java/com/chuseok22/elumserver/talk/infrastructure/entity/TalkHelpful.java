package com.chuseok22.elumserver.talk.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Getter;
import lombok.Setter;

/** 도움이 됐어요 1건: 한 글에 한 사람이 한 번 (post_id, member_id 유니크) */
@Entity
@Getter
@Setter
@Table(
  name = "talk_helpful",
  indexes = @Index(name = "idx_talk_helpful_member_id", columnList = "member_id"),
  uniqueConstraints = @UniqueConstraint(name = "uk_talk_helpful_post_member", columnNames = {"post_id", "member_id"})
)
public class TalkHelpful extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "post_id", nullable = false)
  private String postId;

  @Column(name = "member_id", nullable = false)
  private String memberId;
}
