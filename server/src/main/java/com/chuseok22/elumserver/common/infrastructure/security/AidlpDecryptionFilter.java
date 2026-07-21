package com.chuseok22.elumserver.common.infrastructure.security;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.AidlpProperties;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ReadListener;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletInputStream;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

// AI DLP 진입점 3경로의 암호화된 요청 본문을 복호화해 평문 JSON으로 되돌린다.
// JWT 인증 필터 뒤에 놓여, 인증된 요청의 body만 열어 컨트롤러에는 기존 평문 DTO로 전달한다.
// 필터 계층 예외는 GlobalExceptionHandler가 잡지 못하므로 실패 응답을 직접 기록한다.
@Component
@RequiredArgsConstructor
public class AidlpDecryptionFilter extends OncePerRequestFilter {

  // 암호화 대상 경로. 정확히 이 경로의 POST만 복호화한다.
  private static final Set<String> TARGET_PATHS = Set.of(
    "/api/routines",
    "/api/routines/questions",
    "/api/internal/sensitive-check"
  );
  private static final long ALLOWED_SKEW_MILLIS = 5 * 60 * 1000L;

  private final AidlpCryptoService cryptoService;
  private final NonceStore nonceStore;
  private final AidlpProperties properties;
  // 이 프로젝트는 ObjectMapper 빈을 주입하지 않고 각자 직접 생성해 쓴다(JwtAuthenticationEntryPoint 등 관례).
  // starter-webmvc 환경에서 필터 생성 시점에 ObjectMapper 빈이 없어 기동 실패했으므로 직접 생성으로 맞춘다.
  private final ObjectMapper objectMapper = new ObjectMapper();

  @Override
  protected boolean shouldNotFilter(HttpServletRequest request) {
    // 정확 경로 매칭 + POST 만 대상. secret 미설정이면 복호화 자체를 건너뛴다(데모 안전 — 로컬 fallback 유도).
    boolean isTarget = HttpMethod.POST.matches(request.getMethod())
      && TARGET_PATHS.contains(request.getRequestURI());
    return !isTarget || properties.getSecret().isBlank();
  }

  @Override
  protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
    throws IOException, ServletException {

    // 1) 봉투 파싱
    JsonNode root;
    try {
      root = objectMapper.readTree(request.getInputStream());
    } catch (Exception e) {
      writeError(response, ErrorCode.DLP_ENVELOPE_INVALID);
      return;
    }
    JsonNode enc = root == null ? null : root.get("encrypted");
    if (enc == null) {
      writeError(response, ErrorCode.DLP_ENVELOPE_INVALID);
      return;
    }
    AidlpEnvelope envelope = new AidlpEnvelope(
      text(enc, "ciphertext"), text(enc, "iv"), text(enc, "salt"));
    if (!envelope.isComplete()) {
      writeError(response, ErrorCode.DLP_ENVELOPE_INVALID);
      return;
    }

    // 2) 헤더 추출
    String timestamp = request.getHeader("X-Elum-Timestamp");
    String nonce = request.getHeader("X-Elum-Nonce");
    String signature = request.getHeader("X-Elum-Signature");
    if (isBlank(timestamp) || isBlank(nonce) || isBlank(signature)) {
      writeError(response, ErrorCode.DLP_ENVELOPE_INVALID);
      return;
    }

    // 3) timestamp 허용 오차
    long ts;
    try {
      ts = Long.parseLong(timestamp);
    } catch (NumberFormatException e) {
      writeError(response, ErrorCode.DLP_TIMESTAMP_INVALID);
      return;
    }
    long now = System.currentTimeMillis();
    if (Math.abs(now - ts) > ALLOWED_SKEW_MILLIS) {
      writeError(response, ErrorCode.DLP_TIMESTAMP_INVALID);
      return;
    }

    // 4) HMAC 서명 (nonce 소비 전에 검증 — 위조 요청으로 nonce 저장소를 오염시키지 않는다)
    if (!cryptoService.verifySignature(timestamp, nonce, envelope.ciphertext(), envelope.salt(), signature)) {
      writeError(response, ErrorCode.DLP_SIGNATURE_INVALID);
      return;
    }

    // 5) nonce 재사용
    if (!nonceStore.checkAndRemember(nonce, now)) {
      writeError(response, ErrorCode.DLP_NONCE_REPLAY);
      return;
    }

    // 6) 복호화 → 평문 JSON으로 body 교체
    byte[] plain;
    try {
      plain = cryptoService.decrypt(envelope);
    } catch (Exception e) {
      writeError(response, ErrorCode.DLP_DECRYPT_FAILED);
      return;
    }

    chain.doFilter(new CachedBodyRequest(request, plain), response);
  }

  private static String text(JsonNode node, String field) {
    JsonNode v = node.get(field);
    return v == null ? null : v.asText();
  }

  private static boolean isBlank(String s) {
    return s == null || s.isBlank();
  }

  // 필터 예외는 GlobalExceptionHandler를 타지 않으므로 ErrorResponse와 동일한 JSON을 직접 쓴다.
  private void writeError(HttpServletResponse response, ErrorCode code) throws IOException {
    response.setStatus(code.getStatus().value());
    response.setContentType(MediaType.APPLICATION_JSON_VALUE);
    response.setCharacterEncoding("UTF-8");
    // ErrorResponse(errorCode, errorMessage) 구조를 그대로 흉내낸다 — 클라가 errorCode 이름으로 분기한다.
    String body = objectMapper.writeValueAsString(
      Map.of("errorCode", code.name(), "errorMessage", code.getMessage()));
    response.getWriter().write(body);
  }

  // 복호화한 평문 바이트를 요청 body로 다시 노출하는 wrapper. getInputStream을 여러 번 읽을 수 있게 한다.
  private static class CachedBodyRequest extends HttpServletRequestWrapper {
    private final byte[] body;

    CachedBodyRequest(HttpServletRequest request, byte[] body) {
      super(request);
      this.body = body;
    }

    @Override
    public ServletInputStream getInputStream() {
      ByteArrayInputStream bais = new ByteArrayInputStream(body);
      return new ServletInputStream() {
        @Override public int read() { return bais.read(); }
        @Override public boolean isFinished() { return bais.available() == 0; }
        @Override public boolean isReady() { return true; }
        @Override public void setReadListener(ReadListener listener) { /* 동기 처리라 불필요 */ }
      };
    }

    @Override
    public BufferedReader getReader() {
      return new BufferedReader(new InputStreamReader(getInputStream(), StandardCharsets.UTF_8));
    }

    @Override
    public int getContentLength() {
      return body.length;
    }

    @Override
    public long getContentLengthLong() {
      return body.length;
    }
  }
}
