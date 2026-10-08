package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineDetailResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineStatusCounts;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineStepImage;
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

  /** 한 쪽에 보여줄 개수. 회원 목록과 같은 리듬으로 둔다. */
  private static final int PAGE_SIZE = 20;

  /**
   * 일과 목록. <b>전건을 그리지 않는다</b>.
   *
   * <p>{@code findAll()} 로 전부 가져와 그리면 운영에서 일과가 쌓일수록 그 수만큼 줄을 그리다 화면이 멈춘다.
   * 회원 목록·AI 모니터링처럼 페이지를 나눈다.
   */
  public Page<AdminRoutineResponse> search(String keyword, int page) {
    Pageable pageable = PageRequest.of(Math.max(page, 0), PAGE_SIZE,
      Sort.by(Sort.Direction.DESC, "createdAt"));
    String normalized = keyword == null || keyword.isBlank() ? null : keyword.trim();
    Page<Routine> routines = normalized == null
      ? routineRepository.findAll(pageable)
      : routineRepository.searchForAdmin(normalized, pageable);
    // 만든 사람 이름은 한 쪽(20건)을 한 번에 묻는다 — 일과마다 묻지 않는다.
    Map<String, String> usernames = usernamesOf(routines.getContent());
    return routines.map(routine -> AdminRoutineResponse.from(routine, usernames.get(routine.getCreatedBy())));
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
