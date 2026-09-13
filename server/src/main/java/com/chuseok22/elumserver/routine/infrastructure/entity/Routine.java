package com.chuseok22.elumserver.routine.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import jakarta.persistence.CascadeType;
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
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter
@Setter
public class Routine extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "member_id", nullable = false)
  private Member member;

  @Column(nullable = false, columnDefinition = "TEXT")
  private String rawInputText;

  @Column(nullable = false, columnDefinition = "TEXT")
  private String sanitizedInputText;

  @Column(nullable = false)
  private String title;

  @Column(nullable = false)
  private LocalDateTime scheduledAt;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private RoutineStatus status;

  @Column(columnDefinition = "TEXT")
  private String revisionFeedback;

  /// 보호자가 정한 보상(강화물). 없으면 null — 건너뛰기를 허용한다.
  ///
  /// **앱이 보상을 주지 않는다.** 아이에게 보여주고 상기시키는 용도이며,
  /// 실제로 주는 사람은 보호자다. (2026-09-13 서울 ABA연구소 자문)
  @Column(length = 100)
  private String rewardText;

  /// 프리셋에서 고른 경우 그 키(SNACK·VIDEO·PLAY·WALK). 직접 입력이면 null.
  ///
  /// 아동 화면에 **그림**을 띄우려면 키가 필요하다 — 자유 텍스트만 받으면
  /// 글자를 못 읽는 사용자에게 아무 의미가 없다.
  @Column(length = 30)
  private String rewardPresetKey;

  private LocalDateTime completedAt;

  @OneToMany(mappedBy = "routine", cascade = CascadeType.ALL, orphanRemoval = true)
  @OrderBy("stepOrder ASC")
  private List<RoutineStep> steps = new ArrayList<>();
}
