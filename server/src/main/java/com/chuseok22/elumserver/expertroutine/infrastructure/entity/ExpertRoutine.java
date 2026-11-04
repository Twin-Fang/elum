package com.chuseok22.elumserver.expertroutine.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.AppLocaleConverter;
import com.chuseok22.elumserver.expertroutine.core.ExpertRoutineReviewStatus;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import jakarta.persistence.Column;
import jakarta.persistence.Convert;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/**
 * 전문가 일과 1건: 관리자가 검수해 올린 일과 원본 (보호자는 사본을 가져감, 원본을 고쳐도 가져간 일과는 그대로)
 * 앱 노출 조건 2개: 공개 켜짐 + 검수 완료
 */
@Entity
@Getter
@Setter
@Table(
  name = "expert_routine",
  indexes = @Index(name = "idx_expert_routine_published_language", columnList = "is_published, language, sort_order")
)
public class ExpertRoutine extends BaseEntity {

  /// 제목 최대 글자 수 (일과 제목과 같은 칸)
  public static final int TITLE_MAX_LENGTH = 100;
  /// 목록 한 줄 설명 최대 글자 수
  public static final int SUMMARY_MAX_LENGTH = 200;
  /// 보상 제안 최대 글자 수 (routine.reward_text 와 같은 칸)
  public static final int REWARD_TEXT_MAX_LENGTH = 100;

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(nullable = false, length = TITLE_MAX_LENGTH)
  private String title;

  // 목록에 보이는 한 줄 설명. 없으면 null
  @Column(length = SUMMARY_MAX_LENGTH)
  private String summary;

  // 분류: 이야기 분류 6개를 같이 씀 (앱 RoutineTemplateCategory 와 같은 이름)
  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private TalkCategory category;

  // 카드 글의 언어. 같은 언어 보호자 목록에만 나옴
  @Convert(converter = AppLocaleConverter.class)
  @Column(nullable = false, length = 8)
  private AppLocale language = AppLocale.KO;

  // 보상 제안 (가져간 일과의 보상 칸에 들어감). 없으면 null
  @Column(name = "reward_text", length = REWARD_TEXT_MAX_LENGTH)
  private String rewardText;

  // 보상 프리셋 키 SNACK·VIDEO·PLAY·WALK. 직접 입력이면 null
  @Column(name = "reward_preset_key", length = 30)
  private String rewardPresetKey;

  @Enumerated(EnumType.STRING)
  @Column(name = "review_status", nullable = false, length = 20)
  private ExpertRoutineReviewStatus reviewStatus = ExpertRoutineReviewStatus.DRAFT;

  // 관리자 메모: 누가 언제 검수했는지 (앱에는 나가지 않음)
  @Column(name = "review_note", columnDefinition = "TEXT")
  private String reviewNote;

  // is_published: 앱 목록에 보임 true, 숨김 false
  @Column(name = "is_published", nullable = false)
  private boolean isPublished;

  // 목록 순서. 작을수록 위
  @Column(name = "sort_order", nullable = false)
  private int sortOrder;

  @Column(name = "step_count", nullable = false)
  private int stepCount;

  // 일과관리로 가져간 횟수 (같은 보호자의 반복도 셈)
  @Column(name = "import_count", nullable = false)
  private int importCount;

  // 마지막으로 고친 관리자 아이디
  @Column(name = "updated_by", length = 100)
  private String updatedBy;

  /// 앱에 보여도 되는가 (공개 켜짐 + 검수 완료)
  public boolean isVisibleInApp() {
    return isPublished && reviewStatus == ExpertRoutineReviewStatus.REVIEWED;
  }
}
