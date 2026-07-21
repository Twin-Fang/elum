# AI DLP 요청 구간 암호화 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** AI DLP 진입점 3개(`/api/routines`, `/api/routines/questions`, `/api/internal/sensitive-check`)의 요청 본문을 클라이언트에서 AES-256-GCM으로 암호화해 전송하고, 서버가 컨트롤러 이전 필터에서 복호화한다.

**Architecture:** 마스터 시크릿 1개를 클라·서버가 공유한다. 요청마다 랜덤 salt로 HKDF-SHA256 파생해 AES 키·HMAC 키를 만든다. 본문은 AES-256-GCM으로 암호화(봉투 DTO)하고, `X-Elum-Timestamp/Nonce/Signature` 헤더로 재전송을 막는다. 클라는 Dio 인터셉터, 서버는 Security 필터로 처리해 기존 컨트롤러·DTO·비즈니스 로직은 건드리지 않는다.

**Tech Stack:** 서버 — JDK 21 순수 JCA(`AES/GCM/NoPadding`, `HmacSHA256`, HKDF 수동 구현), Spring Security 필터. 클라 — Dart `cryptography` 패키지(순수 Dart, build hook 없음), Dio 인터셉터.

## Global Constraints

- 서버: `application-*.yml` **열람·수정 금지** — 시크릿은 사용자가 직접 넣는다. 키 이름은 `elum.aidlp.secret`.
- 서버: request DTO에 `jakarta.validation.constraints` 어노테이션 추가 금지.
- 서버: 모든 REST 엔드포인트 `@LogMonitoring` + `*ControllerDocs` 유지. **이번 작업은 새 엔드포인트를 만들지 않으므로** 기존 컨트롤러를 수정하지 않는다.
- 서버: 예외는 `CustomException` + `ErrorCode` + `GlobalExceptionHandler`. 단 **필터 계층 예외는 GlobalExceptionHandler가 못 잡으므로 필터가 직접 JSON 에러를 쓴다**.
- 서버: 단위테스트만. 통합테스트·curl·DB 직접 접근 금지.
- 서버 작업은 `server/` 내부만, 클라 작업은 `client/` 내부만.
- 원문·복호문을 로그에 남기지 않는다(원칙 5번).
- 클라: 환경값은 `.env` + `AppConfig` 경유, 하드코딩 금지. 디자인 토큰 규칙은 이 작업과 무관(네트워크 계층).
- 데모는 어떤 실패에도 fallback으로 끝까지 진행. 복호화/암호화 실패 시 기존 로컬 fallback 유지.
- 공유 crypto 규약(양쪽 반드시 일치):
  - HKDF-SHA256. `salt`=16바이트 랜덤, `masterSecret`=UTF-8 바이트.
  - `aesKey = HKDF(masterSecret, salt, info="elum-aes-gcm", 32B)`
  - `hmacKey = HKDF(masterSecret, salt, info="elum-hmac-sha256", 32B)`
  - AES-256-GCM, IV=12바이트 랜덤, 태그=128비트. `ciphertext`는 **암호문+태그**를 이어붙인 표준 형식(Java `Cipher` 기본 출력, Dart `SecretBox.concatenation()` 순서 = cipherText+mac, IV 제외).
  - `signingString = timestamp + "." + nonceB64 + "." + ciphertextB64`
  - `signature = base64( HMAC-SHA256(hmacKey, signingString.getBytes(UTF-8)) )`
  - 모든 바이너리는 base64(표준, 패딩 포함) 문자열로 전송.
  - timestamp 허용 오차 ±5분(300000ms). nonce는 윈도우 내 1회용.

---

## File Structure

**서버 (`server/src/main/java/com/chuseok22/elumserver/`)**
- `common/infrastructure/properties/AidlpProperties.java` (신규) — `elum.aidlp.secret` 바인딩
- `common/infrastructure/security/AidlpCryptoService.java` (신규) — HKDF·AES-GCM 복호화·HMAC 검증 순수 로직
- `common/infrastructure/security/AidlpEnvelope.java` (신규) — 봉투 파싱용 record
- `common/infrastructure/security/NonceStore.java` (신규) — 인메모리 TTL nonce 중복 차단
- `common/infrastructure/security/AidlpDecryptionFilter.java` (신규) — 대상 경로 body 복호화 + 재전송 검증 + 실패 시 직접 JSON 응답
- `common/infrastructure/exception/ErrorCode.java` (수정) — DLP 에러코드 5개 추가
- `common/infrastructure/config/SecurityConfig.java` (수정) — 필터를 JWT 필터 뒤에 등록

**서버 테스트 (`server/src/test/java/com/chuseok22/elumserver/`)**
- `common/infrastructure/security/AidlpCryptoServiceTest.java` (신규)
- `common/infrastructure/security/NonceStoreTest.java` (신규)

**클라 (`client/`)**
- `pubspec.yaml` (수정) — `cryptography` 추가
- `.env.example` (수정) — `ELUM_AIDLP_SECRET=` 문서화
- `lib/core/config/app_config.dart` (수정) — `aidlpSecret` getter
- `lib/core/security/aidlp_crypto.dart` (신규) — HKDF·AES-GCM 암호화·HMAC 서명
- `lib/core/network/encryption_interceptor.dart` (신규) — 대상 경로 body→봉투 치환 + 헤더 부착
- `lib/core/network/dio_client.dart` (수정) — 인터셉터 등록

**클라 테스트 (`client/test/`)**
- `core/security/aidlp_crypto_test.dart` (신규)
- `core/network/encryption_interceptor_test.dart` (신규)

---

## Task 1: 서버 — 시크릿 프로퍼티 바인딩

**Files:**
- Create: `server/src/main/java/com/chuseok22/elumserver/common/infrastructure/properties/AidlpProperties.java`

**Interfaces:**
- Produces: `AidlpProperties.getSecret() : String`

- [ ] **Step 1: `AidlpProperties` 작성**

