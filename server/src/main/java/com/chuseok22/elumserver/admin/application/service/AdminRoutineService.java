package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineDetailResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineStatusCounts;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineStepImage;
import com.chuseok22.elumserver.admin.application.list.AdminListDefaults;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminRoutineList;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AdminRoutineService {

  private final RoutineRepository routineRepository;
  private final RoutineImageStorage routineImageStorage;
  private final MemberRepository memberRepository;

  /**
   * 일과 목록: 조건 쿼리 1회(이룸이 함께 조회) > 보호자 계정명 1회
   * 범위 밖 페이지는 마지막 페이지로 맞춰 다시 조회. 일과마다 쿼리하지 않음
   */
  public Page<AdminRoutineResponse> search(AdminListQuery query) {
    Page<Routine> routines = findRoutines(query);
    if (routines.getTotalPages() > 0 && query.page() > routines.getTotalPages()) {
      routines = findRoutines(query.withTotalPages(routines.getTotalPages()));
    }
    Map<String, String> usernames = usernamesOf(routines.getContent());
    return routines.map(routine -> AdminRoutineResponse.from(routine, usernames.get(routine.getCreatedBy())));
  }

  private Page<Routine> findRoutines(AdminListQuery query) {
    String statusFilter = query.filters().get(AdminRoutineList.FILTER_STATUS);
    List<RoutineStatus> statuses = statusFilter == null
      ? List.of(RoutineStatus.values())
      : List.of(RoutineStatus.valueOf(statusFilter));
    Pageable pageable = PageRequest.of(query.pageIndex(), AdminListDefaults.PAGE_SIZE, sortOf(query));
    // 보호자 필터: 회원 ID 정확히 일치 또는 아이디·닉네임 일부 (없으면 빈 값을 넘겨 파라미터 타입 고정)
    String guardian = AdminRoutineList.guardianOf(query);
    String guardianPattern = AdminListQuery.toLikePattern(guardian);
    return routineRepository.searchForAdmin(query.q() != null, query.likePattern(), statuses,
      AdminRoutineList.scheduledFromOf(query), AdminRoutineList.scheduledToExclusiveOf(query),
      guardianPattern != null, guardian == null ? "" : guardian, guardianPattern == null ? "" : guardianPattern,
      pageable);
  }

  // 정렬 열 키 > 엔티티 속성 (허용 열만 들어오므로 그 밖은 기본 정렬). 동률은 id 로 고정해 페이지가 겹치지 않게 한다
  private Sort sortOf(AdminListQuery query) {
    Sort.Direction direction = query.isAscending() ? Sort.Direction.ASC : Sort.Direction.DESC;
    Sort.Order mainOrder = switch (query.sortKey()) {
      case AdminRoutineList.SORT_TITLE -> new Sort.Order(direction, "title");
      case AdminRoutineList.SORT_STATUS -> new Sort.Order(direction, "status");
      case AdminRoutineList.SORT_SCHEDULED_AT -> new Sort.Order(direction, "scheduledAt");
      // 미완료(null)는 방향과 상관없이 뒤로
      case AdminRoutineList.SORT_COMPLETED_AT ->
        new Sort.Order(direction, "completedAt").with(Sort.NullHandling.NULLS_LAST);
      default -> new Sort.Order(direction, "updatedAt").with(Sort.NullHandling.NULLS_LAST);
    };
    return Sort.by(mainOrder, new Sort.Order(Sort.Direction.ASC, "id"));
  }

  public AdminRoutineDetailResponse getDetail(String routineId) {
    Routine routine = routineRepository.findById(routineId)
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_NOT_FOUND));
    return AdminRoutineDetailResponse.from(routine, usernamesOf(List.of(routine)).get(routine.getCreatedBy()));
  }

  private Map<String, String> usernamesOf(List<Routine> routines) {
    List<String> ids = routines.stream().map(Routine::getCreatedBy).distinct().toList();
    return memberRepository.findAllById(ids).stream()
      .collect(Collectors.toMap(Member::getId, Member::getUsername));
  }

  public AdminRoutineStatusCounts getStatusCounts() {
    long total = routineRepository.count();
    long pendingReview = routineRepository.countByStatus(RoutineStatus.PENDING_REVIEW);
    long confirmed = routineRepository.countByStatus(RoutineStatus.CONFIRMED);
    long completed = routineRepository.countByStatus(RoutineStatus.COMPLETED);
    return new AdminRoutineStatusCounts(total, pendingReview, confirmed, completed);
  }

  public AdminRoutineStepImage getStepImage(String routineId, String stepId) {
    Routine routine = routineRepository.findById(routineId)
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_NOT_FOUND));
    RoutineStep step = routine.getSteps().stream()
      .filter(candidate -> candidate.getId().equals(stepId))
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));
    RoutineImageStorage.ImageContent content = routineImageStorage.read(step.getImagePath());
    return new AdminRoutineStepImage(content.bytes(), content.contentType());
  }
}
