package com.chuseok22.elumserver.routine.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
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

  /**
   * 이 일과를 수행하는 당사자.
   *
   * <p>계정이 아니라 프로필에 붙는다. 같은 당사자를 보호자와 기관이 함께 지원할 때
   * 각자 만든 일과가 한 프로필 아래 모여야 당사자 화면이 하나로 보인다.
   */
  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "profile_id", nullable = false)
  private Profile profile;

  /**
   * 이 일과를 만든 보호자의 계정 ID (다중 보호자 명세 4-2).
   *
   * <p>한 이룸이에 보호자가 여럿이면 일과는 모두가 보지만 승인·수정·삭제는 만든 사람만 한다.
   * 보유 일과 한도도 이 값으로 센다 — 남이 만든 일과가 내 한도를 먹지 않게 (E42).
   *
   * <p>DB 는 비워 둘 수 있다. 옛 서버로 되돌렸을 때 옛 코드가 이 컬럼을 모르고 일과를 만들기 때문이다
   * (V25). 새 코드는 항상 채운다. NOT NULL 은 4단계(#364)에서 건다.
   */
  @Column(name = "created_by")
  private String createdBy;

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

  /**
   * 홈 목록에서 보이는 순서. 작을수록 위다.
   *
   * <p>예정 시각으로만 줄 세우면 보호자가 순서를 바꿀 수 없다. 그렇다고 예정 시각을
   * 바꿔 순서를 표현하면 "몇 시에 하는 일과인가"라는 뜻이 망가진다. 그래서 보이는
   * 순서를 따로 둔다.
   *
   * <p>같은 값이면 예정 시각으로 갈린다 — 순서를 한 번도 바꾸지 않은 계정도 지금과
   * 똑같은 차례로 보인다.
   */
  @Column(nullable = false, columnDefinition = "integer not null default 0")
  private Integer displayOrder = 0;

  private LocalDateTime completedAt;

  @OneToMany(mappedBy = "routine", cascade = CascadeType.ALL, orphanRemoval = true)
  @OrderBy("stepOrder ASC")
  private List<RoutineStep> steps = new ArrayList<>();
}