```java
package com.chuseok22.elumserver.common.infrastructure.properties;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

// AI DLP 요청 암호화용 마스터 시크릿. application-dev.yml의 elum.aidlp.secret에서 온다.
// 값은 클라이언트 .env(ELUM_AIDLP_SECRET)와 동일해야 HKDF 파생 결과가 일치한다.
@Getter
@Setter
@Component
@ConfigurationProperties(prefix = "elum.aidlp")
public class AidlpProperties {

  // 미설정 시 빈 문자열. 필터는 secret이 비면 복호화를 시도하지 않고 통과시켜(데모 안전) 로컬 fallback을 유도한다.
  private String secret = "";
}
```

- [ ] **Step 2: 컴파일 확인**

Run: `cd server && ./gradlew compileJava -q`
Expected: BUILD SUCCESSFUL

- [ ] **Step 3: 커밋**

```bash
git add server/src/main/java/com/chuseok22/elumserver/common/infrastructure/properties/AidlpProperties.java
git commit -m "AI DLP 암호화 시크릿 프로퍼티 바인딩 : feat"
```

---

## Task 2: 서버 — DLP 에러코드 추가

**Files:**
- Modify: `server/src/main/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorCode.java:44-46`

**Interfaces:**
- Produces: `ErrorCode.DLP_TIMESTAMP_INVALID`, `DLP_NONCE_REPLAY`, `DLP_SIGNATURE_INVALID`, `DLP_DECRYPT_FAILED`, `DLP_ENVELOPE_INVALID` (모두 `HttpStatus.BAD_REQUEST`)

- [ ] **Step 1: enum 상수 5개 추가**

`ErrorCode.java`의 `PROMPT_TEST_GEMINI_IMAGE_FAILED(...)` 줄 다음, `;` 앞에 추가:

```java
  // AI DLP 요청 암호화 (필터 계층 — errorCode 이름이 그대로 클라 식별자가 된다)
  DLP_TIMESTAMP_INVALID(HttpStatus.BAD_REQUEST, "요청 시각이 유효하지 않습니다."),
  DLP_NONCE_REPLAY(HttpStatus.BAD_REQUEST, "이미 사용된 요청입니다."),
  DLP_SIGNATURE_INVALID(HttpStatus.BAD_REQUEST, "요청 서명이 유효하지 않습니다."),
  DLP_DECRYPT_FAILED(HttpStatus.BAD_REQUEST, "요청 복호화에 실패했습니다."),
  DLP_ENVELOPE_INVALID(HttpStatus.BAD_REQUEST, "암호화 요청 형식이 올바르지 않습니다."),
```

- [ ] **Step 2: 컴파일 확인**

Run: `cd server && ./gradlew compileJava -q`
Expected: BUILD SUCCESSFUL

- [ ] **Step 3: 커밋**

```bash
git add server/src/main/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorCode.java
git commit -m "AI DLP 복호화 실패 에러코드 5종 추가 : feat"
```

---

## Task 3: 서버 — crypto 서비스 (HKDF·AES-GCM·HMAC) + 봉투 record

**Files:**
- Create: `server/src/main/java/com/chuseok22/elumserver/common/infrastructure/security/AidlpEnvelope.java`
- Create: `server/src/main/java/com/chuseok22/elumserver/common/infrastructure/security/AidlpCryptoService.java`
- Test: `server/src/test/java/com/chuseok22/elumserver/common/infrastructure/security/AidlpCryptoServiceTest.java`

**Interfaces:**
- Consumes: `AidlpProperties.getSecret()`
- Produces:
  - `record AidlpEnvelope(String ciphertext, String iv, String salt)`
  - `AidlpCryptoService.decrypt(AidlpEnvelope env) : byte[]` — HKDF로 aesKey 파생 후 AES-GCM 복호화한 평문 바이트. 실패 시 `CustomException(DLP_DECRYPT_FAILED)`.
  - `AidlpCryptoService.verifySignature(String timestamp, String nonceB64, String ciphertextB64, String saltB64, String signatureB64) : boolean` — HKDF로 hmacKey 파생 후 상수시간 비교.
  - `AidlpCryptoService.deriveKey(byte[] salt, String info) : byte[]` (package-private, 테스트용)

- [ ] **Step 1: 봉투 record 작성**

```java
package com.chuseok22.elumserver.common.infrastructure.security;

// 클라이언트가 보내는 암호문 봉투. 요청 본문은 {"encrypted":{ciphertext,iv,salt}} 형태다.
public record AidlpEnvelope(String ciphertext, String iv, String salt) {

  public boolean isComplete() {
    return ciphertext != null && !ciphertext.isBlank()
      && iv != null && !iv.isBlank()
      && salt != null && !salt.isBlank();
  }
}
```

- [ ] **Step 2: 실패하는 테스트 먼저 작성**

`AidlpCryptoServiceTest.java` — HKDF 파생이 고정 벡터와 일치하는지(양쪽 규약 고정), AES-GCM 왕복, HMAC 검증을 확인한다. crypto는 결정적이므로 서비스가 자체 암호화한 결과를 자기 복호화로 왕복 검증한다(클라 없이도 규약 자기정합성 보장).

