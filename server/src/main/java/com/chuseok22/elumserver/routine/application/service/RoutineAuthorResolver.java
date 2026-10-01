package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository.GuardianName;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * 일과 응답을 호출자에게 맞춘다 — 보호자 원문을 가리고(#357), 만든 사람 정보를 싣는다 (#361).
 *
 * <p>둘 다 "누가 이 일과를 만들었고 누가 부르는가"에서 나오는 판단이라 한 곳에서 한다.
 * 만든 사람 이름은 {@code profile_guardian.display_name} 이다 — 계정 ID·아이디·이메일은 싣지 않는다
 * (소셜 가입자의 아이디는 내부 식별자다).
 *
 * <p><b>이름은 목록을 이룸이 단위로 묶어 한 번에 읽는다.</b> 일과마다 묻으면 목록 길이만큼 쿼리가 늘어난다.
 * 목록은 보통 이룸이 하나의 일과라 쿼리 한 번이다.
 */
@Component
@RequiredArgsConstructor
public class RoutineAuthorResolver {

  private final ProfileGuardianRepository profileGuardianRepository;

  public RoutineResponse forCaller(Caller caller, RoutineResponse response) {
    return forCaller(caller, List.of(response)).get(0);
  }

  public List<RoutineResponse> forCaller(Caller caller, List<RoutineResponse> responses) {
    List<RoutineResponse> adapted = responses.stream().map(r -> r.forCaller(caller)).toList();
    // 이룸이 휴대폰에는 보호자 이름을 주지 않는다 — 화면에 쓰지 않는 값이고, 보내지 않으면 남지 않는다 (#357 과 같은 이유).
    if (caller.isElumi()) {
      return adapted;
    }

    // 이룸이 → 그 이룸이에서 일과를 만든 사람들
    Map<String, Set<String>> authorsByProfile = new LinkedHashMap<>();
    for (RoutineResponse r : adapted) {
      if (r.profileId() != null && r.createdBy() != null) {
        authorsByProfile.computeIfAbsent(r.profileId(), k -> new HashSet<>()).add(r.createdBy());
      }
    }
    if (authorsByProfile.isEmpty()) {
      return adapted;
    }

    // "이룸이 ID + 계정 ID" 로 찾는다 — 같은 사람도 이룸이마다 다르게 불릴 수 있다.
    Map<String, Map<String, String>> names = new HashMap<>();
    authorsByProfile.forEach((profileId, memberIds) -> {
      Map<String, String> byMember = new HashMap<>();
      for (GuardianName guardian : profileGuardianRepository.findNamesByProfileIdAndMemberIdIn(profileId, memberIds)) {
        String name = guardian.getDisplayName();
        // 비었거나 공백이면 이름 없음 — 앱이 '보호자'로 부른다.
        if (name != null && !name.isBlank()) {
          byMember.put(guardian.getMemberId(), name.trim());
        }
      }
      names.put(profileId, byMember);
    });

    return adapted.stream()
      .map(r -> {
        Map<String, String> byMember = r.profileId() == null ? null : names.get(r.profileId());
        String name = byMember == null || r.createdBy() == null ? null : byMember.get(r.createdBy());
        return name == null ? r : r.withCreatorName(name);
      })
      .toList();
  }
}
