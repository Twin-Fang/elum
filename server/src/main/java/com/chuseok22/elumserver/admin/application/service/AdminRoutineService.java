package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineDetailResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineStatusCounts;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineStepImage;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.util.List;
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

  /** 한 쪽에 보여줄 개수. 회원 목록과 같은 리듬으로 둔다. */
  private static final int PAGE_SIZE = 20;

  /**
   * 일과 목록. <b>전건을 그리지 않는다</b> (이슈 #248).
   *
   * <p>예전에는 {@code findAll()} 로 전부 가져와 화면에 그렸다. 회원 목록과 AI 모니터링에는
   * 페이지 나누기가 있는데 여기만 없었고, 운영에서 일과가 쌓이면 그 수만큼 줄을 그리다
   * 화면이 멈춘다.
   */
  public Page<AdminRoutineResponse> search(String keyword, int page) {
    Pageable pageable = PageRequest.of(Math.max(page, 0), PAGE_SIZE,
      Sort.by(Sort.Direction.DESC, "createdAt"));
    String normalized = keyword == null || keyword.isBlank() ? null : keyword.trim();
    Page<Routine> routines = normalized == null
      ? routineRepository.findAll(pageable)
      : routineRepository.searchForAdmin(normalized, pageable);
    return routines.map(AdminRoutineResponse::from);
  }

  public AdminRoutineDetailResponse getDetail(String routineId) {
    Routine routine = routineRepository.findById(routineId)
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_NOT_FOUND));
    return AdminRoutineDetailResponse.from(routine);
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
