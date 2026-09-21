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
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/**
 * 약관을 고치기 <b>직전</b>의 스냅샷. 쌓이기만 하고 지워지지 않는다.
 *
 * <p>왜 이력을 남기나 — 약관은 법적 효력이 있는 문서다. 분쟁이 생기면 "그 사람이
 * 동의한 시점의 문구가 무엇이었나"를 답할 수 있어야 한다. 현재본만 들고 있으면
 * 그 질문에 답할 방법이 없다.
 *
 * <p>{@code changedBy} · {@code reason} 은 스냅샷이 아니라 <b>이 스냅샷을 만들게 한
 * 변경</b>에 대한 기록이다. 누가 왜 고쳤는지가 근거가 된다.
 */
@Entity
@Getter
@Setter
@Table(
  name = "consent_document_history",
  indexes = @Index(name = "idx_consent_document_history_key_created",
    columnList = "consent_key, created_at")
)
public class ConsentDocumentHistory extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private ConsentKey consentKey;

  @Column(nullable = false)
  private String version;

  @Column(nullable = false)
  private String label;

  @Column(nullable = false)
  private String summary;

  @Column(nullable = false, columnDefinition = "TEXT")
  private String body;

  @Column(nullable = false)
  private boolean required;

  /** 고친 관리자의 로그인 아이디. 알 수 없으면 {@code 알 수 없음}. */
  @Column(nullable = false)
  private String changedBy;

  /** 왜 고쳤는지. 관리자 화면에서 필수로 받는다. */
  @Column(nullable = false, columnDefinition = "TEXT")
  private String reason;
}
