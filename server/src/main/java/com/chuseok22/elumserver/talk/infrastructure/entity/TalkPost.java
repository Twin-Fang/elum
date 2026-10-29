package com.chuseok22.elumserver.talk.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.AppLocaleConverter;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import com.chuseok22.elumserver.talk.core.TalkPostVisibility;
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
import org.hibernate.annotations.DynamicUpdate;

/**
 * 이야기 글 1건: 보호자가 일과를 나눈 글 (V52 와 같은 이름)
 * member·routine 에 외래키를 걸지 않음 (탈퇴·삭제와 무관하게 글은 남고, 정리는 서비스가 맡음)
 * 바뀐 칼럼만 UPDATE (집계·상태를 다른 요청이 바꾼 값을 덮어쓰지 않음)
 * 부분 유니크 인덱스 uk_talk_post_visible_source (VISIBLE 글은 source_routine_id·visibility 당 하나) 는 V59 에만 있음
 */
@Entity
@DynamicUpdate
@Getter
@Setter
@Table(
  name = "talk_post",
  indexes = {
    @Index(name = "idx_talk_post_status_language_created", columnList = "status, language, created_at desc"),
    @Index(name = "idx_talk_post_status_language_category_created",
      columnList = "status, language, category, created_at desc"),
    @Index(name = "idx_talk_post_author_member_id", columnList = "author_member_id"),
    @Index(name = "idx_talk_post_source_routine_id", columnList = "source_routine_id")
  }
)
public class TalkPost extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(name = "author_member_id", nullable = false)
  private String authorMemberId;

  // 나눈 원본 일과. 일과관리에서 지워져도 글은 남는다
  @Column(name = "source_routine_id")
  private String sourceRoutineId;

  @Column(nullable = false, length = 100)
  private String title;

  // 글쓴이가 덧붙인 설명. 없으면 null
  @Column(columnDefinition = "TEXT")
  private String note;

  // 분류. 링크 글은 분류를 받지 않아 null
  @Enumerated(EnumType.STRING)
  @Column(length = 20)
  private TalkCategory category;

  // 글의 언어. 같은 언어 보호자에게만 보인다
  @Convert(converter = AppLocaleConverter.class)
  @Column(nullable = false, length = 8)
  private AppLocale language = AppLocale.KO;

  @Column(name = "step_count", nullable = false)
  private int stepCount;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private TalkPostStatus status = TalkPostStatus.VISIBLE;

  // 공개 범위: PUBLIC 피드에 보임, LINK_ONLY 링크를 가진 사람만 (V59)
  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private TalkPostVisibility visibility = TalkPostVisibility.PUBLIC;

  // 집계 3개: 서비스가 증감 (도움이 됐어요 수, 댓글 수, 가져간 수)
  @Column(name = "helpful_count", nullable = false)
  private int helpfulCount;

  @Column(name = "comment_count", nullable = false)
  private int commentCount;

  @Column(name = "import_count", nullable = false)
  private int importCount;

  // 링크로만 보이는 글인가 (피드·인기·내 글 목록·반응에서 빠짐)
  public boolean isLinkOnly() {
    return visibility == TalkPostVisibility.LINK_ONLY;
  }
}
