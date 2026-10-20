package com.chuseok22.elumserver.talk.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.talk.core.TalkCommentStatus;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/** 이야기 글의 댓글 1건 */
@Entity
@Getter
@Setter
@Table(
  name = "talk_comment",
  indexes = @Index(name = "idx_talk_comment_post_created", columnList = "post_id, created_at")
)
public class TalkComment extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "post_id", nullable = false)
  private String postId;

  @Column(name = "author_member_id", nullable = false)
  private String authorMemberId;

  @Column(nullable = false, columnDefinition = "TEXT")
  private String body;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private TalkCommentStatus status = TalkCommentStatus.VISIBLE;
}
