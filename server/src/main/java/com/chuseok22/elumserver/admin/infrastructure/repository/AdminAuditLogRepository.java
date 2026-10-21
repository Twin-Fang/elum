package com.chuseok22.elumserver.admin.infrastructure.repository;

import com.chuseok22.elumserver.admin.core.AdminAuditAction;
import com.chuseok22.elumserver.admin.core.AdminAuditTargetType;
import com.chuseok22.elumserver.admin.infrastructure.entity.AdminAuditLog;
import java.time.LocalDateTime;
import java.util.Collection;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AdminAuditLogRepository extends JpaRepository<AdminAuditLog, String> {

  /**
   * 관리자 기록 검색: 관리자·대상 id 는 완전 일치, 동작·대상 종류는 목록, 기간은 [from, toExclusive)
   * 없는 조건은 플래그 false + 빈 문자열, 목록은 전체 값 (null 바인딩 타입 문제를 피함)
   */
  @Query("""
    select a from AdminAuditLog a
    where a.action in :actions
      and a.targetType in :targetTypes
      and (:hasAdminUsername = false or a.adminUsername = :adminUsername)
      and (:hasTargetId = false or a.targetId = :targetId)
      and a.createdAt >= :createdFrom and a.createdAt < :createdToExclusive
    """)
  Page<AdminAuditLog> searchForAdmin(
    @Param("actions") Collection<AdminAuditAction> actions,
    @Param("targetTypes") Collection<AdminAuditTargetType> targetTypes,
    @Param("hasAdminUsername") boolean hasAdminUsername, @Param("adminUsername") String adminUsername,
    @Param("hasTargetId") boolean hasTargetId, @Param("targetId") String targetId,
    @Param("createdFrom") LocalDateTime createdFrom, @Param("createdToExclusive") LocalDateTime createdToExclusive,
    Pageable pageable);
}
