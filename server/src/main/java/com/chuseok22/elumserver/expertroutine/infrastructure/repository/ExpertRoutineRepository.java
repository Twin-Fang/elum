package com.chuseok22.elumserver.expertroutine.infrastructure.repository;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.expertroutine.core.ExpertRoutineReviewStatus;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutine;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ExpertRoutineRepository extends JpaRepository<ExpertRoutine, String> {

  /// 앱 목록(분류 전체): 공개 + 검수 상태 + 언어 > 순서·제목 순
  List<ExpertRoutine> findByIsPublishedTrueAndReviewStatusAndLanguageOrderBySortOrderAscTitleAsc(
    ExpertRoutineReviewStatus reviewStatus, AppLocale language);

  /// 앱 목록(분류 하나): 공개 + 검수 상태 + 언어 + 분류 > 순서·제목 순
  List<ExpertRoutine> findByIsPublishedTrueAndReviewStatusAndLanguageAndCategoryOrderBySortOrderAscTitleAsc(
    ExpertRoutineReviewStatus reviewStatus, AppLocale language, TalkCategory category);

  /// 관리자 목록: 전부 > 순서·제목 순
  List<ExpertRoutine> findAllByOrderBySortOrderAscTitleAsc();

  /// 가져간 횟수 +1 (동시 가져가기에도 빠지지 않게 DB 에서 더함)
  @Modifying(flushAutomatically = true)
  @Query("update ExpertRoutine routine set routine.importCount = routine.importCount + 1 where routine.id = :id")
  int increaseImportCount(@Param("id") String id);
}
