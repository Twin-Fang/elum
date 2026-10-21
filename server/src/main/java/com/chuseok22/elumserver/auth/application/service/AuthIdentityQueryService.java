package com.chuseok22.elumserver.auth.application.service;

import com.chuseok22.elumserver.auth.infrastructure.entity.AuthIdentity;
import com.chuseok22.elumserver.auth.infrastructure.oauth.OAuthProvider;
import com.chuseok22.elumserver.auth.infrastructure.repository.AuthIdentityRepository;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 소셜 신원 조회 (읽기 전용): 계정 id 목록 > 연결된 로그인 제공자
 * 다른 도메인(관리자 회원 목록)이 신원 저장소를 직접 쓰지 않고 이 서비스를 거친다
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AuthIdentityQueryService {

  private final AuthIdentityRepository authIdentityRepository;

  /// 계정 id > 연결된 제공자 (중복 없이 제공자 선언 순서, 신원이 없는 계정은 빠짐). 쿼리 1회
  public Map<String, List<OAuthProvider>> providersByMemberIds(Collection<String> memberIds) {
    if (memberIds == null || memberIds.isEmpty()) {
      return Map.of();
    }
    return authIdentityRepository.findAllByMemberIdIn(memberIds).stream()
      .collect(Collectors.groupingBy(AuthIdentity::getMemberId,
        Collectors.collectingAndThen(Collectors.mapping(AuthIdentity::getProvider, Collectors.toSet()),
          providers -> providers.stream().sorted().toList())));
  }
}
