package com.chuseok22.elumserver.routine.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.AppLocaleConverter;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Convert;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter
@Setter
// 보내기 이력 조회 (오늘 이미 보냈는가 · 원본을 가리키는 일과가 있는가) — V42 와 같은 이름
@Table(indexes = @Index(name = "idx_routine_source_routine_id", columnList = "source_routine_id"))
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
   * <p>V32부터 NOT NULL 이다. 이 컬럼을 모르는 옛 서버는 일과를 만들지 못하므로 옛 이미지로 되돌릴 수 없다.
   */
  @Column(name = "created_by", nullable = false)
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
  /// 실제로 주는 사람은 보호자다.
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

  /**
   * 온보딩에서 고른 분류로 넣은 예시 일과인가 (#803). 홈에 `예시` 표시, 보유 한도 집계 제외.
   * 고쳐도 예시 표시는 그대로 둔다.
   */
  @Column(name = "is_example", nullable = false, columnDefinition = "boolean not null default false")
  private Boolean isExample = false;

  /**
   * 일과의 콘텐츠 언어. 일과가 만들어질 때 정해진 언어를 저장한다.
   *
   * <p>일과를 만든 요청의 화면 언어를 켜진 언어 목록(ENABLED_CONTENT_LOCALES)에 비춰 정한다. 보호자가 고르지 않고
   * 만든 뒤에는 바꾸지 않는다. 기존 일과는 V33 이 ko 로 채웠다.
   *
   * <p>이 값은 만들어질 때의 콘텐츠 언어를 <b>저장</b>할 뿐이다. AI 의 출력 언어는 이 값으로 지정하지 않으므로
   * 저장된 언어와 카드 글의 언어가 어긋날 수 있다.
   *
   * <p>columnDefinition 은 로컬(ddl-auto: update)에서 행이 있는 표에 NOT NULL 컬럼을 더할 때 DEFAULT 가 필요해서 둔다
   * (displayOrder 와 같은 이유).
   */
  @Convert(converter = AppLocaleConverter.class)
  @Column(name = "language", nullable = false, length = 8, columnDefinition = "varchar(8) not null default 'ko'")
  private AppLocale language = AppLocale.KO;

  /** 응답에 싣는 언어 코드. 언어가 없는 옛 행은 ko 로 본다. */
  public String languageCode() {
    return language == null ? AppLocale.KO.code() : language.code();
  }

  /**
   * 일과관리에서 "보내기"로 만든 오늘 일과면 그 원본 일과 ID (#804). 원본이면 null.
   *
   * <p>일과관리 목록은 원본(null)만 보여준다. 보낸 일과까지 올리면 같은 일과가 날마다 쌓인다.
   * V42 이전 일과는 모두 원본으로 본다.
   */
  @Column(name = "source_routine_id")
  private String sourceRoutineId;

  /**
   * 일과관리 "복사하기"로 만든 일과인가 (#804). 일과관리에만 있고 보호자·이룸이 홈에는 뜨지 않는다.
   *
   * <p>복사본은 고쳐서 나중에 보내려는 원본이다. 오늘 일과로 뜨면 이룸이가 같은 일과를 두 번 본다.
   * columnDefinition 은 displayOrder 와 같은 이유(로컬 ddl-auto: update 의 NOT NULL 추가)로 둔다.
   */
  @Column(name = "library_only", nullable = false, columnDefinition = "boolean not null default false")
  private boolean libraryOnly = false;

  /**
   * 보호자가 일과관리에서 지운 원본인가 (#804). 목록에서만 빠진다.
   *
   * <p>완료 기록과 이 원본으로 보낸 일과가 남아 있어 행은 지우지 않는다(수행률 추이의 원본).
   */
  @Column(name = "library_hidden", nullable = false, columnDefinition = "boolean not null default false")
  private boolean libraryHidden = false;

  private LocalDateTime completedAt;

  @OneToMany(mappedBy = "routine", cascade = CascadeType.ALL, orphanRemoval = true)
  @OrderBy("stepOrder ASC")
  private List<RoutineStep> steps = new ArrayList<>();
}
