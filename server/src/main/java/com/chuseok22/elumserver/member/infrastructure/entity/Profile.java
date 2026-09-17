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
import jakarta.persistence.ManyToOne;
import java.util.HashSet;
import java.util.Set;
import lombok.Getter;
import lombok.Setter;

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
 * <p>지금은 계정당 하나지만 관계는 N:1로 열어 둔다. 형제가 있거나 기관에서
 * 여러 이용자를 지원하는 경우가 이 구조 위에서 그대로 돌아간다.
 */
@Entity
@Getter
@Setter
public class Profile extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  /** 이 프로필을 소유한 로그인 계정(보호자). */
  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "member_id", nullable = false)
  private Member member;

  /** 당사자를 부르는 이름. 화면 인사말과 카드 문구에 쓴다. */
  private String nickname;

  /** 카드 삽화에 등장하는 캐릭터. 단계마다 같은 모습이어야 한 이야기로 읽힌다. */
  @Enumerated(EnumType.STRING)
  private CharacterType character;

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
}
