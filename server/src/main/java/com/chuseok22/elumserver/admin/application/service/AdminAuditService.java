package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.list.AdminListDefaults;
import com.chuseok22.elumserver.admin.core.AdminAuditAction;
import com.chuseok22.elumserver.admin.core.AdminAuditTargetType;
import com.chuseok22.elumserver.admin.infrastructure.entity.AdminAuditLog;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminAuditLogRepository;
import com.chuseok22.elumserver.common.infrastructure.logging.RequestIdFilter;
import java.time.LocalDateTime;
import java.util.List;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 관리자 동작 기록 (#653): 기록(본 동작 성공 뒤 호출), 목록·CSV 조회
 * 기록은 별도 트랜잭션 + 실패 시 경고 로그만: 기록 실패가 이미 끝난 본 동작을 실패로 만들지 않음
 */
@Slf4j
@Service
public class AdminAuditService {

  /// 세션에서 관리자 이름을 못 얻었을 때 (시험·세션 없는 호출)
  static final String UNKNOWN_ADMIN_USERNAME = "unknown";
  /// 메모 detail: 저장 "메모 {n}자 저장", 빈 값 저장 "메모 지움"
  static final String MEMO_CLEARED_DETAIL = "메모 지움";
  /// 기간 조건이 없을 때 쓰는 끝값 (null 바인딩 대신)
  private static final LocalDateTime UNBOUNDED_CREATED_FROM = LocalDateTime.of(2000, 1, 1, 0, 0);
  private static final LocalDateTime UNBOUNDED_CREATED_TO = LocalDateTime.of(9999, 1, 1, 0, 0);
  /// 로그용 대상 id: 영문·숫자·_ : . / - 밖은 ?, 100자 제한 (로그 줄 위조 방지)
  private static final String NON_LOGGABLE_TARGET_CHARACTERS = "[^\\w:./-]";
  private static final int MAX_LOGGABLE_TARGET_LENGTH = 100;
  private static final String CONTROL_CHARACTERS = "\\p{Cntrl}";

  private final AdminAuditLogRepository adminAuditLogRepository;
  private final TransactionTemplate requiresNewTransaction;

  public AdminAuditService(AdminAuditLogRepository adminAuditLogRepository, PlatformTransactionManager transactionManager) {
    this.adminAuditLogRepository = adminAuditLogRepository;
    this.requiresNewTransaction = new TransactionTemplate(transactionManager);
    this.requiresNewTransaction.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
  }

  /**
   * 관리자 동작 1건 기록: 관리자 이름(SecurityContext)·요청 id(MDC) 채움 > 별도 트랜잭션 저장
   * 본 동작이 성공한 뒤에만 부름. 저장 실패는 삼키지 않고 경고 로그로 남김 (본 동작 결과는 그대로)
   *
   * @param detail 짧은 요약만 (원문·민감값 금지), 500자 넘으면 자름
   */
  public void record(AdminAuditAction action, String targetId, String detail) {
    try {
      requiresNewTransaction.executeWithoutResult(status -> adminAuditLogRepository.save(toAuditLog(action, targetId, detail)));
    } catch (RuntimeException e) {
      log.warn("[admin audit] record failed : action={}, targetType={}, targetId={}",
        action, action.getTargetType(), toLoggableTargetId(targetId), e);
    }
  }

  /// 메모 저장 detail: 원문 대신 글자 수만 (0자면 지움)
  public static String memoSavedDetailOf(int memoLength) {
    return memoLength == 0 ? MEMO_CLEARED_DETAIL : "메모 " + memoLength + "자 저장";
  }

  /// 목록 한 쪽 (AdminListDefaults.PAGE_SIZE)
  @Transactional(readOnly = true)
  public Page<AdminAuditLog> search(AdminAuditSearch condition, Sort sort, int pageIndex) {
    return searchPage(condition, PageRequest.of(Math.max(pageIndex, 0), AdminListDefaults.PAGE_SIZE, sort));
  }

  /// CSV: 목록과 같은 조건·정렬로 첫 쪽(크기 maxRows). 전체 건수로 상한 초과를 판단
  @Transactional(readOnly = true)
  public Page<AdminAuditLog> searchFirstRows(AdminAuditSearch condition, Sort sort, int maxRows) {
    return searchPage(condition, PageRequest.of(0, maxRows, sort));
  }

  private Page<AdminAuditLog> searchPage(AdminAuditSearch condition, PageRequest pageRequest) {
    List<AdminAuditAction> actions = condition.action() == null
      ? List.of(AdminAuditAction.values())
      : List.of(condition.action());
    List<AdminAuditTargetType> targetTypes = condition.targetType() == null
      ? List.of(AdminAuditTargetType.values())
      : List.of(condition.targetType());
    return adminAuditLogRepository.searchForAdmin(actions, targetTypes,
      condition.adminUsername() != null, valueOrEmpty(condition.adminUsername()),
      condition.targetId() != null, valueOrEmpty(condition.targetId()),
      condition.createdFrom() == null ? UNBOUNDED_CREATED_FROM : condition.createdFrom(),
      condition.createdToExclusive() == null ? UNBOUNDED_CREATED_TO : condition.createdToExclusive(),
      pageRequest);
  }

  private static AdminAuditLog toAuditLog(AdminAuditAction action, String targetId, String detail) {
    AdminAuditLog auditLog = new AdminAuditLog();
    auditLog.setAdminUsername(currentAdminUsername());
    auditLog.setAction(action);
    auditLog.setTargetType(action.getTargetType());
    auditLog.setTargetId(truncate(targetId, AdminAuditLog.MAX_TARGET_ID_LENGTH));
    auditLog.setDetail(truncate(detail, AdminAuditLog.MAX_DETAIL_LENGTH));
    auditLog.setRequestId(MDC.get(RequestIdFilter.MDC_REQUEST_ID_KEY));
    return auditLog;
  }

  // 관리자 화면은 세션 로그인이라 인증 이름이 곧 관리자 아이디
  private static String currentAdminUsername() {
    Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
    if (authentication == null || authentication.getName() == null || authentication.getName().isBlank()) {
      return UNKNOWN_ADMIN_USERNAME;
    }
    return authentication.getName();
  }

  /// 제어문자 제거 + 상한 자르기 (null·빈 값은 null)
  private static String truncate(String value, int maxLength) {
    if (value == null || value.isBlank()) {
      return null;
    }
    String cleaned = value.replaceAll(CONTROL_CHARACTERS, " ").strip();
    return cleaned.length() > maxLength ? cleaned.substring(0, maxLength) : cleaned;
  }

  private static String toLoggableTargetId(String targetId) {
    if (targetId == null) {
      return null;
    }
    String cleaned = targetId.replaceAll(NON_LOGGABLE_TARGET_CHARACTERS, "?");
    return cleaned.length() > MAX_LOGGABLE_TARGET_LENGTH ? cleaned.substring(0, MAX_LOGGABLE_TARGET_LENGTH) : cleaned;
  }

  private static String valueOrEmpty(String value) {
    return value == null ? "" : value;
  }
}
