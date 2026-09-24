package com.chuseok22.elumserver.member.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.verify;

import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.GuardianKind;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

// 나가기 장면마다 같은 준비물을 쓰므로 안 쓰는 스텁을 허용한다 (DeviceLinkServiceTest 와 같은 설정).
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class GuardianshipServiceTest {

  @Mock
  private ProfileRepository profileRepository;

  @Mock
  private ProfileGuardianRepository profileGuardianRepository;

  @InjectMocks
  private GuardianshipService guardianshipService;

  private Member member(String id) {
    Member member = new Member();
    member.setId(id);
    member.setUsername("user-" + id);
    return member;
  }

  @Test
  @DisplayName("가입하면 빈 이룸이와 관계 한 줄이 함께 생기고 대표 보호자도 채운다 — V23 전까지 옛 서버가 읽는다")
  void createOwnProfile_createsProfileAndRelation() {
    Member member = member("A");

    Profile created = guardianshipService.createOwnProfile(member);

    assertThat(created.getMember()).isSameAs(member);
    assertThat(created.getCharacter()).isEqualTo(CharacterType.LULU);
    verify(profileRepository).save(created);
    verify(profileGuardianRepository).save(argThat(guardian ->
      guardian.getProfile() == created
        && guardian.getMember() == member
        && guardian.getKind() == GuardianKind.GUARDIAN
        && guardian.getJoinedAt() != null));
  }
}