```java
package com.chuseok22.elumserver.common.infrastructure.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.properties.AidlpProperties;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Base64;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class AidlpCryptoServiceTest {

  private AidlpCryptoService service;
  private final SecureRandom random = new SecureRandom();

  @BeforeEach
  void setUp() {
    AidlpProperties props = new AidlpProperties();
    props.setSecret("test-master-secret-32bytes-minimum!!"); // 테스트 전용 값
    service = new AidlpCryptoService(props);
  }

  // 클라이언트가 만들 봉투를 서버가 복호화할 수 있는지를, 서버가 동일 규약으로 만든 봉투로 검증한다.
  @Test
  void aesGcm_왕복_복호화() throws Exception {
    byte[] salt = randomBytes(16);
    byte[] iv = randomBytes(12);
    byte[] plain = "홍길동 010-1234-5678".getBytes(StandardCharsets.UTF_8);

    byte[] aesKey = service.deriveKey(salt, "elum-aes-gcm");
    Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
    cipher.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(aesKey, "AES"), new GCMParameterSpec(128, iv));
    byte[] ct = cipher.doFinal(plain); // 암호문+태그

    AidlpEnvelope env = new AidlpEnvelope(b64(ct), b64(iv), b64(salt));
    byte[] decrypted = service.decrypt(env);

    assertThat(new String(decrypted, StandardCharsets.UTF_8)).isEqualTo("홍길동 010-1234-5678");
  }

  @Test
  void 잘못된_태그면_복호화_실패() {
    byte[] salt = randomBytes(16);
    byte[] iv = randomBytes(12);
    AidlpEnvelope env = new AidlpEnvelope(b64("corrupted".getBytes()), b64(iv), b64(salt));

    assertThatThrownBy(() -> service.decrypt(env))
      .isInstanceOf(CustomException.class);
  }

  @Test
  void HMAC_서명_검증_성공과_실패() {
    byte[] salt = randomBytes(16);
    String ts = "1700000000000";
    String nonce = b64(randomBytes(16));
    String ctB64 = b64(randomBytes(40));

    byte[] hmacKey = service.deriveKey(salt, "elum-hmac-sha256");
    String signing = ts + "." + nonce + "." + ctB64;
    String sig = b64(hmacSha256(hmacKey, signing.getBytes(StandardCharsets.UTF_8)));

    assertThat(service.verifySignature(ts, nonce, ctB64, b64(salt), sig)).isTrue();
    assertThat(service.verifySignature(ts, nonce, ctB64, b64(salt), b64("wrong".getBytes()))).isFalse();
  }

  private byte[] randomBytes(int n) {
    byte[] b = new byte[n];
    random.nextBytes(b);
    return b;
  }

  private static String b64(byte[] b) {
    return Base64.getEncoder().encodeToString(b);
  }

  private static byte[] hmacSha256(byte[] key, byte[] data) {
    try {
      javax.crypto.Mac mac = javax.crypto.Mac.getInstance("HmacSHA256");
      mac.init(new SecretKeySpec(key, "HmacSHA256"));
      return mac.doFinal(data);
    } catch (Exception e) {
      throw new RuntimeException(e);
    }
  }
}
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `cd server && ./gradlew test --tests "*AidlpCryptoServiceTest" -q`
Expected: FAIL (AidlpCryptoService 미존재로 컴파일 에러)

- [ ] **Step 4: `AidlpCryptoService` 구현**

```java
package com.chuseok22.elumserver.common.infrastructure.security;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.AidlpProperties;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.Base64;
import javax.crypto.Cipher;
import javax.crypto.Mac;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

// AI DLP 요청 암호화의 순수 crypto 로직. HKDF-SHA256으로 마스터 시크릿에서 요청별 키를 파생하고,
// AES-256-GCM 복호화와 HMAC-SHA256 서명 검증을 담당한다. 클라이언트와 규약(info 라벨·바이트 순서)을 맞춘다.
@Service
@RequiredArgsConstructor
public class AidlpCryptoService {

  private static final int GCM_TAG_BITS = 128;
  private static final Base64.Decoder B64_DEC = Base64.getDecoder();

  private final AidlpProperties properties;

  // 봉투를 AES-256-GCM으로 복호화해 평문 바이트를 돌려준다. 태그 불일치·형식 오류는 DLP_DECRYPT_FAILED.
  public byte[] decrypt(AidlpEnvelope env) {
    try {
      byte[] salt = B64_DEC.decode(env.salt());
      byte[] iv = B64_DEC.decode(env.iv());
      byte[] ct = B64_DEC.decode(env.ciphertext()); // 암호문+태그
      byte[] aesKey = deriveKey(salt, "elum-aes-gcm");

      Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
      cipher.init(Cipher.DECRYPT_MODE, new SecretKeySpec(aesKey, "AES"), new GCMParameterSpec(GCM_TAG_BITS, iv));
      return cipher.doFinal(ct);
    } catch (Exception e) {
      // 원문·키를 로그에 남기지 않는다. 실패 사실만 던진다.
      throw new CustomException(ErrorCode.DLP_DECRYPT_FAILED);
    }
  }

  // timestamp.nonce.ciphertext를 HMAC-SHA256으로 서명한 값과 상수시간 비교한다.
  public boolean verifySignature(String timestamp, String nonceB64, String ciphertextB64,
    String saltB64, String signatureB64) {
    try {
      byte[] salt = B64_DEC.decode(saltB64);
      byte[] hmacKey = deriveKey(salt, "elum-hmac-sha256");
      String signing = timestamp + "." + nonceB64 + "." + ciphertextB64;
      byte[] expected = hmac(hmacKey, signing.getBytes(StandardCharsets.UTF_8));
      byte[] actual = B64_DEC.decode(signatureB64);
      return MessageDigest.isEqual(expected, actual); // 상수시간 비교
    } catch (Exception e) {
      return false;
    }
  }

  // HKDF-SHA256(RFC 5869). Extract(salt, ikm) → Expand(prk, info, 32B). 단일 블록(L<=32)만 필요하다.
  byte[] deriveKey(byte[] salt, String info) {
    try {
      byte[] ikm = properties.getSecret().getBytes(StandardCharsets.UTF_8);
      byte[] prk = hmac(salt, ikm); // Extract
      // Expand: T(1) = HMAC(prk, info || 0x01)
      byte[] infoBytes = info.getBytes(StandardCharsets.UTF_8);
      byte[] input = Arrays.copyOf(infoBytes, infoBytes.length + 1);
      input[infoBytes.length] = 0x01;
      byte[] t1 = hmac(prk, input);
      return Arrays.copyOf(t1, 32); // AES-256 / HMAC-SHA256 키 모두 32B
    } catch (Exception e) {
      throw new CustomException(ErrorCode.DLP_DECRYPT_FAILED);
    }
  }

