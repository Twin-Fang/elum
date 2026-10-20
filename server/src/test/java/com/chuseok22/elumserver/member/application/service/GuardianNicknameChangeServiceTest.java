package com.chuseok22.elumserver.member.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.core.NicknamePolicy;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class GuardianNicknameChangeServiceTest {

  private static final ZoneId ZONE = ZoneId.of("Asia/Seoul");
  private static final Clock FIXED_CLOCK = Clock.fixed(Instant.parse("2026-10-20T03:00:00Z"), ZONE);
  private static final LocalDateTime NOW = LocalDateTime.now(FIXED_CLOCK);
  private static final NicknamePolicy NICKNAME_POLICY = new NicknamePolicy();

  @Mock
  private MemberRepository memberRepository;

  private GuardianNicknameChangeService service() {
    return new GuardianNicknameChangeService(memberRepository, NICKNAME_POLICY, FIXED_CLOCK);
  }

  private static Member memberWith(String nickname, LocalDateTime nicknameChangedAt) {
    Member member = new Member();
    member.setId("member-1");
    member.setNickname(nickname);
    member.setNicknameChangedAt(nicknameChangedAt);
    return member;
  }

  private static ErrorCode errorCodeOf(Runnable action) {
    try {
      action.run();
    } catch (CustomException e) {
      return e.getErrorCode();
    }
    return null;
  }

  // 깨지면: 자동 생성 이름을 처음 바꾸는 보호자가 막힘
  @Test
  void 처음_바꾸면_반영하고_변경_시각을_남긴다() {
    Member member = memberWith("가파른블록-1269", null);
    when(memberRepository.existsByNicknameIgnoreCaseAndIdNot("푸른하늘", "member-1")).thenReturn(false);

    service().change(member, "  푸른하늘 ");

    assertThat(member.getNickname()).isEqualTo("푸른하늘");
    assertThat(member.getNicknameChangedAt()).isEqualTo(NOW);
    assertThat(GuardianNicknameChangeService.changeableAt(member)).isEqualTo(NOW.plusDays(7));
  }

  // 깨지면: 7일 제한이 하루 일찍 풀리거나 하루 늦게 풀림
  @Test
  void 칠일이_지나기_전에는_막고_지나면_허용한다() {
    Member recentlyChanged = memberWith("푸른하늘", NOW.minusDays(6));
    assertThat(errorCodeOf(() -> service().change(recentlyChanged, "초록바다")))
      .isEqualTo(ErrorCode.NICKNAME_CHANGE_TOO_SOON);
    assertThat(recentlyChanged.getNickname()).isEqualTo("푸른하늘");

    Member changedWeekAgo = memberWith("푸른하늘", NOW.minusDays(7));
    when(memberRepository.existsByNicknameIgnoreCaseAndIdNot("초록바다", "member-1")).thenReturn(false);
    service().change(changedWeekAgo, "초록바다");
    assertThat(changedWeekAgo.getNickname()).isEqualTo("초록바다");
  }

  // 깨지면: 대소문자만 다른 이름으로 다른 보호자를 흉내낼 수 있음
  @Test
  void 다른_보호자가_대소문자만_다르게_쓰고_있으면_중복이다() {
    Member member = memberWith("가파른블록-1269", null);
    when(memberRepository.existsByNicknameIgnoreCaseAndIdNot("SKY-7", "member-1")).thenReturn(true);

    assertThat(errorCodeOf(() -> service().change(member, "SKY-7"))).isEqualTo(ErrorCode.NICKNAME_DUPLICATED);
    assertThat(member.getNickname()).isEqualTo("가파른블록-1269");
  }

  // 깨지면: 같은 이름 저장 버튼을 다시 눌러도 7일이 다시 시작됨
  @Test
  void 지금과_같은_이름이면_아무것도_바꾸지_않는다() {
    LocalDateTime changedAt = NOW.minusDays(1);
    Member member = memberWith("푸른하늘", changedAt);

    service().change(member, "푸른하늘");

    assertThat(member.getNicknameChangedAt()).isEqualTo(changedAt);
    verify(memberRepository, never()).existsByNicknameIgnoreCaseAndIdNot(anyString(), anyString());
  }

  // 깨지면: 욕설·형식 오류 이름이 저장됨
  @Test
  void 형식_오류와_욕설은_저장하지_않는다() {
    Member member = memberWith("가파른블록-1269", null);

    assertThat(errorCodeOf(() -> service().change(member, "푸른 하늘"))).isEqualTo(ErrorCode.NICKNAME_INVALID_FORMAT);
    assertThat(errorCodeOf(() -> service().change(member, null))).isEqualTo(ErrorCode.NICKNAME_INVALID_FORMAT);
    assertThat(errorCodeOf(() -> service().change(member, "시1발"))).isEqualTo(ErrorCode.NICKNAME_NOT_ALLOWED);
    assertThat(member.getNickname()).isEqualTo("가파른블록-1269");
    assertThat(member.getNicknameChangedAt()).isNull();
  }

  // 깨지면: 본인이 대소문자만 바꿀 때 자기 이름과 겹친다고 막힘
  @Test
  void 본인_이름의_대소문자만_바꾸면_허용한다() {
    Member member = memberWith("Sky-7", null);
    when(memberRepository.existsByNicknameIgnoreCaseAndIdNot("sky-7", "member-1")).thenReturn(false);

    service().change(member, "sky-7");

    assertThat(member.getNickname()).isEqualTo("sky-7");
  }

  @Test
  void 판정_실패는_CustomException_이다() {
    assertThatThrownBy(() -> service().change(memberWith("가파른블록-1269", null), "관리자"))
      .isInstanceOf(CustomException.class);
  }
}
