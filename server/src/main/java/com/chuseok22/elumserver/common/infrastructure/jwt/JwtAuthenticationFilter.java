package com.chuseok22.elumserver.common.infrastructure.jwt;

import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

  private static final String HEADER_NAME = "Authorization";
  private static final String TOKEN_PREFIX = "Bearer ";

  private final JwtProvider jwtProvider;
  private final TokenAccessValidator tokenAccessValidator;

  @Override
  protected void doFilterInternal(
    HttpServletRequest request,
    HttpServletResponse response,
    FilterChain filterChain
  ) throws ServletException, IOException {
    String token = resolveToken(request);

    if (token != null && jwtProvider.isValid(token)) {
      Claims claims = jwtProvider.parseClaims(token);
      String memberId = claims.getSubject();

      // 서명이 유효해도 정지 계정·강제 로그아웃(tokenInvalidBefore 이전 발급) 토큰은
      // 인증을 세팅하지 않는다 → JwtAuthenticationEntryPoint가 401을 반환한다.
      if (tokenAccessValidator.isAllowed(memberId, claims.getIssuedAt())) {
        UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(
          memberId,
          null,
          List.of(new SimpleGrantedAuthority("ROLE_MEMBER"))
        );
        SecurityContextHolder.getContext().setAuthentication(authentication);
      }
    }

    filterChain.doFilter(request, response);
  }

  private String resolveToken(HttpServletRequest request) {
    String header = request.getHeader(HEADER_NAME);
    if (header != null && header.startsWith(TOKEN_PREFIX)) {
      return header.substring(TOKEN_PREFIX.length());
    }
    return null;
  }
}
