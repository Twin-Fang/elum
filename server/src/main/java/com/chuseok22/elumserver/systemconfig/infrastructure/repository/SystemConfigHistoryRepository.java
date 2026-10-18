package com.chuseok22.elumserver.systemconfig.infrastructure.repository;

import com.chuseok22.elumserver.systemconfig.infrastructure.entity.SystemConfigHistory;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;

public interface SystemConfigHistoryRepository
  extends JpaRepository<SystemConfigHistory, String>, JpaSpecificationExecutor<SystemConfigHistory> {

  /// 키별 최신 이력 한 줄씩: 키로 묶어 최신 시각을 구한 뒤 그 행을 가져옴 (쿼리 1회, 키 수만큼 반복 조회 금지)
  @Query("""
    select h from SystemConfigHistory h
    where (h.configKey, h.createdAt) in (
      select x.configKey, max(x.createdAt) from SystemConfigHistory x group by x.configKey
    )
    """)
  List<SystemConfigHistory> findLatestPerKey();

  /// 한 키의 최근 이력 (최신순)
  List<SystemConfigHistory> findByConfigKeyOrderByCreatedAtDesc(String configKey, Pageable pageable);
}