  private byte[] hmac(byte[] key, byte[] data) throws Exception {
    Mac mac = Mac.getInstance("HmacSHA256");
    mac.init(new SecretKeySpec(key, "HmacSHA256"));
    return mac.doFinal(data);
  }
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `cd server && ./gradlew test --tests "*AidlpCryptoServiceTest" -q`
Expected: PASS (3 tests)

- [ ] **Step 6: 커밋**

```bash
git add server/src/main/java/com/chuseok22/elumserver/common/infrastructure/security/AidlpEnvelope.java \
        server/src/main/java/com/chuseok22/elumserver/common/infrastructure/security/AidlpCryptoService.java \
        server/src/test/java/com/chuseok22/elumserver/common/infrastructure/security/AidlpCryptoServiceTest.java
git commit -m "AI DLP crypto 서비스(HKDF·AES-GCM·HMAC) + 왕복 테스트 : feat"
```

---

## Task 4: 서버 — nonce 중복 차단 저장소

**Files:**
- Create: `server/src/main/java/com/chuseok22/elumserver/common/infrastructure/security/NonceStore.java`
- Test: `server/src/test/java/com/chuseok22/elumserver/common/infrastructure/security/NonceStoreTest.java`

**Interfaces:**
- Produces: `NonceStore.checkAndRemember(String nonce, long nowMillis) : boolean` — 처음 보는 nonce면 기억하고 `true`, 이미 있으면 `false`. TTL(10분) 지난 항목은 청소.

- [ ] **Step 1: 실패하는 테스트 작성**

```java
package com.chuseok22.elumserver.common.infrastructure.security;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class NonceStoreTest {

  @Test
  void 처음_보는_nonce는_통과_재사용은_차단() {
    NonceStore store = new NonceStore();
    long now = 1_700_000_000_000L;

    assertThat(store.checkAndRemember("abc", now)).isTrue();   // 최초
    assertThat(store.checkAndRemember("abc", now)).isFalse();  // 재사용
    assertThat(store.checkAndRemember("def", now)).isTrue();   // 다른 값
  }

  @Test
  void TTL_지난_nonce는_다시_통과() {
    NonceStore store = new NonceStore();
    long t0 = 1_700_000_000_000L;

    assertThat(store.checkAndRemember("abc", t0)).isTrue();
    // 11분 뒤: 이전 항목이 만료되어 다시 통과해야 한다
    long later = t0 + 11 * 60 * 1000L;
    assertThat(store.checkAndRemember("abc", later)).isTrue();
  }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd server && ./gradlew test --tests "*NonceStoreTest" -q`
Expected: FAIL (NonceStore 미존재)

- [ ] **Step 3: `NonceStore` 구현**

```java
package com.chuseok22.elumserver.common.infrastructure.security;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Component;

// 재전송 방지용 nonce 저장소. 단일 인스턴스 데모 기준 인메모리로 충분하다.
// 각 nonce의 최초 수신 시각을 기억하고, TTL(10분)이 지난 항목은 새 요청이 올 때 청소한다.
@Component
public class NonceStore {

  private static final long TTL_MILLIS = 10 * 60 * 1000L; // timestamp 허용오차(±5분)보다 넉넉히

  private final Map<String, Long> seen = new ConcurrentHashMap<>();

  // 처음 보는 nonce면 기억하고 true, 이미 유효 범위 내에서 본 적 있으면 false.
  public synchronized boolean checkAndRemember(String nonce, long nowMillis) {
    evictExpired(nowMillis);
    Long prev = seen.get(nonce);
    if (prev != null && nowMillis - prev < TTL_MILLIS) {
      return false; // 재사용
    }
    seen.put(nonce, nowMillis);
    return true;
  }

  private void evictExpired(long nowMillis) {
    seen.entrySet().removeIf(e -> nowMillis - e.getValue() >= TTL_MILLIS);
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd server && ./gradlew test --tests "*NonceStoreTest" -q`
Expected: PASS (2 tests)

- [ ] **Step 5: 커밋**

```bash
git add server/src/main/java/com/chuseok22/elumserver/common/infrastructure/security/NonceStore.java \
        server/src/test/java/com/chuseok22/elumserver/common/infrastructure/security/NonceStoreTest.java
git commit -m "AI DLP 재전송 방지 nonce 저장소 : feat"
```

---

## Task 5: 서버 — 복호화 필터 + SecurityConfig 등록

**Files:**
- Create: `server/src/main/java/com/chuseok22/elumserver/common/infrastructure/security/AidlpDecryptionFilter.java`
- Modify: `server/src/main/java/com/chuseok22/elumserver/common/infrastructure/config/SecurityConfig.java:100-116` (apiSecurityFilterChain의 addFilterBefore 부근)

**Interfaces:**
- Consumes: `AidlpCryptoService`, `NonceStore`, `AidlpProperties`, `ObjectMapper`
- Produces: `AidlpDecryptionFilter extends OncePerRequestFilter` (Spring 빈). 대상 3경로 POST 요청에만 동작.

**동작:** 대상 경로가 아니면 통과(`shouldNotFilter`). secret이 비면 통과(데모 안전). 봉투 파싱 → timestamp·nonce·HMAC 검증 → 복호화 → 평문 JSON으로 body 교체한 wrapper를 다음 필터로 전달. 실패 시 각 에러코드로 **직접 JSON 응답**(400)을 쓰고 체인 중단(GlobalExceptionHandler는 필터 예외를 못 잡으므로).

- [ ] **Step 1: 필터 구현**

```java
package com.chuseok22.elumserver.common.infrastructure.security;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ReadListener;
import jakarta.servlet.ServletInputStream;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
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
  private final ObjectMapper objectMapper;

  @Override
  protected boolean shouldNotFilter(HttpServletRequest request) {
    // 정확 경로 매칭 + POST 만 대상. secret 미설정이면 복호화 자체를 건너뛴다(데모 안전 — 로컬 fallback 유도).
    boolean isTarget = HttpMethod.POST.matches(request.getMethod())
      && TARGET_PATHS.contains(request.getRequestURI());
    return !isTarget || properties.getSecret().isBlank();
  }

  @Override
  protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
    throws IOException, jakarta.servlet.ServletException {

    // 1) 봉투 파싱
    JsonNode root;
    try {
      root = objectMapper.readTree(request.getInputStream());
    } catch (Exception e) {
      writeError(response, ErrorCode.DLP_ENVELOPE_INVALID);
      return;
    }
    JsonNode enc = root.get("encrypted");
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
      java.util.Map.of("errorCode", code.name(), "errorMessage", code.getMessage()));
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
    public java.io.BufferedReader getReader() {
      return new java.io.BufferedReader(new java.io.InputStreamReader(getInputStream(), StandardCharsets.UTF_8));
    }

    @Override
    public int getContentLength() { return body.length; }

    @Override
    public long getContentLengthLong() { return body.length; }
  }
}
```

- [ ] **Step 2: SecurityConfig에 필터 등록**

`apiSecurityFilterChain`에서 JWT 필터 뒤에 DLP 필터를 추가한다. 먼저 필드/생성자에 `AidlpDecryptionFilter`를 주입한다.

`SecurityConfig` 필드 추가(기존 필드 블록 끝):
```java
  private final AidlpDecryptionFilter aidlpDecryptionFilter;
```

생성자 파라미터 추가 + 대입(기존 생성자):
```java
    AidlpDecryptionFilter aidlpDecryptionFilter
```
```java
    this.aidlpDecryptionFilter = aidlpDecryptionFilter;
```
> import 추가: `import com.chuseok22.elumserver.common.infrastructure.security.AidlpDecryptionFilter;`

`apiSecurityFilterChain`의 `.addFilterBefore(jwtAuthenticationFilter, ...)` 다음 줄에 체이닝:
```java
      .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class)
      // JWT 인증 이후 실행 — 인증된 요청의 암호화 본문을 복호화해 컨트롤러에 평문 DTO로 넘긴다.
      .addFilterAfter(aidlpDecryptionFilter, JwtAuthenticationFilter.class);
```
> `sensitive-check`는 인증 대상이므로 JWT 필터 뒤 실행이 안전하다. `API_AUTH_MATCHER`(permitAll)에 이 경로가 포함되는지는 구현 시 `SecurityPaths`를 열어 확인하고, permitAll이면 순서 무관하게 동작한다.

- [ ] **Step 3: 전체 컴파일 + 기존 테스트 유지 확인**

Run: `cd server && ./gradlew compileJava test -q`
Expected: BUILD SUCCESSFUL (기존 테스트 + 신규 crypto/nonce 테스트 통과)

- [ ] **Step 4: 커밋**

```bash
git add server/src/main/java/com/chuseok22/elumserver/common/infrastructure/security/AidlpDecryptionFilter.java \
        server/src/main/java/com/chuseok22/elumserver/common/infrastructure/config/SecurityConfig.java
git commit -m "AI DLP 복호화 필터 + SecurityConfig 등록 : feat"
```

---

## Task 6: 클라 — cryptography 패키지 + AppConfig 시크릿

**Files:**
- Modify: `client/pubspec.yaml` (dependencies)
- Modify: `client/.env.example`
- Modify: `client/lib/core/config/app_config.dart`

**Interfaces:**
- Produces: `AppConfig.aidlpSecret : String` (기본값 빈 문자열)

- [ ] **Step 1: `cryptography` 의존성 추가**

Run: `cd client && flutter pub add cryptography`
Expected: pubspec.yaml에 `cryptography: ^2.x` 추가, `flutter pub get` 성공
> 실패 시(analyzer 충돌 등) 계획을 멈추고 사용자에게 보고한다. 대안은 `pointycastle` 직접 사용.

- [ ] **Step 2: `.env.example`에 키 문서화**

`client/.env.example`에 추가:
```
# AI DLP 요청 암호화 마스터 시크릿 (서버 application-dev.yml의 elum.aidlp.secret와 동일 값)
# 비어 있으면 클라가 암호화하지 않고 평문 전송 → 서버도 통과(데모 안전).
ELUM_AIDLP_SECRET=
```

- [ ] **Step 3: `AppConfig`에 getter 추가**

`app_config.dart`의 기존 `_string`/유사 헬퍼 패턴을 따라 추가(기본값 빈 문자열):
```dart
  // AI DLP 요청 암호화 마스터 시크릿. 비면 암호화를 건너뛴다(평문 전송 → 서버 통과).
  static String get aidlpSecret => _string('ELUM_AIDLP_SECRET', '');
```
> `_string` 헬퍼 이름이 다르면(`_env` 등) 파일을 열어 실제 헬퍼명에 맞춘다.

- [ ] **Step 4: analyze 확인**

Run: `cd client && flutter analyze lib/core/config/app_config.dart`
Expected: No issues

- [ ] **Step 5: 커밋**

```bash
git add client/pubspec.yaml client/pubspec.lock client/.env.example client/lib/core/config/app_config.dart
git commit -m "AI DLP 암호화 의존성·시크릿 설정 : feat"
```

---

## Task 7: 클라 — crypto 유틸 (HKDF·AES-GCM·HMAC)

**Files:**
- Create: `client/lib/core/security/aidlp_crypto.dart`
- Test: `client/test/core/security/aidlp_crypto_test.dart`

**Interfaces:**
- Produces:
  - `class AidlpEnvelope { final String ciphertext, iv, salt; }`
  - `class AidlpSealed { final AidlpEnvelope envelope; final String timestamp, nonce, signature; }`
  - `Future<AidlpSealed> AidlpCrypto.seal(String plaintextJson, {required String secret})` — salt·iv·nonce 생성, HKDF 파생, AES-GCM 암호화, HMAC 서명까지.
  - `Future<List<int>> AidlpCrypto.deriveKey(List<int> salt, String info, String secret)` (테스트용 노출)

- [ ] **Step 1: 실패하는 테스트 작성**

crypto는 결정적이지 않은 부분(salt/iv/nonce 랜덤)이 있으므로, **왕복 복호화**로 규약을 검증한다. `cryptography` 패키지의 복호화를 테스트에서 직접 호출해 seal 결과를 되푼다.

```dart
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elum/core/security/aidlp_crypto.dart';

void main() {
  const secret = 'test-master-secret-32bytes-minimum!!';

  test('seal한 봉투를 같은 규약으로 복호화하면 원문이 나온다', () async {
    const plain = '{"rawInputText":"홍길동 010-1234-5678"}';
    final sealed = await AidlpCrypto.seal(plain, secret: secret);

    // 같은 salt로 aesKey 재파생 → AES-GCM 복호화
    final salt = base64.decode(sealed.envelope.salt);
    final iv = base64.decode(sealed.envelope.iv);
    final ct = base64.decode(sealed.envelope.ciphertext); // cipherText+mac
    final aesKey = await AidlpCrypto.deriveKey(salt, 'elum-aes-gcm', secret);

    final algo = AesGcm.with256bits();
    final mac = ct.sublist(ct.length - 16);
    final cipherText = ct.sublist(0, ct.length - 16);
    final clear = await algo.decrypt(
      SecretBox(cipherText, nonce: iv, mac: Mac(mac)),
      secretKey: SecretKey(aesKey),
    );
    expect(utf8.decode(clear), plain);
  });

  test('HMAC 서명이 timestamp.nonce.ciphertext 규약을 따른다', () async {
    const plain = '{"text":"주민번호 900101-1234567"}';
    final sealed = await AidlpCrypto.seal(plain, secret: secret);

    final salt = base64.decode(sealed.envelope.salt);
    final hmacKey = await AidlpCrypto.deriveKey(salt, 'elum-hmac-sha256', secret);
    final signing = '${sealed.timestamp}.${sealed.nonce}.${sealed.envelope.ciphertext}';
    final hmac = Hmac.sha256();
    final expected = await hmac.calculateMac(
      utf8.encode(signing),
      secretKey: SecretKey(hmacKey),
    );
    expect(sealed.signature, base64.encode(expected.bytes));
  });

  test('같은 원문도 매번 다른 암호문을 만든다(salt/iv 랜덤)', () async {
    const plain = '{"text":"동일 입력"}';
    final a = await AidlpCrypto.seal(plain, secret: secret);
    final b = await AidlpCrypto.seal(plain, secret: secret);
    expect(a.envelope.ciphertext, isNot(b.envelope.ciphertext));
    expect(a.envelope.salt, isNot(b.envelope.salt));
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd client && flutter test test/core/security/aidlp_crypto_test.dart`
Expected: FAIL (aidlp_crypto.dart 미존재)

- [ ] **Step 3: `aidlp_crypto.dart` 구현**

```dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// 서버로 보낼 암호문 봉투. 요청 본문의 `encrypted` 필드가 된다.
class AidlpEnvelope {
  const AidlpEnvelope({required this.ciphertext, required this.iv, required this.salt});
  final String ciphertext; // base64(cipherText+mac) — 서버 Java Cipher 출력과 동일 순서
  final String iv;         // base64(12바이트 GCM nonce)
  final String salt;       // base64(16바이트 HKDF salt)

  Map<String, dynamic> toJson() => {'ciphertext': ciphertext, 'iv': iv, 'salt': salt};
}

/// 봉투 + 재전송 방지 헤더 값 묶음.
class AidlpSealed {
  const AidlpSealed({
    required this.envelope,
    required this.timestamp,
    required this.nonce,
    required this.signature,
  });
  final AidlpEnvelope envelope;
  final String timestamp; // epoch millis
  final String nonce;     // base64(16바이트)
  final String signature; // base64(HMAC-SHA256)
}

/// AI DLP 요청 암호화. 서버 AidlpCryptoService와 규약(HKDF info 라벨·바이트 순서·서명 문자열)을 맞춘다.
abstract final class AidlpCrypto {
  static final Random _random = Random.secure();

  /// 평문 JSON을 AES-256-GCM으로 봉인하고 HMAC 서명까지 만든다.
  static Future<AidlpSealed> seal(String plaintextJson, {required String secret}) async {
    final salt = _randomBytes(16);
    final iv = _randomBytes(12);
    final nonce = _randomBytes(16);

    final aesKey = await deriveKey(salt, 'elum-aes-gcm', secret);
    final algo = AesGcm.with256bits();
    final box = await algo.encrypt(
      utf8.encode(plaintextJson),
      secretKey: SecretKey(aesKey),
      nonce: iv,
    );
    // 서버는 cipherText+tag를 하나로 받는다 → concatenation 순서(cipherText + mac).
    final ct = <int>[...box.cipherText, ...box.mac.bytes];

    final ctB64 = base64.encode(ct);
    final ivB64 = base64.encode(iv);
    final saltB64 = base64.encode(salt);
    final nonceB64 = base64.encode(nonce);
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    final hmacKey = await deriveKey(salt, 'elum-hmac-sha256', secret);
    final signing = '$timestamp.$nonceB64.$ctB64';
    final sigMac = await Hmac.sha256().calculateMac(
      utf8.encode(signing),
      secretKey: SecretKey(hmacKey),
    );

    return AidlpSealed(
      envelope: AidlpEnvelope(ciphertext: ctB64, iv: ivB64, salt: saltB64),
      timestamp: timestamp,
      nonce: nonceB64,
      signature: base64.encode(sigMac.bytes),
    );
  }

  /// HKDF-SHA256(RFC 5869) 단일 블록. Extract(salt, secret) → Expand(prk, info, 32B).
  static Future<List<int>> deriveKey(List<int> salt, String info, String secret) async {
    final hmac = Hmac.sha256();
    // Extract
    final prk = await hmac.calculateMac(utf8.encode(secret), secretKey: SecretKey(salt));
    // Expand: T(1) = HMAC(prk, info || 0x01)
    final input = <int>[...utf8.encode(info), 0x01];
    final t1 = await hmac.calculateMac(input, secretKey: SecretKey(prk.bytes));
    return t1.bytes.sublist(0, 32);
  }

  static Uint8List _randomBytes(int n) {
    final b = Uint8List(n);
    for (var i = 0; i < n; i++) {
      b[i] = _random.nextInt(256);
    }
    return b;
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd client && flutter test test/core/security/aidlp_crypto_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: 커밋**

```bash
git add client/lib/core/security/aidlp_crypto.dart client/test/core/security/aidlp_crypto_test.dart
git commit -m "클라 AI DLP crypto 유틸(HKDF·AES-GCM·HMAC) + 왕복 테스트 : feat"
```

---

## Task 8: 클라 — 암호화 인터셉터 + Dio 등록

**Files:**
- Create: `client/lib/core/network/encryption_interceptor.dart`
- Modify: `client/lib/core/network/dio_client.dart:36-54` (dioProvider 인터셉터 등록부)
- Test: `client/test/core/network/encryption_interceptor_test.dart`

**Interfaces:**
- Consumes: `AidlpCrypto.seal`, `AppConfig.aidlpSecret`
- Produces: `class EncryptionInterceptor extends Interceptor` — 대상 3경로 POST 요청의 `data`(Map)를 봉투로 치환하고 헤더 3개 부착. 그 외 요청·secret 빈 경우·data가 Map 아닌 경우는 그대로 통과.

- [ ] **Step 1: 실패하는 테스트 작성**

인터셉터가 대상 경로만 변형하고 헤더를 붙이는지 검증한다. `onRequest`를 직접 호출해 `RequestOptions`가 봉투로 바뀌었는지 본다.

```dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elum/core/network/encryption_interceptor.dart';

void main() {
  const secret = 'test-master-secret-32bytes-minimum!!';

  Future<RequestOptions> runInterceptor(RequestOptions options) async {
    final interceptor = EncryptionInterceptor(secret: secret);
    final completer = Completer<RequestOptions>();
    interceptor.onRequest(
      options,
      RequestInterceptorHandler()..._; // 아래 구현에서 handler.next(options) 캡처
    );
    // 핸들러 캡처 방식은 구현 시 InterceptorsWrapper 또는 실제 Dio로 대체한다.
    return completer.future;
  }

  test('대상 경로 요청은 봉투로 치환되고 헤더가 붙는다', () async {
    // 실제로는 Dio에 인터셉터를 달고 MockAdapter로 최종 RequestOptions를 관찰하는 방식을 쓴다.
    final dio = Dio(BaseOptions(baseUrl: 'https://x'));
    late RequestOptions captured;
    dio.interceptors.add(EncryptionInterceptor(secret: secret));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      captured = o;
      h.reject(DioException(requestOptions: o)); // 실제 전송 막고 관찰만
    }));

