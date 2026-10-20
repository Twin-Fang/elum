# 보호자 닉네임 변경 서버 API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 보호자가 자기 닉네임을 바꾸는 `PATCH /api/member/account/nickname` (형식 · 예약어 · 욕설 · 7일 주기 · 중복 검사)

**Architecture:** 판정은 순수 클래스 `NicknamePolicy`(member/core)가 하고, 단어 목록은 리소스 파일에서 한 번 읽는다. 변경 흐름은 기존 `MemberNicknameService` 에 더하고, `MemberService` 가 응답을 만든다.

**Tech Stack:** Spring Boot, JPA, Flyway, JUnit5 + Mockito + AssertJ

**Spec:** `docs/superpowers/specs/2026-10-20-guardian-nickname-change-server-design.md`

## Global Constraints

- 길이 2~16자(앞뒤 공백 제거 후), 허용: 한글 완성형 · 영문 · 숫자 · `-`
- 변경 주기 7일, `nicknameChangedAt == null` 이면 제한 없음, 현재와 같은 이름은 변경 없음 200
- 중복은 대소문자 무시(`existsByNicknameIgnoreCaseAndIdNot`), 저장은 입력 모양 그대로
- 욕설·예약어 거절은 `NICKNAME_NOT_ALLOWED` 하나, 걸린 단어를 응답·로그에 남기지 않음
- 로그는 영어, 접두사 `[member nickname]`, 원문 닉네임 금지
- 문구 5개 언어(ko/en/ja/zh/es), ko 는 해요체. 골든 `error-messages-ko.json` 함께 갱신
- 마이그레이션은 develop 최신 V 다음 번호(지금 V48 > `V49__add_member_nickname_changed_at.sql`), 머지 직전 다시 확인
- 테스트는 관련 클래스만 실행. 전체 스위트 금지

## Review Focus

- 앞뒤 공백·전각 문자(`ａｂｃ`) 입력 > NFKC·trim 뒤 판정 (Task 1 테스트)
- 한글 자모만(`ㅋㅋㅋ`) · 이모지 · 보이지 않는 문자(U+200B) > INVALID_FORMAT (Task 1)
- 욕설 사이에 숫자·하이픈 끼우기(`시1발`, `s-h-1-t`) > NOT_ALLOWED (Task 1)
- 같은 이름을 대소문자만 바꿔 저장(`Abc` > `abc`, 본인) > 본인은 중복 아님, 주기 소모 (Task 2)
- 동시 요청으로 유니크 인덱스 거부 > 500 아님, DUPLICATED (Task 2)

---

### Task 1: NicknamePolicy (형식 · 예약어 · 욕설 판정)

**Files:**
- Create: `server/src/main/java/com/chuseok22/elumserver/member/core/NicknamePolicy.java`
- Create: `server/src/main/java/com/chuseok22/elumserver/member/core/NicknameVerdict.java` (enum: `ALLOWED`, `INVALID_FORMAT`, `NOT_ALLOWED`)
- Create: `server/src/main/resources/nickname/profanity-{ko,en,ja,zh,es}.txt`, `nickname/profanity-allow.txt`, `nickname/reserved.txt` (한 줄 한 단어, `#` 주석)
- Test: `server/src/test/java/com/chuseok22/elumserver/member/core/NicknamePolicyTest.java`

**Interfaces:**
- Produces: `NicknamePolicy` `@Component`, `String normalize(String raw)`(trim + NFKC, null 이면 ""), `NicknameVerdict judge(String normalized)`. 기동 시 목록 파일이 없거나 비면 `IllegalStateException`(조용히 통과 금지)

- [ ] **Step 1: 표 테스트 작성** — `@ParameterizedTest` 3묶음
  - INVALID_FORMAT: `"가"`(1자), 17자, `"푸른 하늘"`, `"ㅋㅋㅋ"`, `"ㅅㅂ하늘"`(자모 섞임), `"하늘😀"`, `"하늘​"`, `""`
  - NOT_ALLOWED: `"시발놈"`, `"시1발"`, `"sh1t-man"`, `"FUCK"`, `"관리자"`, `"admin-1"`, `"elum공식"`
  - ALLOWED: `"가파른블록-1269"`, `"푸른하늘"`, `"Sky-7"`, `"시발점"`(허용 예외), `"ａｂｃ"`(NFKC 후 abc), 16자 경계
- [ ] **Step 2: 실행해 실패 확인** — `./gradlew test --offline --tests '*NicknamePolicyTest'` > 컴파일 실패
- [ ] **Step 3: 구현** — 비교용 문자열: 소문자 > 하이픈 제거 > 영문 사이 숫자는 `0→o 1→i 3→e 4→a 5→s 7→t`, 한글 사이 숫자는 제거 > 한글은 자모 분해. 허용 예외 단어를 먼저 지운 뒤 목록 단어 포함 여부 검사. 목록은 언어마다 최소 단어로 직접 작성
- [ ] **Step 4: 통과 확인** — 같은 명령, PASS
- [ ] **Step 5: 커밋**

