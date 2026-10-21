package com.chuseok22.elumserver.auth.infrastructure.repository;

import com.chuseok22.elumserver.auth.infrastructure.entity.AuthIdentity;
import com.chuseok22.elumserver.auth.infrastructure.oauth.OAuthProvider;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AuthIdentityRepository extends JpaRepository<AuthIdentity, String> {

  Optional<AuthIdentity> findByProviderAndProviderUserId(OAuthProvider provider, String providerUserId);

  List<AuthIdentity> findAllByMemberId(String memberId);

  /// 여러 계정의 신원 한 번에 (관리자 회원 목록의 로그인 제공자 표시, 회원 수만큼 묻지 않음)
  List<AuthIdentity> findAllByMemberIdIn(Collection<String> memberIds);

  boolean existsByMemberIdAndProvider(String memberId, OAuthProvider provider);

  /** 이미 가입된 이메일인지 안내하기 위한 조회. 자동 병합에는 쓰지 않는다. */
  Optional<AuthIdentity> findFirstByEmailAndEmailVerifiedTrue(String email);

  void deleteAllByMemberId(String memberId);
}