    try {
      await dio.post('/api/routines', data: {'rawInputText': '홍길동'});
    } catch (_) {}

    expect(captured.data, isA<Map>());
    expect((captured.data as Map).containsKey('encrypted'), isTrue);
    expect(captured.headers['X-Elum-Timestamp'], isNotNull);
    expect(captured.headers['X-Elum-Nonce'], isNotNull);
    expect(captured.headers['X-Elum-Signature'], isNotNull);
  });

  test('대상이 아닌 경로는 그대로 통과한다', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://x'));
    late RequestOptions captured;
    dio.interceptors.add(EncryptionInterceptor(secret: secret));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      captured = o;
      h.reject(DioException(requestOptions: o));
    }));

    try {
      await dio.get('/api/member/me');
    } catch (_) {}

    expect(captured.headers.containsKey('X-Elum-Signature'), isFalse);
  });

  test('secret이 비면 대상 경로도 그대로 통과한다', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://x'));
    late RequestOptions captured;
    dio.interceptors.add(EncryptionInterceptor(secret: ''));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      captured = o;
      h.reject(DioException(requestOptions: o));
    }));

    try {
      await dio.post('/api/routines', data: {'rawInputText': '홍길동'});
    } catch (_) {}

    expect((captured.data as Map).containsKey('encrypted'), isFalse);
  });
}
```
> 첫 테스트의 `runInterceptor` 스텁은 구현 참고용이다. 실제 테스트는 위 3개(Dio+InterceptorsWrapper 관찰)만 남기고 `runInterceptor`/`Completer` 잔재는 지운다. `import 'dart:async';` 추가.

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd client && flutter test test/core/network/encryption_interceptor_test.dart`
Expected: FAIL (EncryptionInterceptor 미존재)

