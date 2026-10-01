package com.chuseok22.elumserver.member.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import java.util.HashSet;
import java.util.Set;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.DynamicUpdate;

/**
 * 일과를 수행하는 당사자.
 *
 * <p>로그인하지 않는다. 자문에서 받은 원칙이다 —
 * <i>"당사자에게 아이디와 비밀번호를 만들게 하지 않는다"</i>.
 * 계정은 보호자({@link Member})가 갖고, 당사자는 그 아래 프로필로만 존재한다.
 *
 * <p>{@link Member}에서 떼어낸 이유는 <b>기기를 나누기 위해서</b>다. 한 테이블에
 * 섞여 있으면 당사자 기기가 서버에 접속하려고 보호자의 아이디·비밀번호를 써야 하고,
 * 그 기기를 잃어버리면 계정 전체가 열린다.
 *
 * <p>보호자는 여럿일 수 있다 — 관계는 {@link ProfileGuardian} 표가 들고 있다 (다중 보호자 명세 4-1).
 * 형제가 있거나 기관에서 여러 이용자를 지원하는 경우가 이 구조 위에서 그대로 돌아간다.
 * 옛 대표 보호자 컬럼(profile.member_id)은 V32(#364)에서 지웠다 — 이룸이의 보호자는 관계 표만 안다.
 */
// 바뀐 컬럼만 UPDATE 한다. 전체 컬럼을 쓰면 이름·캐릭터를 고치는 트랜잭션이 그사이 쿼리로 더한 별을
// 옛 값으로 덮어쓴다 (다중 보호자 E23·E25 — 두 보호자·두 기기가 동시에 쓴다).
@DynamicUpdate
@Entity
@Getter
@Setter
public class Profile extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  /** 당사자를 부르는 이름. 화면 인사말과 카드 문구에 쓴다. */
  private String nickname;

  /** 카드 삽화에 등장하는 캐릭터. 단계마다 같은 모습이어야 한 이야기로 읽힌다. */
  @Enumerated(EnumType.STRING)
  private CharacterType character;

  /**
   * 카드 그림 방식 (#457). 캐릭터를 쓰는 만화(기본)·실사·직접 사진(AI 그림 생략).
   *
   * <p>운영은 ddl-auto: validate 라 컬럼이 V28 마이그레이션에 있어야 서버가 뜬다. 옛 행·옛 서버가 넣은 행은
   * DEFAULT 'CARTOON' 이 채우고, 그래도 null 이 읽히면 getter 가 만화로 돌려 기존 동작을 지킨다.
   */
  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20, columnDefinition = "varchar(20) not null default 'CARTOON'")
  private ImageStyle imageStyle = ImageStyle.CARTOON;

  /**
   * 개인화 축. 진단명이나 장애 유형은 수집하지 않는다 (docs 서비스 원칙 1번).
   * 무엇을 도와줄지만 받는다.
   */
  @ElementCollection(fetch = FetchType.EAGER)
  @CollectionTable(name = "profile_support_goals", joinColumns = @JoinColumn(name = "profile_id"))
  @Enumerated(EnumType.STRING)
  @Column(name = "support_goal", nullable = false)
  private Set<SupportGoal> supportGoals = new HashSet<>();

  /** 누적 별. 당사자가 카드를 완료할 때마다 늘어난다. */
  @Column(nullable = false, columnDefinition = "integer not null default 0")
  private Integer totalStars = 0;

  /// null 이면 만화 — 그림 방식이 생기기 전 행과 옛 코드가 넣은 행이 기존 동작을 그대로 타게 한다.
  public ImageStyle getImageStyle() {
    return ImageStyle.orDefault(imageStyle);
  }
}
