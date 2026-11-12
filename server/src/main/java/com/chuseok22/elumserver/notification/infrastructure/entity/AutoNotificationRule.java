package com.chuseok22.elumserver.notification.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.notification.core.AdminMessageRoute;
import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDate;
import lombok.Getter;
import lombok.Setter;

/**
 * 자동 알림 규칙 한 종류 (#1275): 켜짐, 제목·본문 틀(변수 {아이이름} {일과} {날짜}), 갈 화면, 보내는 시각(KST), 같은 사람 최소 간격
 * 행은 V74 가 5종 모두 꺼진 채로 넣음 (관리자가 문구 검토 후 켬)
 */
@Entity
@Getter
@Setter
@Table(name = "auto_notification_rule")
public class AutoNotificationRule extends BaseEntity {

  @Id
  @Enumerated(EnumType.STRING)
  @Column(length = 40)
  private AutoNotificationType type;

  @Column(name = "enabled", nullable = false)
  private boolean isEnabled;

  @Column(name = "title_template", nullable = false, length = AdminMessage.TITLE_MAX_LENGTH)
  private String titleTemplate;

  @Column(name = "body_template", nullable = false, length = AdminMessage.BODY_MAX_LENGTH)
  private String bodyTemplate;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private AdminMessageRoute route;

  @Column(name = "send_hour", nullable = false)
  private int sendHour;

  @Column(name = "send_minute", nullable = false)
  private int sendMinute;

  @Column(name = "min_interval_days", nullable = false)
  private int minIntervalDays;

  // 그날 이미 돌았는지 (정한 시각이 있는 종류만 씀)
  @Column(name = "last_run_date")
  private LocalDate lastRunDate;

  // 마지막으로 고친 관리자 아이디
  @Column(name = "updated_by", length = 100)
  private String updatedBy;
}