### Task 2: 변경 흐름 · 오류 코드 · 데이터

**Files:**
- Create: `server/src/main/resources/db/migration/V49__add_member_nickname_changed_at.sql` (`ALTER TABLE member ADD COLUMN IF NOT EXISTS nickname_changed_at TIMESTAMP NULL;`)
- Modify: `member/infrastructure/entity/Member.java` (`private LocalDateTime nicknameChangedAt;`)
- Modify: `member/infrastructure/repository/MemberRepository.java` (`boolean existsByNicknameIgnoreCaseAndIdNot(String nickname, String id);`)
- Modify: `common/infrastructure/exception/ErrorCode.java` (MEMBER 묶음: `NICKNAME_INVALID_FORMAT(BAD_REQUEST)`, `NICKNAME_NOT_ALLOWED(BAD_REQUEST)`, `NICKNAME_DUPLICATED(CONFLICT)`, `NICKNAME_CHANGE_TOO_SOON(TOO_MANY_REQUESTS)`)
- Modify: `resources/i18n/messages_{ko,en,ja,zh,es}.properties`, `test/resources/i18n/golden/error-messages-ko.json`
- Modify: `member/application/service/MemberNicknameService.java`
- Modify: `member/application/dto/response/GuardianAccountResponse.java` (마지막 필드 `LocalDateTime nicknameChangeableAt`, `of(...)` 에 인자 추가)
- Modify: `member/application/service/MemberService.java` (`toGuardianAccount` 가 주기 반영, 새 메서드)
- Create: `member/application/dto/request/GuardianNicknameUpdateRequest.java` (`String nickname`)
- Test: `MemberNicknameServiceTest.java` 에 변경 케이스 추가

**Interfaces:**
- Consumes: Task 1 `NicknamePolicy.normalize/judge`
- Produces: `MemberNicknameService.change(Member member, String rawNickname)` (void, 실패는 `CustomException(ErrorCode)`), `static LocalDateTime changeableAt(Member member)` (null 가능), `MemberService.updateGuardianNickname(Caller caller, GuardianNicknameUpdateRequest request): MemberResponse`
- 시각은 주입된 `Clock` 빈 사용(credit 서비스와 같은 방식)

- [ ] **Step 1: 실패 테스트** — `MemberNicknameServiceTest`
  - 형식·욕설 거절 > 해당 ErrorCode, 저장 안 함
  - `nicknameChangedAt` = 지금-6일 > `NICKNAME_CHANGE_TOO_SOON`; 지금-7일 > 성공
  - 다른 회원이 `abc` 사용, 입력 `ABC` > `NICKNAME_DUPLICATED`
  - 본인 현재 `Abc`, 입력 `abc` > 성공, `nicknameChangedAt` 갱신
  - 현재와 완전히 같은 입력 > 아무것도 안 바뀜(시각도 그대로)
  - 첫 변경(`nicknameChangedAt == null`) > 성공
- [ ] **Step 2: 실행해 실패 확인** — `./gradlew test --offline --tests '*MemberNicknameServiceTest'`
- [ ] **Step 3: 구현** — 순서: normalize > 같으면 return > judge > 주기 > 중복 > set nickname + changedAt. `MemberService.updateGuardianNickname` 은 `@Transactional`, `saveAndFlush` 로 유니크 위반을 메서드 안에서 터뜨려 `DataIntegrityViolationException` > `NICKNAME_DUPLICATED`. 로그 `[member nickname] changed : memberId={}` / `rejected : memberId={}, reason={}`
- [ ] **Step 4: 문구 5개 언어 추가, 골든 갱신** (ko 는 spec 오류 표 그대로)
- [ ] **Step 5: 통과 확인** — `--tests '*MemberNicknameServiceTest' --tests '*ErrorMessageParityTest' --tests '*LocalizedErrorResponsesTest' --tests '*MemberServiceTest'`
- [ ] **Step 6: 커밋**

### Task 3: 컨트롤러 · Swagger

**Files:**
- Modify: `member/application/controller/MemberController.java` (`@PatchMapping("/account/nickname")`, `@Valid` 없이 서비스가 판정)
- Modify: `member/application/controller/MemberControllerDocs.java` (200 + 오류 4개 예시, 해요체 문구)
- Test: 기존 MemberController MockMvc 테스트가 있으면 거기에, 없으면 `MemberControllerAccountNicknameTest.java`

**Interfaces:**
- Consumes: Task 2 `MemberService.updateGuardianNickname`

- [ ] **Step 1: 실패 테스트** — 200 응답의 `account.nickname`, `account.nicknameChangeableAt` 경로 존재 / 서비스가 `NICKNAME_DUPLICATED` 던지면 409 + `errorCode`
- [ ] **Step 2: 실행해 실패 확인**
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인 + `./gradlew compileJava compileTestJava --offline`**
- [ ] **Step 5: 커밋**
