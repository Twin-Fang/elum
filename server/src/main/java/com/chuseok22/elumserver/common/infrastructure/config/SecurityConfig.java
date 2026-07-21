package com.chuseok22.elumserver.common.infrastructure.config;

import com.chuseok22.elumserver.common.infrastructure.constant.SecurityPaths;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtAuthenticationEntryPoint;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtAuthenticationFilter;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.core.annotation.Order;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.ProviderManager;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

  private final UserDetailsService memberUserDetailsService;
  private final UserDetailsService adminUserDetailsService;
  private final JwtProvider jwtProvider;
  private final JwtAuthenticationEntryPoint jwtAuthenticationEntryPoint;

  // Lombok @RequiredArgsConstructor는 필드의 @Qualifier를 생성자 파라미터로 복사하지 않고,
  // UserDetailsService 구현체를 직접 import하면 common -> member/admin 역방향 패키지 의존이
  // 생기므로, 인터페이스 타입 + 빈 이름 기반 @Qualifier로 명시적 생성자를 작성한다.
  public SecurityConfig(
    @Qualifier("memberUserDetailsService") UserDetailsService memberUserDetailsService,
    @Qualifier("adminUserDetailsService") UserDetailsService adminUserDetailsService,
    JwtProvider jwtProvider,
    JwtAuthenticationEntryPoint jwtAuthenticationEntryPoint
  ) {
    this.memberUserDetailsService = memberUserDetailsService;
    this.adminUserDetailsService = adminUserDetailsService;
    this.jwtProvider = jwtProvider;
    this.jwtAuthenticationEntryPoint = jwtAuthenticationEntryPoint;
  }

  @Bean
  public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder();
  }

  // Member/Admin이 동일한 BCryptPasswordEncoder 인스턴스로 encode/match를 수행하도록
  // DaoAuthenticationProvider를 도메인별로 직접 구성한다.
  // Spring Security 7.1.0에서는 DaoAuthenticationProvider의 무인자 생성자와
  // setUserDetailsService(...)가 제거되었으므로(javap로 실측 확인),
  // UserDetailsService를 받는 단일 생성자를 사용한다.
  @Primary
  @Bean
  public AuthenticationManager memberAuthenticationManager() {
    DaoAuthenticationProvider provider = new DaoAuthenticationProvider(memberUserDetailsService);
    provider.setPasswordEncoder(passwordEncoder());
    return new ProviderManager(provider);
  }

  @Bean
  public AuthenticationManager adminAuthenticationManager() {
    DaoAuthenticationProvider provider = new DaoAuthenticationProvider(adminUserDetailsService);
    provider.setPasswordEncoder(passwordEncoder());
    return new ProviderManager(provider);
  }

  @Bean
  @Order(1)
  public SecurityFilterChain adminSecurityFilterChain(HttpSecurity http) throws Exception {
    http
      .securityMatcher(SecurityPaths.ADMIN_MATCHER)
      .authenticationManager(adminAuthenticationManager())
      .authorizeHttpRequests(auth -> auth
        .requestMatchers(SecurityPaths.ADMIN_LOGIN).permitAll()
        .anyRequest().authenticated()
      )
      .formLogin(form -> form
        .loginPage(SecurityPaths.ADMIN_LOGIN)
        // loginPage()만으로는 POST 처리 URL이 기본값 "/login"으로 남는다.
        // admin/login.html의 폼이 "/admin/login"으로 제출하므로 명시적으로 맞춰준다.
        .loginProcessingUrl(SecurityPaths.ADMIN_LOGIN)
        .defaultSuccessUrl(SecurityPaths.ADMIN_DASHBOARD, true)
        .permitAll()
      )
      .logout(logout -> logout
        .logoutUrl(SecurityPaths.ADMIN_LOGOUT)
        .logoutSuccessUrl(SecurityPaths.ADMIN_LOGIN)
      );

    return http.build();
  }

  @Bean
  @Order(2)
  public SecurityFilterChain apiSecurityFilterChain(HttpSecurity http) throws Exception {
    JwtAuthenticationFilter jwtAuthenticationFilter = new JwtAuthenticationFilter(jwtProvider);

    http
      .securityMatcher(SecurityPaths.API_MATCHER)
      .csrf(csrf -> csrf.disable())
      .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
      .authorizeHttpRequests(auth -> auth
        .requestMatchers(SecurityPaths.API_AUTH_MATCHER).permitAll()
        .anyRequest().authenticated()
      )
      .exceptionHandling(handling -> handling.authenticationEntryPoint(jwtAuthenticationEntryPoint))
      .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

    return http.build();
  }

  // Swagger UI/OpenAPI 문서 경로는 /admin/**, /api/** 어느 securityMatcher에도 걸리지 않아
  // 지금까지는 암묵적으로(어떤 체인도 적용되지 않아서) 인증 없이 열려 있었다. 이 상태를
  // 명시적인 permitAll 체인으로 고정해, 나중에 catch-all 체인이 추가되더라도 문서 접근이
  // 조용히 막히지 않도록 한다.
  @Bean
  @Order(3)
  public SecurityFilterChain docsSecurityFilterChain(HttpSecurity http) throws Exception {
    http
      .securityMatcher(
        SecurityPaths.DOCS_SWAGGER,
        SecurityPaths.DOCS_SWAGGER_UI_MATCHER,
        SecurityPaths.DOCS_API_DOCS_MATCHER
      )
      .csrf(csrf -> csrf.disable())
      .authorizeHttpRequests(auth -> auth.anyRequest().permitAll());

    return http.build();
  }
}