- [ ] **Step 3: 인터셉터 구현**

```dart
import 'dart:convert';

import 'package:dio/dio.dart';

import '../security/aidlp_crypto.dart';

/// AI DLP 진입점 요청 본문을 AES-GCM으로 암호화해 전송한다.
///
/// 대상 3경로의 POST 요청만 봉투로 치환하고 재전송 방지 헤더를 붙인다.
/// secret이 비었거나 대상이 아니면 요청을 그대로 흘려보낸다(평문 → 서버도 통과, 데모 안전).
class EncryptionInterceptor extends Interceptor {
  EncryptionInterceptor({required String secret}) : _secret = secret;

  final String _secret;

  // 정확히 이 경로의 POST만 암호화한다. baseUrl을 뺀 path 기준.
  static const _targetPaths = {
    '/api/routines',
    '/api/routines/questions',
    '/api/internal/sensitive-check',
  };

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final isTarget = options.method.toUpperCase() == 'POST' && _targetPaths.contains(options.path);
    if (!isTarget || _secret.isEmpty || options.data is! Map) {
      handler.next(options); // 그대로 통과
      return;
    }

    try {
      final plaintext = jsonEncode(options.data);
      final sealed = await AidlpCrypto.seal(plaintext, secret: _secret);
      options.data = {'encrypted': sealed.envelope.toJson()};
      options.headers['X-Elum-Timestamp'] = sealed.timestamp;
      options.headers['X-Elum-Nonce'] = sealed.nonce;
      options.headers['X-Elum-Signature'] = sealed.signature;
      handler.next(options);
    } catch (_) {
      // 암호화 실패해도 데모를 막지 않는다 — 평문 그대로 보내 서버 fallback/로컬 fallback에 맡긴다.
      handler.next(options);
    }
  }
}
```

