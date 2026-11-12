package com.chuseok22.elumserver.notification.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.notification.core.AdminMessageRoute;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/**
 * 운영자 알림 한 번 보낸 내용 (#1273): 제목, 본문, 눌렀을 때 갈 화면
 * 받는 사람마다의 알림 행(notification)은 targetId 로 이 행을 가리킴 (문구를 사람 수만큼 복사하지 않음)
 */
@Entity
@Getter
@Setter
@Table(name = "admin_message")
public class AdminMessage extends BaseEntity {

  // 제목 최대 글자 수 (잠금 화면 한 줄)
  public static final int TITLE_MAX_LENGTH = 50;
  // 본문 최대 글자 수
  public static final int BODY_MAX_LENGTH = 300;

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(nullable = false, length = TITLE_MAX_LENGTH)
  private String title;

  @Column(nullable = false, length = BODY_MAX_LENGTH)
  private String body;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private AdminMessageRoute route;
}
