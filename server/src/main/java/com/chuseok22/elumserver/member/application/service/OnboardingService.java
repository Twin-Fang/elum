package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.dto.request.MemberCharacterUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.MemberImageStyleUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.MemberNicknameUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.MemberSupportGoalsUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.OnboardingCompleteRequest;
import com.chuseok22.elumserver.member.application.dto.response.MemberResponse;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.routine.application.service.RoutineExampleService;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutineExampleCategory;
import java.util.List;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 온보딩 완료: 이룸이 확보 > 이름·목표·캐릭터·그림 방식 저장 > 예시 일과 생성 (한 트랜잭션)
 * 헤더의 이룸이를 보지 않고 내 첫 이룸이에 저장 (앱에 남은 옛 선택값이 섞여도 403·부분 저장 없음)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class OnboardingService {

  private final MemberService memberService;
  private final RoutineExampleService routineExampleService;

  @Transactional
  public MemberResponse complete(Caller caller, OnboardingCompleteRequest request) {
    validate(request);

    // 이룸이 확보 (없으면 생성, 멱등) > 그 이룸이를 명시해 저장
    MemberResponse ensured = memberService.createProfile(caller);
    String profileId = ensured.profiles().get(0).id();
    Caller target = Caller.guardian(caller.memberId(), profileId);

    // 이룸이 정보 저장 (캐릭터·그림 방식은 보낸 경우만)
    memberService.updateNickname(target, new MemberNicknameUpdateRequest(request.nickname().trim()));
    Set<SupportGoal> goals = request.supportGoals() == null ? Set.of() : request.supportGoals();
    memberService.updateSupportGoals(target, new MemberSupportGoalsUpdateRequest(goals));
    if (request.character() != null) {
      memberService.updateCharacter(target, new MemberCharacterUpdateRequest(request.character()));
    }
    if (request.imageStyle() != null) {
      memberService.updateImageStyle(target, new MemberImageStyleUpdateRequest(request.imageStyle()));
    }

    // 예시 일과 (모르는 분류는 빼고, 이미 만들었으면 서비스가 건너뜀)
    List<String> categories = toKnownCategoryCodes(request.exampleCategories());
    if (!categories.isEmpty()) {
      routineExampleService.create(target, categories);
    }

    log.info("[onboarding complete] saved : profileId={}, exampleCategories={}", profileId, categories);
    return memberService.getMyInfo(target);
  }

  /**
   * 요청 검증 (본문, 호칭 필수)
   */
  private void validate(OnboardingCompleteRequest request) {
    if (request == null || request.nickname() == null || request.nickname().isBlank()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
  }

  /**
   * 분류 코드 목록 > 아는 코드만 (모르는 코드로 온보딩 전체가 400 이 되지 않게)
   */
  private List<String> toKnownCategoryCodes(List<String> codes) {
    if (codes == null) {
      return List.of();
    }
    List<String> known = codes.stream()
      .filter(code -> RoutineExampleCategory.fromCode(code) != null)
      .distinct()
      .toList();
    if (known.size() != codes.size()) {
      log.warn("[onboarding complete] dropped unknown example categories : requested={}, kept={}",
        codes.size(), known.size());
    }
    return known;
  }
}
