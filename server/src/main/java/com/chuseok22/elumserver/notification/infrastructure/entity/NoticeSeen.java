package com.chuseok22.elumserver.notification.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;

/** 회원이 공지 목록을 마지막으로 본 시각: 이 시각 뒤에 올라오거나 고친 공지가 안 읽은 공지 */
@Entity
@Getter
@Setter
@Table(name = "notice_seen")
public class NoticeSeen extends BaseEntity {

  @Id
  @Column(name = "member_id")
  private String memberId;

  @Column(name = "seen_at", nullable = false)
  private LocalDateTime seenAt;
}
