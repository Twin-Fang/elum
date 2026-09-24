package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.GuardianKind;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileGuardian;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 보호자와 이룸이의 관계를 만들고 끊는다 (다중 보호자 명세 4-3).
 *
 * <p>원칙은 하나다 — <b>한 사람이 나가면 자기 것만 지운다.</b> 그래서 탈퇴와 나가기가 서로
 * 부딪치지 않는다. 마지막 보호자가 나가면 돌볼 사람이 없으므로 이룸이도 지운다.
 *
 * <p>클래스에 읽기 전용 트랜잭션을 걸지 않는다 — 모든 메서드가 쓰기다 (ReadOnlyTransactionWriteTest).
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class GuardianshipService {

  private final ProfileRepository profileRepository;
  private final ProfileGuardianRepository profileGuardianRepository;

  /**
   * 가입한 사람의 빈 이룸이를 만든다. 온보딩에서 이름·캐릭터를 채운다.
   *
   * <p>가입 때 만들어 두지 않으면 이후 모든 조회가 "이룸이 없음"을 분기해야 한다. 관계 행이 없으면
   * 새 서버는 이 이룸이를 찾지 못한다 — 판단이 관계 표만 보기 때문이다.
   */
  @Transactional
  public Profile createOwnProfile(Member member) {
    Profile profile = new Profile();
    // 옛 서버 호환용 대표 보호자. V23 전까지 계속 채운다 — 되돌리면 옛 코드가 이 값으로 프로필을 찾는다.
    profile.setMember(member);
    profile.setCharacter(CharacterType.LULU);
    profileRepository.save(profile);

    ProfileGuardian guardian = new ProfileGuardian();
    guardian.setProfile(profile);
    guardian.setMember(member);
    guardian.setKind(GuardianKind.GUARDIAN);
    guardian.setJoinedAt(LocalDateTime.now());
    profileGuardianRepository.save(guardian);
    return profile;
  }
}
