package com.chuseok22.elumserver.member.application.service;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.member.application.dto.request.MemberNicknameUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.OnboardingCompleteRequest;
import com.chuseok22.elumserver.member.application.dto.response.MemberResponse;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.ImageStyle;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.service.RoutineExampleService;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

/**
 * 온보딩 완료 한 번 저장: 앱이 지워진 이룸이 id 를 들고 있어도 내 이룸이에 전부 저장되고 예시가 생긴다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class OnboardingServiceTest {

  @Mock private MemberService memberService;
  @Mock private RoutineExampleService routineExampleService;

  @InjectMocks private OnboardingService onboardingService;

  // 탈퇴 전 이룸이 id 가 헤더에 남은 재가입 보호자
  private final Caller staleCaller = Caller.guardian("member-1", "p-deleted");
  private final Caller ownProfile = Caller.guardian("member-1", "p-own");

  @BeforeEach
  void ensuredProfileIsOwn() {
    Member member = new Member();
    member.setId("member-1");
    Profile own = new Profile();
    own.setId("p-own");
    MemberResponse ensured = MemberResponse.from(member, own, List.of(own), null);
    when(memberService.createProfile(any())).thenReturn(ensured);
  }

  private static OnboardingCompleteRequest request(String nickname, List<String> categories) {
    return new OnboardingCompleteRequest(nickname, Set.of(), CharacterType.LULU, ImageStyle.CARTOON, categories);
  }

  @Test
  @DisplayName("헤더의 옛 이룸이가 아니라 확보한 내 이룸이에 이름을 저장한다 — 재가입 직후 403 으로 이름이 빠지지 않게")
  void savesToEnsuredProfileNotHeader() {
    onboardingService.complete(staleCaller, request(" 하늘이 ", List.of()));

    verify(memberService).updateNickname(eq(ownProfile), eq(new MemberNicknameUpdateRequest("하늘이")));
    verify(memberService, never()).updateNickname(eq(staleCaller), any());
  }

  @Test
  @DisplayName("고른 분류로 내 이룸이에 예시 일과를 만든다 — 모르는 코드는 빼서 온보딩 전체가 실패하지 않게")
  void createsExamplesWithKnownCategoriesOnly() {
    onboardingService.complete(staleCaller, request("하늘이", List.of("SCHOOL_STUDY", "UNKNOWN", "HOUSE_SELF")));

    verify(routineExampleService).create(ownProfile, List.of("SCHOOL_STUDY", "HOUSE_SELF"));
  }

  @Test
  @DisplayName("분류를 건너뛰었으면 예시를 만들지 않는다")
  void skipsExamplesWhenNoCategories() {
    onboardingService.complete(staleCaller, request("하늘이", null));

    verifyNoInteractions(routineExampleService);
  }

  @Test
  @DisplayName("호칭이 비면 아무것도 저장하지 않고 400 — 일부만 저장된 이룸이가 남지 않게")
  void rejectsBlankNicknameBeforeSaving() {
    assertThatThrownBy(() -> onboardingService.complete(staleCaller, request("  ", List.of("SCHOOL_STUDY"))))
      .isInstanceOf(CustomException.class);

    verify(memberService, never()).createProfile(any());
    verifyNoInteractions(routineExampleService);
  }
}
