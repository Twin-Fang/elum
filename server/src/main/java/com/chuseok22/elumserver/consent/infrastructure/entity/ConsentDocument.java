package com.chuseok22.elumserver.consent.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.consent.core.ConsentKey;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;

/**
 * 지금 앱에 나가는 약관 한 편 (이슈 #278).
 *
 * <p>고칠 때마다 직전 내용이 {@link ConsentDocumentHistory} 로 남는다. 법적 문구라
 * "언제 무엇이 어떻게 바뀌었나"를 답할 수 있어야 한다.
 */
@Entity
@Getter
@Setter
public class ConsentDocument extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, unique = true)
  private ConsentKey consentKey;

  /**
   * 이 문서의 버전. 날짜 문자열({@code 2026-09-18})을 쓴다.
   *
   * <p><b>관리자가 올릴지 말지를 고른다.</b> 오타를 고칠 때마다 올리면 회원마다
   * 어떤 문구에 동의했는지 가리기 어려워진다.
   *
   * <p>⚠️ 올려도 기존 회원에게 다시 묻지는 않는다. 재동의 판정은 아직 없다.
   */
  @Column(nullable = false)
  private String version;

  @Column(nullable = false)
  private String label;

  @Column(nullable = false)
  private String summary;

  @Column(nullable = false, columnDefinition = "TEXT")
  private String body;

  /** 필수 항목은 동의하지 않으면 서비스를 쓸 수 없다. */
  @Column(nullable = false)
  private boolean required;

  /** 이 버전이 적용된 시각. 버전을 올릴 때만 갱신한다. */
  @Column(nullable = false)
  private LocalDateTime publishedAt;
}
