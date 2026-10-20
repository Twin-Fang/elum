package com.chuseok22.elumserver.talk.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.talk.core.TalkReportReason;
import com.chuseok22.elumserver.talk.core.TalkReportTargetType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;

/** 신고 1건: 한 대상에 한 사람이 한 번 (target_type, target_id, reporter_member_id 유니크) */
@Entity
@Getter
@Setter
@Table(
  name = "talk_report",
  uniqueConstraints = @UniqueConstraint(
    name = "uk_talk_report_target_reporter",
    columnNames = {"target_type", "target_id", "reporter_member_id"})
)
public class TalkReport extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Enumerated(EnumType.STRING)
  @Column(name = "target_type", nullable = false, length = 20)
  private TalkReportTargetType targetType;

  @Column(name = "target_id", nullable = false)
  private String targetId;

  // 댓글 신고도 어느 글인지 알아야 관리자 화면이 글로 이동 (글 신고는 targetId 와 같음)
  @Column(name = "post_id", nullable = false)
  private String postId;

  @Column(name = "reporter_member_id", nullable = false)
  private String reporterMemberId;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private TalkReportReason reason;

  // 관리자가 처리한 시각. 미처리면 null
  @Column(name = "resolved_at")
  private LocalDateTime resolvedAt;
}
