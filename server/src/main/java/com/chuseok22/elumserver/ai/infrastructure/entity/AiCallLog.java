package com.chuseok22.elumserver.ai.infrastructure.entity;

import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
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

// AI 호출 1건의 결과 기록. 회원별 사용량 집계와 관리자 모니터링의 원천 데이터다.
// 원문 프롬프트는 저장하지 않는다(서비스 원칙 5 — 탐지 유형·건수만 저장).
@Entity
@Getter
@Setter
@Table(name = "ai_call_log", indexes = {
  @Index(name = "idx_ai_call_log_member_created", columnList = "member_id, created_at"),
  @Index(name = "idx_ai_call_log_created", columnList = "created_at"),
  @Index(name = "idx_ai_call_log_credit_job", columnList = "credit_job_id")
})
public class AiCallLog extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  // 관리자 테스트 등 회원 컨텍스트가 없는 호출은 null.
  @Column(name = "member_id")
  private String memberId;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private AiCallType callType;

  private String model;

  @Column(nullable = false)
  private boolean success;

  @Column(length = 500)
  private String errorMessage;

  private Long latencyMs;

  private Integer promptTokens;

  private Integer outputTokens;

  private Integer totalTokens;

  // 기록 시점의 요금 단가(시스템 설정)로 계산한 추정 비용. 단가가 바뀌어도 과거 기록은 불변.
  private Double estimatedCostUsd;

  // 이 호출이 속한 크레딧 작업(#407). 작업 하나에 실제로 든 USD 를 대조한다. 크레딧 밖 호출(질문·관리자 테스트)은 null.
  @Column(name = "credit_job_id")
  private String creditJobId;
}
