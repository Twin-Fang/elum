package com.chuseok22.elumserver.routine.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.LocalDate;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

/**
 * 주간 리포트 정리 글 (V69): 끝난 주 하나당 (이룸이, 주, 언어)마다 1행
 * 이름·원문은 담지 않음 (이름은 {userName} 자리표시)
 */
@Entity
@Getter
@Setter
@Table(
  name = "weekly_report_summary",
  uniqueConstraints = @UniqueConstraint(
    name = "uk_weekly_report_summary_profile_week_language", columnNames = {"profile_id", "week_start", "language"})
)
public class WeeklyReportSummary extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  /// 이룸이를 지우면 함께 지움 (V69 ON DELETE CASCADE)
  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "profile_id", nullable = false)
  @OnDelete(action = OnDeleteAction.CASCADE)
  private Profile profile;

  /// 그 주 월요일
  @Column(name = "week_start", nullable = false)
  private LocalDate weekStart;

  /// 정리 글 언어 코드 (ko | en)
  @Column(nullable = false, length = 8)
  private String language;

  /// JSON 배열 [문장] (최대 3줄, 이름 자리 {userName})
  @Column(nullable = false, columnDefinition = "TEXT")
  private String lines;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 16)
  private Source source;

  public enum Source {
    AI,
    FALLBACK
  }
}
