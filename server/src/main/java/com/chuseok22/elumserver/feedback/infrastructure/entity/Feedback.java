package com.chuseok22.elumserver.feedback.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.feedback.core.FeedbackStatus;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import lombok.Getter;
import lombok.Setter;

/**
 * 보호자가 보낸 의견 하나.
 *
 * <p>member 에 외래키를 걸지 않는다 — 탈퇴해도 관리자가 지울 때까지 남는다.
 */
@Entity
@Getter
@Setter
@Table(
  name = "feedback",
  indexes = @Index(name = "idx_feedback_member_created", columnList = "member_id, created_at")
)
public class Feedback extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "member_id", nullable = false)
  private String memberId;

  @Column(nullable = false, columnDefinition = "TEXT")
  private String message;

  // 앱 상태 기록. 보내지 않으면 null.
  @Column(name = "app_log", columnDefinition = "TEXT")
  private String appLog;

  @Column(name = "app_version", length = 32)
  private String appVersion;

  @Column(length = 64)
  private String os;

  // 처리 상태. 기존 의견은 V40 이 NEW 로 채웠다. columnDefinition 은 로컬(ddl-auto: update)에서 행이 있는 표에 NOT NULL 을 더할 때 필요하다.
  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20, columnDefinition = "varchar(20) not null default 'NEW'")
  private FeedbackStatus status = FeedbackStatus.NEW;

  // 처리 상태를 마지막으로 바꾼 시각과 관리자. 한 번도 안 바꿨으면 null.
  @Column(name = "status_changed_at")
  private LocalDateTime statusChangedAt;

  @Column(name = "status_changed_by")
  private String statusChangedBy;

  // 관리자 메모 (V53). 관리자끼리만 보고 보낸 사람에게는 안 감. 없으면 null
  @Column(name = "admin_note", columnDefinition = "TEXT")
  private String adminNote;

  // 메모를 마지막으로 저장·지운 시각과 관리자. 한 번도 안 건드렸으면 null
  @Column(name = "admin_note_changed_at")
  private LocalDateTime adminNoteChangedAt;

  @Column(name = "admin_note_changed_by")
  private String adminNoteChangedBy;

  // 앱이 기록 맨 앞에 두는 구역 표지. 앱의 AppLogBuffer 와 같은 글자여야 한다.
  private static final String ERROR_SECTION = "== 최근 오류 ==";
  private static final String LOG_SECTION = "== 기록 ==";
  private static final Pattern ERROR_ENTRY = Pattern.compile("^\\[\\d{2}:\\d{2}:\\d{2}\\.\\d{3}]", Pattern.MULTILINE);

  public boolean hasAppLog() {
    return appLog != null && !appLog.isEmpty();
  }

  public boolean hasAdminNote() {
    return adminNote != null && !adminNote.isBlank();
  }

  /// 앱 상태 기록의 "최근 오류" 구역에 적힌 오류 건수. 구역이 없으면 0.
  public int appLogErrorCount() {
    if (!hasAppLog()) {
      return 0;
    }
    int start = appLog.indexOf(ERROR_SECTION);
    if (start < 0) {
      return 0;
    }
    start += ERROR_SECTION.length();
    int end = appLog.indexOf(LOG_SECTION, start);
    String section = end < 0 ? appLog.substring(start) : appLog.substring(start, end);
    Matcher matcher = ERROR_ENTRY.matcher(section);
    int count = 0;
    while (matcher.find()) {
      count++;
    }
    return count;
  }
}
