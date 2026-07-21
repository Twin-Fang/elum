package com.chuseok22.elumserver.auth.application.service;

import com.chuseok22.elumserver.auth.application.dto.request.LoginRequest;
import com.chuseok22.elumserver.auth.application.dto.request.SignUpRequest;
import com.chuseok22.elumserver.auth.application.dto.response.TokenResponse;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.properties.JwtProperties;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AuthService {

  private final MemberRepository memberRepository;
  private final PasswordEncoder passwordEncoder;
  private final AuthenticationManager memberAuthenticationManager;
  private final JwtProvider jwtProvider;
  private final JwtProperties jwtProperties;

  @Transactional
  public void signUp(SignUpRequest request) {
    if (memberRepository.existsByUsername(request.username())) {
      throw new CustomException(ErrorCode.DUPLICATE_USERNAME);
    }

    Member member = new Member();
    member.setUsername(request.username());
    member.setPassword(passwordEncoder.encode(request.password()));
    memberRepository.save(member);
  }

  public TokenResponse login(LoginRequest request) {
    try {
      memberAuthenticationManager.authenticate(
        new UsernamePasswordAuthenticationToken(request.username(), request.password())
      );
    } catch (BadCredentialsException e) {
      throw new CustomException(ErrorCode.INVALID_CREDENTIALS);
    }

    Member member = memberRepository.findByUsername(request.username())
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));

    String accessToken = jwtProvider.createAccessToken(member.getId(), member.getUsername());
    return new TokenResponse(accessToken, "Bearer", jwtProperties.accessExpMillis());
  }
}