- [ ] **Step 4: Dio에 인터셉터 등록**

`dio_client.dart`의 `dioProvider`에서 **AuthInterceptor 뒤, 로깅 앞**에 등록. body가 봉투로 바뀐 뒤 로깅되도록(원문이 로그에 안 남도록) 로깅보다 먼저 실행되게 한다.

```dart
import '../security/... ' // 불필요, 아래 import만 추가
```
`dio_client.dart` 상단 import에 추가:
```dart
import 'encryption_interceptor.dart';
import '../config/app_config.dart'; // 이미 있으면 생략
```
`dioProvider` 안, `dio.interceptors.add(AuthInterceptor(...))` 다음에:
```dart
  // 암호화는 인증 헤더가 붙은 뒤, 로깅보다 먼저 — 봉투로 바뀐 본문만 로그에 남게 한다.
  dio.interceptors.add(EncryptionInterceptor(secret: AppConfig.aidlpSecret));
```
> `DioClient.create()`가 로깅 인터셉터를 이미 add한 상태이므로, 순서상 로깅이 먼저 등록돼 있으면 로깅이 원문을 찍을 수 있다. 이 경우 `SafeLogInterceptor` 자체가 이미 body를 민감 취급(원문 비로깅)하는지 `dio_client.dart`를 열어 확인하고, 아니면 암호화 인터셉터를 `DioClient.create()` 내부의 로깅 등록 **앞**으로 옮긴다.

