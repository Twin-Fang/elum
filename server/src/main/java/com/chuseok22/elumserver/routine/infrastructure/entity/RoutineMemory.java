package com.chuseok22.elumserver.routine.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

/**
 * 이룸이별 AI 메모 (#1082, V63): 이룸이 1명당 1행, 줄 목록 JSON + 켜기/끄기 + 마지막 갱신 시각
 * 원문·진단은 담지 않음. 줄 변환은 RoutineMemoryLines
 */
@Entity
@Getter
@Setter
@Table(name = "routine_memory")
public class RoutineMemory extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  /// 이룸이를 지우면 함께 지움 (V63 ON DELETE CASCADE)
  @OneToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "profile_id", nullable = false, unique = true)
  @OnDelete(action = OnDeleteAction.CASCADE)
  private Profile profile;

  /// 보호자 켜기/끄기. 끄면 일과 만들기에 넣지 않고 갱신도 하지 않음 (줄은 남음)
  @Column(nullable = false, columnDefinition = "boolean not null default true")
  private boolean enabled = true;

  /// JSON 배열 [{"text","source"}] (최대 10줄)
  @Column(nullable = false, columnDefinition = "TEXT not null default '[]'")
  private String lines = "[]";

  /// 보호자가 지운 AI 줄 JSON 배열 [문장] (다시 만들지 않게, 최대 20개)
  @Column(name = "dismissed_lines", nullable = false, columnDefinition = "TEXT not null default '[]'")
  private String dismissedLines = "[]";

  /// 마지막 메모 갱신(AI 호출) 시각. 하루 1번 묶음 판단 기준
  @Column(name = "last_built_at")
  private LocalDateTime lastBuiltAt;
}
