package com.chuseok22.elumserver.notice.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.notice.core.NoticePlatform;
import com.chuseok22.elumserver.notice.core.NoticeStatus;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;

/**
 * 보호자 홈 팝업에 나가는 공지 한 장 (이슈 #370).
 *
 * <p>보지 않기 일수는 여기 두지 않는다. 팝업 하나에 체크박스가 하나라 공지마다 일수가
 * 다르면 설명할 수 없다 — 관리자 설정 {@code NOTICE_HIDE_DAYS} 하나로 둔다.
 */
@Entity
@Getter
@Setter
public class AppNotice extends BaseEntity {

  public static final int TITLE_MAX_LENGTH = 40;
  public static final int BODY_MAX_LENGTH = 1000;
  public static final int BUTTON_LABEL_MAX_LENGTH = 20;
  public static final int BUTTON_URL_MAX_LENGTH = 500;

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  /** {@code **강조**} 표기를 그대로 담는다. 길이는 표기까지 센다(컬럼 한도라서). */
  @Column(nullable = false, length = TITLE_MAX_LENGTH)
  private String title;

  /** 줄바꿈은 LF 로 담는다. */
  @Column(nullable = false, length = BODY_MAX_LENGTH)
  private String body;

  /** 저장소 열쇠. 경로가 아니다. 없으면 글만 있는 공지다. */
  private String imageKey;

  /** 문구와 링크는 둘 다 있거나 둘 다 없다. 링크는 https 만. */
  @Column(length = BUTTON_LABEL_MAX_LENGTH)
  private String buttonLabel;

  @Column(length = BUTTON_URL_MAX_LENGTH)
  private String buttonUrl;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private NoticePlatform platform = NoticePlatform.ALL;

  /** 클수록 먼저. 같으면 시작이 늦은 것이 먼저다. */
  @Column(nullable = false)
  private int priority;

  /**
   * "다시 보이게"로 저장할 때마다 오른다. 앱은 숨긴 기록에 이 값을 함께 적어 두고,
   * 값이 달라지면 숨김을 무시한다.
   */
  @Column(nullable = false)
  private int revision = 1;

  /** 한국 시각. 서버 시계로 판단한다. */
  @Column(nullable = false)
  private LocalDateTime startsAt;

  /** 한국 시각. 비면 끌 때까지. 종료 시각 그 순간부터 빠진다. */
  private LocalDateTime endsAt;

  /** 기간과 별개로 관리자가 켜고 끈다. */
  @Column(nullable = false)
  private boolean enabled;

  @Column(nullable = false)
  private String createdBy;

  @Column(nullable = false)
  private String updatedBy;

  public NoticeStatus statusAt(LocalDateTime now) {
    return NoticeStatus.of(enabled, startsAt, endsAt, now);
  }

  public boolean hasButton() {
    return buttonLabel != null && buttonUrl != null;
  }
}
