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
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AdminRoutineService {

  private final RoutineRepository routineRepository;
  private final RoutineImageStorage routineImageStorage;

  public List<AdminRoutineResponse> getAll() {
    return routineRepository.findAll().stream()
      .map(AdminRoutineResponse::from)
      .toList();
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
