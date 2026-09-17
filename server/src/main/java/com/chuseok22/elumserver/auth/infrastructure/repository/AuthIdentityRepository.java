package com.chuseok22.elumserver.auth.infrastructure.repository;

import com.chuseok22.elumserver.auth.infrastructure.entity.AuthIdentity;
import com.chuseok22.elumserver.auth.infrastructure.oauth.OAuthProvider;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AuthIdentityRepository extends JpaRepository<AuthIdentity, String> {

  Optional<AuthIdentity> findByProviderAndProviderUserId(OAuthProvider provider, String providerUserId);

  List<AuthIdentity> findAllByMemberId(String memberId);

  boolean existsByMemberIdAndProvider(String memberId, OAuthProvider provider);

  /** 이미 가입된 이메일인지 안내하기 위한 조회. 자동 병합에는 쓰지 않는다. */
  Optional<AuthIdentity> findFirstByEmailAndEmailVerifiedTrue(String email);

  void deleteAllByMemberId(String memberId);
}
