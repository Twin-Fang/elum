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
 * <p>보호자는 여럿일 수 있다 — 관계는 {@link ProfileGuardian} 표가 들고 있다 (다중 보호자 명세 4-1).
 * 형제가 있거나 기관에서 여러 이용자를 지원하는 경우가 이 구조 위에서 그대로 돌아간다.
 */
@Entity
@Getter
@Setter
public class Profile extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  /**
   * 옛 서버 호환용 대표 보호자. <b>새 코드는 권한·조회에 읽지 않는다.</b>
   *
   * <p>배포 뒤 옛 서버로 되돌리면 옛 코드가 이 값으로 프로필을 찾는다. 그래서 4단계(#364)에서 지우기 전까지
   * 가입 때 채우고, 대표가 나가면 남은 사람 중 가장 먼저 합류한 사람으로 바꾼다. 처음 만든 보호자가
   * 나가도 이룸이가 남아야 해서 비워 둘 수 있다 (V25).
   */
  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "member_id", nullable = true)
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