- [ ] **Step 5: 테스트 + analyze 통과 확인**

Run: `cd client && flutter test test/core/network/encryption_interceptor_test.dart && flutter analyze lib/core/network/ lib/core/security/`
Expected: PASS (3 tests), No issues

- [ ] **Step 6: 커밋**

```bash
git add client/lib/core/network/encryption_interceptor.dart \
        client/lib/core/network/dio_client.dart \
        client/test/core/network/encryption_interceptor_test.dart
git commit -m "클라 AI DLP 암호화 인터셉터 + Dio 등록 : feat"
```

---

## Task 9: 최종 검증 — 전체 테스트

**Files:** 없음(검증만)

- [ ] **Step 1: 서버 전체 테스트**

Run: `cd server && ./gradlew test -q`
Expected: BUILD SUCCESSFUL (기존 + 신규 전부 통과)

- [ ] **Step 2: 클라 전체 테스트 + analyze**

Run: `cd client && flutter test && flutter analyze`
Expected: All tests passed, No issues (기존 경고 수준 유지)

- [ ] **Step 3: 규약 일치 최종 점검(수동 리뷰)**

아래 4가지가 서버·클라에서 문자 그대로 일치하는지 두 파일을 나란히 놓고 확인:
- HKDF info 라벨: `elum-aes-gcm`, `elum-hmac-sha256`
- salt/iv/nonce 바이트 길이: 16/12/16
- ciphertext 순서: cipherText + mac(tag)
- signingString: `timestamp + "." + nonce + "." + ciphertext(base64)`

불일치가 하나라도 있으면 서버가 조용히 복호화 실패 → fallback으로 빠져 증상이 안 보인다.

- [ ] **Step 4: 시크릿 설정 안내(사용자 작업)**

구현 완료 후 사용자에게 아래를 안내한다(직접 하지 않음):
- 서버 `application-dev.yml`에 `elum.aidlp.secret: <32바이트+ 랜덤>` 추가
- 클라 `.env`에 `ELUM_AIDLP_SECRET=<동일 값>` 추가
- 배포 시 GitHub Secret `CLIENT_ENV_FILE` 갱신(배포 전)
- 두 값이 **동일**해야 함. 다르면 전부 복호화 실패 → 로컬 fallback

---

## Self-Review (작성자 점검 완료)

**Spec 커버리지:**
- §2 범위 3경로 → Task 5 `TARGET_PATHS`, Task 8 `_targetPaths` ✅
- §3 AES-GCM/HKDF/HMAC → Task 3, 7 ✅
- §4 봉투·헤더 포맷 → Task 3(봉투), 5(헤더 검증), 7·8(생성) ✅
- §5 HKDF info 분리 → Task 3·7 `deriveKey` ✅
- §6 인터셉터/필터 구조 → Task 5, 8 ✅
- §7 실패 경로 5종 에러코드 + fallback → Task 2, 5(직접 JSON 응답), 8(암호화 실패 통과) ✅
- §8 테스트 → Task 3,4,7,8 왕복·규약 테스트 ✅
- §9 시크릿 사용자 주입 → Task 1(빈 기본값), Task 9 Step 4 안내 ✅

**Placeholder 스캔:** 코드 스텝은 전부 실제 코드 포함. Task 8 Step 1의 `runInterceptor` 스텁만 "구현 참고용"으로 명시하고 실제 테스트 3개로 대체하도록 지시함(의도된 안내). ✅

**타입 일관성:** `AidlpEnvelope(ciphertext, iv, salt)` — 서버 record·클라 class 필드명 일치. `deriveKey(salt, info, secret)` 시그니처 양쪽 일치. `seal`/`decrypt`/`verifySignature` 이름 태스크 간 일관. ✅

**알려진 확인 필요(구현 중 파일 열어 맞출 것):**
- `AppConfig`의 env 헬퍼 실제 이름(`_string` 가정) — Task 6 Step 3
- `SecurityPaths.API_AUTH_MATCHER`에 `sensitive-check` 포함 여부 — Task 5 Step 2
- `DioClient.create()`의 로깅 인터셉터 등록 순서 vs 원문 로깅 여부 — Task 8 Step 4
