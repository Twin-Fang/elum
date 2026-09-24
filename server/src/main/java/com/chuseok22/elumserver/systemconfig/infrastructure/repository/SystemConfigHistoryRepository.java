package com.chuseok22.elumserver.systemconfig.infrastructure.repository;

import com.chuseok22.elumserver.systemconfig.infrastructure.entity.SystemConfigHistory;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SystemConfigHistoryRepository extends JpaRepository<SystemConfigHistory, String> {

  /// 설정 화면 아래 "최근 변경" — 최신 20건.
  List<SystemConfigHistory> findTop20ByOrderByCreatedAtDesc();
}
