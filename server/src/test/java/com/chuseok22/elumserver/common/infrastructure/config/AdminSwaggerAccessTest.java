package com.chuseok22.elumserver.common.infrastructure.config;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrl;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.chuseok22.elumserver.common.infrastructure.jwt.JwtAuthenticationEntryPoint;
import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.common.infrastructure.jwt.LinkAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.jwt.TokenAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.store.SharedStateStore;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.jpa.mapping.JpaMetamodelMappingContext;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * API 문서(Swagger)가 관리자 로그인 뒤에서만 열리고, 관리자 화면 안 iframe 으로만 보이는지 (#870)
 * 문서 경로를 /admin/** 아래로 옮겼으므로 관리자 체인의 인증 규칙이 그대로 적용된다.
 */
@WebMvcTest(controllers = AdminSwaggerAccessTest.SwaggerProbeController.class)
@Import({SecurityConfig.class, JwtAuthenticationEntryPoint.class, AdminSwaggerAccessTest.SwaggerProbeController.class})
class AdminSwaggerAccessTest {

  private static final String SWAGGER_PATH = "/admin/docs/swagger";
  private static final String API_DOCS_PATH = "/admin/v3/api-docs";

  // springdoc 대신 같은 경로에 응답하는 시험용 컨트롤러
  @RestController
  static class SwaggerProbeController {
    @GetMapping({SWAGGER_PATH, API_DOCS_PATH})
    String probe() {
      return "ok";
    }
  }

  @Autowired
  private MockMvc mockMvc;

  // SecurityConfig 생성자가 요구하는 빈들
  @MockitoBean(name = "memberUserDetailsService")
  private UserDetailsService memberUserDetailsService;
  @MockitoBean(name = "adminUserDetailsService")
  private UserDetailsService adminUserDetailsService;
  @MockitoBean
  private JwtProvider jwtProvider;
  @MockitoBean
  private TokenAccessValidator tokenAccessValidator;
  @MockitoBean
  private LinkAccessValidator linkAccessValidator;
  @MockitoBean
  private SystemConfigService systemConfigService;
  @MockitoBean
  private SharedStateStore sharedStateStore;
  @MockitoBean
  private JpaMetamodelMappingContext jpaMetamodelMappingContext;

  @Test
  @DisplayName("로그인하지 않으면 Swagger 화면과 API 문서 JSON 모두 로그인 화면으로 보낸다")
  void anonymous_isRedirectedToLogin() throws Exception {
    mockMvc.perform(get(SWAGGER_PATH))
      .andExpect(status().is3xxRedirection())
      .andExpect(redirectedUrl("/admin/login"));
    mockMvc.perform(get(API_DOCS_PATH))
      .andExpect(status().is3xxRedirection())
      .andExpect(redirectedUrl("/admin/login"));
  }

  @Test
  @DisplayName("관리자는 열 수 있고 응답은 같은 출처 iframe 만 허용한다")
  void admin_canOpen_andFramingIsSameOriginOnly() throws Exception {
    mockMvc.perform(get(SWAGGER_PATH).with(user("admin").authorities(new SimpleGrantedAuthority("ROLE_ADMIN"))))
      .andExpect(status().isOk())
      .andExpect(header().string("X-Frame-Options", "SAMEORIGIN"));
  }
}
