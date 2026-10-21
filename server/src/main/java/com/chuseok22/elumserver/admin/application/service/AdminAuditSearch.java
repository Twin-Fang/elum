package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.core.AdminAuditAction;
import com.chuseok22.elumserver.admin.core.AdminAuditTargetType;
import java.time.LocalDateTime;

/**
 * 관리자 기록 검색 조건: 관리자 이름·대상 id 완전 일치, 동작, 대상 종류, 기간 [from, toExclusive). null 은 조건 없음
 */
public record AdminAuditSearch(
  String adminUsername,
  AdminAuditAction action,
  AdminAuditTargetType targetType,
  String targetId,
  LocalDateTime createdFrom,
  LocalDateTime createdToExclusive
) {

  public static AdminAuditSearch none() {
    return new AdminAuditSearch(null, null, null, null, null, null);
  }
}
