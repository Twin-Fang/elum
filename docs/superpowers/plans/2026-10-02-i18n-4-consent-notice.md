# 약관·공지 다국어와 관리자 화면 구현 계획 (하위 계획 4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 약관을 (약관 키, 언어) 한 쌍으로 저장·조회하고, 동의할 때 동의한 언어를 기록하며, 공지에 언어별 번역 행을 달고, 관리자 화면에서 언어별로 편집·확인하게 한다. 약관이 게시되지 않은 언어에서는 가입이 막히고 "약관을 불러오지 못했어요" + 재시도가 나온다. 공지에는 **대상 국가**(`app_notice.target_countries`)를 지정할 수 있고, 서버가 요청 국가로 걸러서 내려준다.

**Architecture:** 서버는 `Accept-Language` 를 `AppLocale.fromAcceptLanguage` 로 해석해 **그 언어의 게시본만** 준다(약관은 `en` 으로 대체하지 않는다. 공지는 요청 → `en` → `ko`). 약관의 "게시"는 **그 언어의 필수 4종(이용약관·개인정보·국외 이전·나이 확인)이 모두 있는 상태**다. 동의 기록은 `member.consent_locale` 에 남기고, 게시되지 않은 언어로는 동의를 받지 않는다(서버가 400). 클라이언트는 번들 기본값을 `ko` 한 벌만 두고(`en` 은 법무 확인 본문이 들어올 때 한 줄로 추가), 캐시는 언어별로 나눈다. 공지는 `app_notice_translation` 에 언어별 제목·본문·버튼 문구를 두고, 이미지·링크·기간·플랫폼은 공지 하나가 공유한다. 관리자 화면은 쿼리 `?locale=` 로 언어를 고르고, 공지 편집은 언어 탭 + 미리보기 언어 연동이다. 공지의 **대상 국가**는 공지 한 장이 공유하는 값(`app_notice.target_countries`, 쉼표 구분 ISO 코드, 비면 전체)이고, `NoticeService` 가 요청 국가(`CurrentRegion.get()`, 컨트롤러가 읽어 넘긴다)로 걸러서 내려준다. 앱은 공지 표시 코드를 바꾸지 않는다.

**Tech Stack:** Spring Boot 4.1 / JPA / Flyway / Thymeleaf / Mockito, 정적 JS(`notice-preview.js`), Flutter(Riverpod 3, Dio), Python 3.11(`tool/check_public_pages.py`), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-02-multi-language-design.md` (4.3.1 국가 판정, 4.4 약관과 동의 기록, 4.5 관리자 화면)

**마스터:** `docs/superpowers/plans/2026-10-02-i18n-0-master.md` (공통 계약 C1~C5)

## Global Constraints

- 지원 언어는 `ko` `en` `ja` `zh`(간체) `es` 다섯이다. RTL과 번체 중국어는 범위 밖이다.
- **앱 안에는 언어 선택 화면을 만들지 않는다.** 언어 강제 스위치는 개발자 도구(`core/dev`)에만 둔다.
- 대체 순서는 어디서든 **요청 언어 → `en` → `ko`** 이다.
- 요청 국가는 `CurrentRegion.get()` 이다(헤더 `X-Elum-Region`, **없으면 `KR`**, 비었거나 형식이 틀리면 `null` = 국가 미상). 이 계획은 그것을 **소비만** 한다. 국가 미상에게는 대상 국가를 지정하지 않은 공지만 보인다. 약관·개인정보방침은 국가와 무관하게 언어로만 고른다.
- `Accept-Language` 헤더가 **없으면 `ko`**, 5개 밖이거나 깨진 값이면 `en` 이다. 이미 배포된 앱의 응답은 바뀌지 않는다.
- 에러 문구는 서버가 번역해 내려보내고 클라이언트는 서버 문구를 그대로 보여준다(#347). 클라이언트가 에러 코드를 번역하지 않는다.
- `ko` 화면은 **1단계 이후에도 지금과 픽셀 단위로 같다.** 기존 앱 테스트와 골든이 그대로 통과해야 한다.
- 일과의 콘텐츠 언어는 일과를 만든 요청의 화면 언어이고, 보호자가 고르지 않는다.
- 약관은 그 언어의 게시본이 있어야 그 언어를 연다. 없는 언어에서 `en` 약관으로 대체하지 않는다.
- 서비스 원칙 유지: 진단명 미수집, 보호자 승인 후 노출, 원문 로그 미저장, AI 실패 시 fallback 필수.
- 용어: `이룸이`(아이·아동 금지), 해요체·능동형·긍정형(한국어 기준). 번역 용어는 용어집(`docs/i18n/glossary.md`)을 따른다.
- 코드 주석은 간결한 한국어(WHY 중심). 커밋은 `/pro-commit`으로, 이슈 번호 연결, `Co-Authored-By` 금지, 푸시는 사용자 요청 시에만.
- AI 호출은 비용이다. 검증용으로 생성 API를 반복 호출하지 않고 언어당 가장 싼 모델로 최소 횟수만 쓴다.
- Flyway 번호는 아래 표가 임시 배정이다. 구현 시점에 `origin/develop`의 다음 빈 번호를 쓴다(번호가 겹치면 먼저 머지된 쪽이 이긴다).

## Review Focus

이 계획이 소유한 줄(마스터 Review Focus 에서 계획 4 로 배정된 것).

- 약관이 게시되지 않은 언어에서 가입이 막히고 재시도 안내가 나온다(빈 화면·무한 로딩 금지). (계획 4)
  - 서버 측 차단: Task 3 `getPublished_incomplete_isEmpty`, Task 4 `agreeConsents_unpublishedLocale_rejected`
  - 클라이언트 측: Task 10 `loadFor_noBundle_unavailable`, Task 11 `unavailable_showsRetry_notBlank`, `retry_reloads`, `error_nonKo_unavailable`

이 계획이 추가로 테스트로 고정하는 것(계획 간 계약과 `ko` 불변을 지키려는 것).

- `ko` 시딩 결과가 현재와 같다 — `consent/ko/*.txt` 5개의 SHA-256 이 이동 전과 같다. (Task 2)
- 헤더가 없는 약관·공지 요청의 응답 본문 JSON 이 이전과 같은 모양이다. (Task 4, Task 6)
- 약관 캐시가 언어별로 나뉘고, 이미 받아 둔 `ko` 캐시를 버리지 않는다. 다른 언어로 응답이 오면 캐시에 넣지 않는다. (Task 10)
- 공지 응답이 `Vary: Accept-Language` 를 붙인다(60초 캐시가 언어를 섞지 않게). (Task 6)
- 관리자 미리보기의 줄바꿈 표시 규칙이 앱과 같은 언어 집합(`ja`·`zh` 는 표시 없음)을 쓴다. (Task 9)
- 이 마이그레이션(V34·V35)은 `MigrationRollbackContractTest` 의 "V32 만 줄인다" 규칙을 어기지 않는다. (Task 1, Task 5)
- 국가 미상(`null`) 사용자에게 대상 국가가 지정된 공지가 새지 않는다. (Task 5 `AppNoticeTargetCountriesTest#unknownRegion_onlyUntargeted`, Task 6 `NoticeCountryTest#unknownRegion_neverSeesTargeted`·`otherCountryNoticesDoNotTakeSlots`)
- 대상 국가 목록에 형식이 틀린 코드가 들어가지 않는다 — 두 글자 대문자만, 중복 제거, 255자 안. 걸리면 아무것도 저장하지 않는다. (Task 6 `NoticeCountryTest#create_rejectsMalformed`·`create_maxLength`·`update_invalid_keepsOldValue`, Task 8 `create_invalidTargetCountries_code`)
- 헤더가 없는 기존 앱(= `KR`)은 기존과 같은 공지를 본다 — 대상이 비어 있는 기존 공지는 전과 같이 나오고 응답 본문 모양도 같다. (Task 6 `NoticeCountryTest#headerlessOldApp_seesWhatItAlwaysSaw`·`response_doesNotExposeTargetCountries`)
- 국가별로 달라지는 공지 응답을 60초 캐시가 섞지 않는다 — `Vary` 에 `X-Elum-Region` 이 있다. (Task 6 `NoticeControllerTest`)

## 선행 조건 (시작 전에 확인한다)

이 계획은 다른 계획의 **계약만** 쓴다. 아래가 없으면 해당 Task 를 시작하지 않는다.

| 필요한 것 | 출처 | 쓰는 Task | 확인 명령 | 기대 결과 |
| --- | --- | --- | --- | --- |
| `com.chuseok22.elumserver.common.locale.CurrentRegion` (`get()` → 대문자 ISO 코드 또는 `null` = 국가 미상, 요청 밖·헤더 없음은 `KR`, 상수 `HEADER = "X-Elum-Region"`·`DEFAULT = "KR"`). 헤더는 클라이언트(계획 1 Task 25)가 보낸다 | 계획 2 Task 3, C1-2 | 서버 Task 6 (이 계획은 **소비만** 한다) | `grep -rn "class CurrentRegion" server/src/main/java` | 1건. **없으면 Task 6 의 대상 국가 부분을 시작하지 않는다**(이 계획에서 만들지 않는다) |
| `com.chuseok22.elumserver.common.locale.AppLocale` (`code()`, `fallbackChain()`, `fromCode`, `fromAcceptLanguage`, 상수 `KO EN JA ZH ES`) | 계획 2, C2 | 서버 Task 2~9 | `grep -rn "enum AppLocale" server/src/main/java` | 1건 |
| Flyway 다음 빈 번호 | C3 | Task 1, 5 | `ls server/src/main/resources/db/migration \| sort -V \| tail -3` | 마지막이 V33 이면 V34·V35 를 그대로 쓴다. 더 크면 이 계획의 V34·V35 를 그 다음 번호로 바꿔 쓴다(파일 이름·계약 테스트 경로만 바뀐다) |
| `context.l10n`, `supportedAppLocales`, `AppLocalizations` | 계획 1, C4 | 클라 Task 10~11 | `grep -rn "supportedAppLocales" client/lib/core/l10n` | 1건 이상 |
| 위젯 테스트 기본 locale 이 `ko` 로 고정됨 | 계획 1 | 클라 Task 11 | `grep -n "localeTestValue\|localesTestValue" client/test/flutter_test_config.dart` | 1건 이상. **없으면 계획 1 이 끝나지 않은 것이다.** 이 계획에서 고치지 않는다 |
| `AcceptLanguageInterceptor` 가 `Accept-Language` 를 붙임 | 계획 1, C4 | 클라 Task 10 | `grep -rn "class AcceptLanguageInterceptor" client/lib` | 1건 |

> 번호가 바뀌면 `MigrationRollbackContractTest` 가 아닌 이 계획이 만든 `ConsentLocaleMigrationTest`·`NoticeTranslationMigrationTest` 의 경로 상수만 고친다.

## 파일 구조 (한눈에)

```
server/src/main/
  resources/consent/ko/{terms,privacy,overseas,age,marketing}.txt   ← git mv (내용 불변)
  resources/db/migration/V34__add_locale_to_consent.sql              (새)
  resources/db/migration/V35__create_app_notice_translation.sql      (새 · 번역 표 + app_notice.target_countries)
  java/.../consent/core/ConsentKey.java                              (label→koLabel, 본문 경로 언어별)
  java/.../consent/infrastructure/entity/{ConsentDocument,ConsentDocumentHistory}.java  (locale)
  java/.../consent/infrastructure/repository/*                        (언어 조건 조회)
  java/.../consent/infrastructure/config/ConsentDocumentInitializer.java
  java/.../consent/application/service/ConsentDocumentService.java   (언어별 조회·게시·수정)
  java/.../consent/application/controller/ConsentController(+Docs).java
  java/.../member/{entity/Member, dto/request/MemberConsentRequest, service/MemberService, controller/*}  (동의 언어)
  java/.../notice/infrastructure/entity/{AppNotice,AppNoticeTranslation}.java
  java/.../notice/application/{service/NoticeService, dto/request/{NoticeInput,NoticeTextInput}, dto/response/AppNoticeResponse, controller/*}
  java/.../notice/core/NoticeLocaleException.java                    (새)
  java/.../admin/...                                                  (관리자 컨트롤러·폼·행 DTO)
  resources/templates/admin/{consents,consent-edit,consent-history,notices,notice-edit}.html
  resources/static/admin/js/notice-preview.js
client/lib/features/auth/{domain,data,presentation}/...              (언어별 번들·캐시·불러오기 실패 화면)
client/lib/core/storage/local_storage.dart                           (언어별 약관 캐시)
tool/check_public_pages.py, tool/test_check_public_pages.py          (언어별 게시본 검사)
.github/workflows/PROJECT-ELUM-PUBLIC-PAGES-CHECK.yaml
```

> **줄 범위에 대해.** 각 Task 의 `Modify` 줄 범위는 이 계획을 쓴 시점의 `origin/develop` 기준이다. 앞 Task 가 같은 파일을 고치면 줄이 밀리므로, 줄 번호가 안 맞으면 **함수·필드 이름으로** 찾는다. 같은 파일을 두 Task 가 고치는 경우(`ErrorCode.java`, `ConsentDocumentRepository.java`, `ConsentDocumentServiceTest.java`)는 Task 마다 다른 자리라 겹치지 않는다.

## 결정 요약 (코드를 읽다 보면 궁금해질 것들)

| 결정 | 이유 |
| --- | --- |
| 약관 "게시" = 그 언어의 **필수 4종이 모두 있음** | 일부만 있으면 앱이 필수 항목이 빠진 동의 화면을 띄우고, 서버는 네 항목 `@AssertTrue` 라 가입이 영영 안 된다. 선택(소식 받기)은 없어도 열린다. |
| 컨트롤러가 `Accept-Language` 를 직접 받아 `AppLocale.fromAcceptLanguage` 를 부른다 | `CurrentLocale` 은 요청 필터에 기대 단위 테스트가 어렵다. 규칙은 같은 메서드라 결과가 같다. |
| 동의 요청에 선택 필드 `consentLocale` 을 더한다(없으면 헤더) | 증빙은 "사용자가 **본** 약관의 언어"여야 한다. 앱이 화면에 띄운 번들의 언어를 그대로 보낸다. 이미 배포된 앱은 안 보내므로 헤더(없으면 `ko`)를 따른다. |
| 응답 본문 모양은 그대로, `Content-Language`·`Vary` 헤더만 더한다 | 헤더 없는 요청의 응답이 이전과 같아야 한다. 클라이언트는 `Content-Language` 로 "요청한 언어가 온 것"을 확인하고 캐시에 넣는다. |
| `Initializer` 는 `ko` 만 시딩한다(`SEEDED_LOCALES`) | 다른 언어 본문 파일이 폴더에 들어왔다고 배포 한 번에 자동 게시되면 법무 확인을 우회한다. 다른 언어는 관리자 화면의 "최초 게시"로만 열린다. |
| `consent/<언어>/` 폴더 존재 = 게시 페이지 검사 대상 | 다른 언어를 열 때 법무가 확인한 본문을 이 폴더에 같이 커밋한다. 폴더가 생기면 CI 가 `/{언어}/privacy.html` 등 게시본 존재를 요구한다. |
| 공지의 한국어 필드(`title`·`body`·`buttonLabel`)는 계속 입력 폼의 최상위 필드다 | `ko` 필수·나머지 선택 규칙이 모양에 그대로 드러나고, 기존 폼·시험이 거의 안 바뀐다. 나머지 언어는 `translations[en].title` 같은 이름으로 따로 묶인다. |
| `AppNotice.getTitle()` 등은 **한국어 번역 행**을 읽는 편의 메서드로 남긴다 | 관리자 목록·로그·기존 시험이 그대로 한국어 제목을 쓴다. 필드는 없으므로 Hibernate 는 무시한다. |
| 공지의 버튼 링크·이미지는 언어와 무관하게 공유한다 | C3 의 번역 표 열이 제목·본문·버튼 문구뿐이다. 이미지에 글이 박힌 공지는 언어별로 다르게 못 낸다(알려진 한계 — 관리자 화면에 적어 둔다). |
| 대상 국가는 공지 한 장의 열 하나(`target_countries`, 쉼표 구분 문자열)다. 별도 표를 두지 않는다 | 국가는 목록이 짧고 조회 조건이 아니라 노출 필터다(공지는 몇십 건이라 메모리에서 거른다). 언어별 번역과 달리 1:N 관계의 속성을 더 붙일 일이 없다. |
| 국가는 컨트롤러가 `CurrentRegion.get()` 으로 읽어 `NoticeService` 에 인자로 넘긴다 | 서비스가 요청 컨텍스트에 기대면 단위 테스트가 어렵다(`CurrentLocale` 을 컨트롤러가 직접 받는 것과 같은 이유). 국가 미상(`null`)도 인자로 그대로 시험할 수 있다. (`CurrentRegion.set` 은 같은 패키지 전용이라 컨트롤러 시험은 "요청 밖 = `KR`" 만 볼 수 있다.) |
| 검증은 `NoticeService.normalizeTargetCountries` 한 곳이다. `NoticeInput` 에는 검증 어노테이션을 두지 않는다 | `server/CLAUDE.md` — request DTO 에 `jakarta.validation` 계열을 쓰지 않는다. 입력은 문자열 그대로 받고 서비스가 다듬는다. |
| 국가 코드는 **두 글자 대문자만** 받고 소문자·세 글자는 거절한다. 허용 국가 목록은 두지 않는다 | 형식만 지키면 새 국가를 코드 수정 없이 쓸 수 있다. 소문자를 몰래 고치면 "KR" 로 저장된 줄 모르는 채 화면 값과 달라진다. 거절하면 쓰던 칸은 그대로 남는다. |
| 노출 판단 순서: 게시 기간·켜짐 → 플랫폼 → **대상 국가** → 언어 글 고르기 → 최대 5개 | 국가·플랫폼으로 빠지는 공지가 5개 슬롯을 차지하지 않게 `limit` 앞에서 거른다. |
| 응답 `Vary` 에 `X-Elum-Region` 을 더한다 | 같은 주소·같은 언어라도 국가가 다르면 응답이 다르다. 60초 캐시가 한국 응답을 일본 요청에 주면 안 된다. |

---

## Task 1: 약관·동의 기록 스키마(V34)와 엔티티

**Files:**
- Create: `server/src/main/resources/db/migration/V34__add_locale_to_consent.sql`
- Create: `server/src/test/java/com/chuseok22/elumserver/consent/ConsentLocaleMigrationTest.java`
- Modify: `server/src/main/java/com/chuseok22/elumserver/consent/infrastructure/entity/ConsentDocument.java:22-33` (`@Table` 추가, `unique` 제거, `locale` 필드)
- Modify: `server/src/main/java/com/chuseok22/elumserver/consent/infrastructure/entity/ConsentDocumentHistory.java:27-43` (인덱스 이름·열, `locale` 필드)
- Modify: `server/src/main/java/com/chuseok22/elumserver/consent/infrastructure/repository/ConsentDocumentRepository.java:8-13` (새 조회 추가, 옛 조회는 Task 3 에서 지운다)
- Modify: `server/src/main/java/com/chuseok22/elumserver/consent/infrastructure/repository/ConsentDocumentHistoryRepository.java:8-12`
- Modify: `server/src/main/java/com/chuseok22/elumserver/member/infrastructure/entity/Member.java:91-105` (`consentLocale`, `clearConsents`)

**Interfaces:**
- Consumes: 없음
- Produces:
  - `ConsentDocument#getLocale(): String` / `setLocale(String)` — 코드 문자열(`"ko"`), 열 `locale VARCHAR(8) NOT NULL DEFAULT 'ko'`
  - `ConsentDocumentHistory#getLocale(): String` / `setLocale(String)`
  - `Member#getConsentLocale(): String` / `setConsentLocale(String)` — 열 `consent_locale VARCHAR(8)` NULL 허용
  - `ConsentDocumentRepository#findByConsentKeyAndLocale(ConsentKey, String): Optional<ConsentDocument>`, `#findAllByLocale(String): List<ConsentDocument>`
  - `ConsentDocumentHistoryRepository#findTop50ByConsentKeyAndLocaleOrderByCreatedAtDesc(ConsentKey, String): List<ConsentDocumentHistory>`

> 이 Task 는 **옛 조회(`findByConsentKey`)를 지우지 않는다.** 서비스(Task 3)가 새 조회로 옮길 때까지 컴파일이 깨지지 않게 하려는 것이다. 운영 DB 에 아직 `ko` 행밖에 없으므로 그 사이에도 옛 조회는 한 건만 돌려준다.

- [ ] **Step 1: 선행 확인 — 번호와 `AppLocale`**

Run:
```bash
ls server/src/main/resources/db/migration | sort -V | tail -3
grep -rn "enum AppLocale" server/src/main/java
```
Expected: 마지막 마이그레이션이 `V33...`(없으면 `V32`), `AppLocale` 1건. 마지막이 V33 보다 크면 이 계획의 V34 를 그다음 번호로 바꿔 이후 모든 경로를 같이 바꾼다.

- [ ] **Step 2: 실패하는 계약 시험을 쓴다**

`server/src/test/java/com/chuseok22/elumserver/consent/ConsentLocaleMigrationTest.java`:

```java
package com.chuseok22.elumserver.consent;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocumentHistory;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import jakarta.persistence.Column;
import jakarta.persistence.Table;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.stream.Collectors;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 약관 언어 마이그레이션(V34)이 엔티티와 같고, 옛 데이터를 한국어로 채우는지 글로 확인한다 (이슈 #521).
 *
 * <p>운영은 {@code ddl-auto: validate} 라 열 이름·길이가 엔티티와 어긋나면 서버가 뜨지 않는다.
 * DB 를 띄우지 않는다. 실제 적용은 운영 사본 리허설에서 본다.
 */
class ConsentLocaleMigrationTest {

  private static final Path V34 = Path.of(
    "src/main/resources/db/migration/V34__add_locale_to_consent.sql");

  @Test
  @DisplayName("V34 는 언어 열을 DEFAULT 'ko' 와 함께 더한다 — 기존 약관·이력이 모두 한국어가 된다")
  void v34_addsLocaleWithKoDefault() throws IOException {
    String sql = normalizedSql();
    assertThat(sql).contains(
      "alter table consent_document add column if not exists locale varchar(8) not null default 'ko';");
    assertThat(sql).contains(
      "alter table consent_document_history add column if not exists locale varchar(8) not null default 'ko';");
  }

  @Test
  @DisplayName("V34 는 유니크를 (consent_key, locale) 로 바꾼다 — 키만 걸린 옛 유니크는 이름과 상관없이 지운다")
  void v34_uniqueIsKeyAndLocale() throws IOException {
    String sql = normalizedSql();
    // 로컬(ddl-auto: update)은 옛 유니크 이름이 Hibernate 가 지은 임의 이름일 수 있다. 이름이 아니라 모양으로 찾아 지운다.
    assertThat(sql).contains("c.contype = 'u'").contains("drop constraint");
    assertThat(sql).contains("add constraint uk_consent_document_key_locale unique (consent_key, locale)");
  }

  @Test
  @DisplayName("V34 는 동의 기록에 consent_locale 을 NULL 허용으로 더하고, 이미 동의한 회원은 ko 로 채운다")
  void v34_memberConsentLocale() throws IOException {
    String sql = normalizedSql();
    // 문장이 ';' 로 바로 끝나야 NOT NULL 이 없다는 뜻이다 — 옛 서버의 가입이 이 열을 모르고 INSERT 한다.
    assertThat(sql).contains("alter table member add column if not exists consent_locale varchar(8);");
    // 지금까지 약관은 한국어 하나뿐이었으므로 동의한 회원의 언어는 사실상 ko 다.
    assertThat(sql).contains(
      "update member set consent_locale = 'ko' where consented_at is not null and consent_locale is null;");
  }

  @Test
  @DisplayName("V34 는 열을 지우지 않고 NOT NULL 을 새로 조이지 않는다 — MigrationRollbackContractTest 의 규칙")
  void v34_dropsNoColumn() throws IOException {
    String sql = normalizedSql();
    assertThat(sql).doesNotContain("drop column").doesNotContain("drop table").doesNotContain("set not null");
  }

  @Test
  @DisplayName("엔티티는 V34 와 같다 — 열 길이 8, 유니크 (consent_key, locale)")
  void entitiesMatchMigration() throws Exception {
    Column locale = ConsentDocument.class.getDeclaredField("locale").getAnnotation(Column.class);
    assertThat(locale.length()).isEqualTo(8);
    assertThat(locale.nullable()).isFalse();

    Table table = ConsentDocument.class.getAnnotation(Table.class);
    assertThat(table.uniqueConstraints()).hasSize(1);
    assertThat(table.uniqueConstraints()[0].name()).isEqualTo("uk_consent_document_key_locale");
    assertThat(table.uniqueConstraints()[0].columnNames()).containsExactly("consent_key", "locale");

    Column historyLocale = ConsentDocumentHistory.class.getDeclaredField("locale").getAnnotation(Column.class);
    assertThat(historyLocale.length()).isEqualTo(8);
    assertThat(historyLocale.nullable()).isFalse();

    Column consentLocale = Member.class.getDeclaredField("consentLocale").getAnnotation(Column.class);
    assertThat(consentLocale.length()).isEqualTo(8);
    assertThat(consentLocale.nullable()).isTrue();
  }

  /** 주석을 빼고 공백을 하나로, 소문자로 — 주석에 적힌 설명이 검사를 속이지 않게 한다. */
  private String normalizedSql() throws IOException {
    return Files.readAllLines(V34).stream()
      .map(line -> line.contains("--") ? line.substring(0, line.indexOf("--")) : line)
      .collect(Collectors.joining(" "))
      .replaceAll("\\s+", " ")
      .toLowerCase();
  }
}
```

- [ ] **Step 3: 실행해 실패를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.consent.ConsentLocaleMigrationTest'`
Expected: FAIL — `NoSuchFileException: ...V34__add_locale_to_consent.sql` (그리고 컴파일은 통과해야 한다. `locale` 필드가 없어 컴파일이 깨지면 Step 4~5 를 먼저 하고 다시 돌린다).

- [ ] **Step 4: 마이그레이션을 쓴다**

`server/src/main/resources/db/migration/V34__add_locale_to_consent.sql`:

```sql
-- 약관을 (약관 키, 언어) 한 쌍으로 관리한다 (이슈 #521, 다국어 하위 계획 4).
--
-- 지금까지 약관은 한국어 하나였다. consent_key 하나가 곧 문서 하나였고 유니크도 거기에 걸려 있었다.
-- 언어를 더하려면 같은 consent_key 에 언어별 행이 여럿이어야 한다. 기존 행은 모두 'ko' 가 된다.
--
-- 이 마이그레이션은 추가 위주다(열 추가 + 유니크 교체). 다만 **영어 등 다른 언어 약관을 게시한 뒤에는**
-- 옛 서버 이미지로 되돌리면 findByConsentKey 가 여러 행을 만나 약관 조회가 500 이 된다.
-- 앱은 이때 번들 기본값으로 떨어지므로 가입은 막히지 않지만, 되돌리려면 다른 언어 행을 먼저 지운다.
--
-- 동의 기록(member.consent_locale)은 NULL 을 허용한다. 옛 서버는 이 열을 모르고 가입 동의를 저장한다.
-- 이미 동의한 회원은 한국어 약관에 동의한 것이 사실이라 'ko' 로 채운다(받지 않은 동의를 꾸미는 것이 아니다).
--
-- prod 는 ddl-auto: validate 라 Hibernate 가 열을 만들지 않는다. 로컬(ddl-auto: update)에서 이미 만들어졌을
-- 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다. 다시 돌려도 안전하다(멱등).

ALTER TABLE consent_document ADD COLUMN IF NOT EXISTS locale VARCHAR(8) NOT NULL DEFAULT 'ko';

-- consent_key 한 열에만 걸린 유니크는 이름과 상관없이 모두 지운다.
-- 운영은 V21 의 uk_consent_document_key 지만, 로컬(ddl-auto: update)은 Hibernate 가 지은 임의 이름이다.
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT c.conname
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    WHERE t.relname = 'consent_document'
      AND c.contype = 'u'
      AND array_length(c.conkey, 1) = 1
      AND (SELECT a.attname FROM pg_attribute a
           WHERE a.attrelid = t.oid AND a.attnum = c.conkey[1]) = 'consent_key'
  LOOP
    EXECUTE format('ALTER TABLE consent_document DROP CONSTRAINT %I', r.conname);
  END LOOP;
END $$;

ALTER TABLE consent_document DROP CONSTRAINT IF EXISTS uk_consent_document_key_locale;
ALTER TABLE consent_document ADD CONSTRAINT uk_consent_document_key_locale UNIQUE (consent_key, locale);

-- 수정 이력도 어느 언어의 약관이었는지 남긴다. 분쟁 때 "그 사람이 동의한 언어의 그 시점 문구"를 찾는다.
ALTER TABLE consent_document_history ADD COLUMN IF NOT EXISTS locale VARCHAR(8) NOT NULL DEFAULT 'ko';

CREATE INDEX IF NOT EXISTS idx_consent_document_history_key_locale_created
  ON consent_document_history (consent_key, locale, created_at);

-- 동의한 언어. 어떤 사용자가 어떤 언어의 어떤 버전에 동의했는지 증명한다(consent_version 과 짝).
ALTER TABLE member ADD COLUMN IF NOT EXISTS consent_locale VARCHAR(8);

UPDATE member SET consent_locale = 'ko' WHERE consented_at IS NOT NULL AND consent_locale IS NULL;
```

- [ ] **Step 5: 엔티티·저장소를 고친다**

`ConsentDocument.java` — 클래스 선언부(22~25행)와 `consentKey`(31~33행)를 아래로 바꾼다. import 에 `jakarta.persistence.Table`, `jakarta.persistence.UniqueConstraint` 를 더한다.

```java
@Entity
@Getter
@Setter
@Table(
  name = "consent_document",
  // 같은 약관 키가 언어마다 한 행씩 있다. 언어 없이 키만 유니크였던 제약은 V34 가 지웠다.
  uniqueConstraints = @UniqueConstraint(
    name = "uk_consent_document_key_locale", columnNames = {"consent_key", "locale"})
)
public class ConsentDocument extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private ConsentKey consentKey;

  /** 이 문서의 언어 코드({@code ko} {@code en} …). {@code AppLocale#code()} 와 같다. */
  @Column(nullable = false, length = 8)
  private String locale = "ko";
```

`ConsentDocumentHistory.java` — `@Table`(30~34행)과 `consentKey` 다음에 필드를 더한다.

```java
@Table(
  name = "consent_document_history",
  indexes = @Index(name = "idx_consent_document_history_key_locale_created",
    columnList = "consent_key, locale, created_at")
)
```
```java
  /** 스냅샷이 속한 약관의 언어. */
  @Column(nullable = false, length = 8)
  private String locale = "ko";
```
(두 번째 블록은 `private ConsentKey consentKey;`(43행) 바로 아래에 둔다.)

`ConsentDocumentRepository.java` — 인터페이스 본문에 두 줄을 더한다(옛 두 줄은 그대로 둔다).

```java
  Optional<ConsentDocument> findByConsentKeyAndLocale(ConsentKey consentKey, String locale);

  List<ConsentDocument> findAllByLocale(String locale);
```
import 에 `java.util.List` 를 더한다.

`ConsentDocumentHistoryRepository.java` — 한 줄을 더한다.

```java
  List<ConsentDocumentHistory> findTop50ByConsentKeyAndLocaleOrderByCreatedAtDesc(
    ConsentKey consentKey, String locale);
```

`Member.java` — 91~93행(`consentVersion`) 아래에 필드를 더하고, `clearConsents()`(97~105행)에 한 줄을 더한다.

```java
  /// 동의한 약관의 언어 코드. consentVersion 과 짝으로 "어떤 언어의 어떤 버전에 동의했나"를 남긴다.
  /// 옛 서버가 받은 동의는 V34 가 'ko' 로 채웠다. 아직 동의하지 않았으면 null.
  @Column(length = 8)
  private String consentLocale;
```
```java
    consentVersion = null;
    consentLocale = null;
```

- [ ] **Step 6: 통과를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.consent.ConsentLocaleMigrationTest' --tests 'com.chuseok22.elumserver.common.MigrationRollbackContractTest'`
Expected: PASS — 신규 5건, 기존 계약 시험은 그대로 통과(`onlyV32DropsOrTightens` 가 V34 를 읽어도 `drop column`·`set not null` 이 없다).

- [ ] **Step 7: 전체 서버 컴파일·기존 시험이 깨지지 않았는지 본다**

Run: `cd server && ./gradlew test`
Expected: PASS. (옛 조회를 남겼으므로 `ConsentDocumentService`·Initializer 는 그대로 컴파일된다.)

- [ ] **Step 8: 커밋 (`/pro-commit`)**

```bash
git add server/src/main/resources/db/migration/V34__add_locale_to_consent.sql \
  server/src/test/java/com/chuseok22/elumserver/consent/ConsentLocaleMigrationTest.java \
  server/src/main/java/com/chuseok22/elumserver/consent/infrastructure/entity/ConsentDocument.java \
  server/src/main/java/com/chuseok22/elumserver/consent/infrastructure/entity/ConsentDocumentHistory.java \
  server/src/main/java/com/chuseok22/elumserver/consent/infrastructure/repository/ConsentDocumentRepository.java \
  server/src/main/java/com/chuseok22/elumserver/consent/infrastructure/repository/ConsentDocumentHistoryRepository.java \
  server/src/main/java/com/chuseok22/elumserver/member/infrastructure/entity/Member.java
```

---

## Task 2: 약관 시드를 `ko` 폴더로 옮기고 Initializer 를 언어별로

**Files:**
- Move: `server/src/main/resources/consent/{terms,privacy,overseas,age,marketing}.txt` → `server/src/main/resources/consent/ko/` (`git mv`, **내용 불변**)
- Modify: `server/src/main/java/com/chuseok22/elumserver/consent/core/ConsentKey.java:25-51`
- Modify: `server/src/main/java/com/chuseok22/elumserver/consent/infrastructure/config/ConsentDocumentInitializer.java:28-89`
- Modify: `server/src/test/java/com/chuseok22/elumserver/member/WithdrawnRetentionMatchesPrivacyPolicyTest.java:21-27`
- Modify: `server/src/test/java/com/chuseok22/elumserver/consent/application/service/ConsentDocumentServiceTest.java:62-72` (`getLabel` → `getKoLabel`)
- Modify: `client/test/consent_body_test.dart:295-312` (원본 경로, **조용히 건너뛰던 것을 막는다**)
- Test: `server/src/test/java/com/chuseok22/elumserver/consent/infrastructure/config/ConsentDocumentInitializerTest.java` (새)

**Interfaces:**
- Consumes: `AppLocale#code()`, `ConsentDocumentRepository#findByConsentKeyAndLocale(ConsentKey, String)`, `#findAll()` (Task 1)
- Produces:
  - `ConsentKey#getKoLabel(): String`, `#getKoSummary(): String`, `#getBodyFile(): String`, `#bodyResource(AppLocale): String` (예: `"consent/ko/terms.txt"`)
  - `ConsentDocumentInitializer.SEEDED_LOCALES: List<AppLocale>` (= `[KO]`)

> **왜 `ko` 만 시딩하나.** 다른 언어 본문 파일이 폴더에 들어왔다고 배포 한 번에 자동 게시되면 법무 확인을 우회한다. 다른 언어는 관리자 화면의 "최초 게시"(Task 7)로만 열린다. 폴더 `consent/<언어>/` 는 CI 가 게시본 존재를 요구하게 하는 신호이자 법무가 확인한 본문의 보관처다(Task 12).

- [ ] **Step 1: 이동 전 해시를 확인해 둔다**

Run: `cd server/src/main/resources/consent && shasum -a 256 *.txt`
Expected (이 값이 시험의 정답이다):
```
490c311cfae066fa77f74486b4213f4106f4f9fa94efe48853d9c92fb68b54d1  age.txt
5f745438c652cb09668ae41c3967433349d20563527a0194c0d89054065c3fa2  marketing.txt
cffd981414ff9c2d3b86b3c4a8672d6fa5da3ce882923d0e99242b5064ab6388  overseas.txt
a14be914bcf3251ee67c89dfc8d5584d9e2ad802e94765b5ec9a609e13eb9eb7  privacy.txt
9cf468883ec7413fab3033b178f7860f3364f81ab28de08252ea4fcd7ec2c4ae  terms.txt
```
다르면 이 계획을 쓴 뒤 약관 본문이 바뀐 것이다. 새 값으로 아래 시험의 상수를 바꾼다(이동 **전** 값이어야 한다).

- [ ] **Step 2: 실패하는 시험을 쓴다**

`server/src/test/java/com/chuseok22/elumserver/consent/infrastructure/config/ConsentDocumentInitializerTest.java`:

```java
package com.chuseok22.elumserver.consent.infrastructure.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import com.chuseok22.elumserver.consent.infrastructure.repository.ConsentDocumentRepository;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

/**
 * 약관 시딩이 언어 폴더로 옮겨 간 뒤에도 {@code ko} 결과가 같은지 (이슈 #521).
 *
 * <p>법적 문구라 한 글자도 달라지면 안 된다. 파일을 옮기며 내용이 바뀌지 않았다는 증거로
 * 이동 <b>전</b>에 잰 SHA-256 을 고정해 둔다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ConsentDocumentInitializerTest {

  /** 이동 전 {@code consent/*.txt} 의 SHA-256 (shasum -a 256). */
  private static final Map<ConsentKey, String> KO_SHA256 = Map.of(
    ConsentKey.TERMS, "9cf468883ec7413fab3033b178f7860f3364f81ab28de08252ea4fcd7ec2c4ae",
    ConsentKey.PRIVACY, "a14be914bcf3251ee67c89dfc8d5584d9e2ad802e94765b5ec9a609e13eb9eb7",
    ConsentKey.OVERSEAS_TRANSFER, "cffd981414ff9c2d3b86b3c4a8672d6fa5da3ce882923d0e99242b5064ab6388",
    ConsentKey.AGE_CONFIRM, "490c311cfae066fa77f74486b4213f4106f4f9fa94efe48853d9c92fb68b54d1",
    ConsentKey.MARKETING, "5f745438c652cb09668ae41c3967433349d20563527a0194c0d89054065c3fa2");

  @Mock
  private ConsentDocumentRepository repository;

  private ConsentDocumentInitializer initializer;

  @BeforeEach
  void setUp() {
    initializer = new ConsentDocumentInitializer(repository);
    when(repository.findByConsentKeyAndLocale(any(), any())).thenReturn(Optional.empty());
    when(repository.findAll()).thenReturn(List.of());
  }

  private static byte[] resourceBytes(String path) throws IOException {
    try (InputStream in = ConsentDocumentInitializerTest.class.getClassLoader().getResourceAsStream(path)) {
      assertThat(in).as("%s 가 클래스패스에 있다", path).isNotNull();
      return in.readAllBytes();
    }
  }

  @Test
  @DisplayName("ko 본문 5개는 이동 전과 바이트 단위로 같다 — 법적 문구가 달라지면 안 된다")
  void koBodies_areByteIdentical() throws IOException, NoSuchAlgorithmException {
    for (ConsentKey key : ConsentKey.values()) {
      byte[] bytes = resourceBytes(key.bodyResource(AppLocale.KO));
      String sha = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
      assertThat(sha).as("%s 의 SHA-256", key).isEqualTo(KO_SHA256.get(key));
    }
  }

  @Test
  @DisplayName("ko 시딩 결과는 이전과 같다 — 본문(strip)·한국어 이름·요약·버전·필수 여부")
  void seedsKoLikeBefore() throws IOException {
    initializer.run(null);

    ArgumentCaptor<ConsentDocument> saved = ArgumentCaptor.forClass(ConsentDocument.class);
    verify(repository, times(ConsentKey.values().length)).save(saved.capture());
    for (ConsentDocument document : saved.getAllValues()) {
      ConsentKey key = document.getConsentKey();
      String expectedBody = new String(resourceBytes(key.bodyResource(AppLocale.KO)), StandardCharsets.UTF_8).strip();
      assertThat(document.getLocale()).isEqualTo("ko");
      assertThat(document.getBody()).isEqualTo(expectedBody);
      assertThat(document.getLabel()).isEqualTo(key.getKoLabel());
      assertThat(document.getSummary()).isEqualTo(key.getKoSummary());
      assertThat(document.getVersion()).isEqualTo("2026-09-21");
      assertThat(document.isRequired()).isEqualTo(key.isRequired());
    }
  }

  @Test
  @DisplayName("이미 있는 문서는 건드리지 않는다 — 관리자가 고친 내용을 배포가 되돌리면 안 된다")
  void existingDocument_isNotOverwritten() {
    ConsentDocument existing = new ConsentDocument();
    existing.setConsentKey(ConsentKey.TERMS);
    existing.setLocale("ko");
    existing.setBody("관리자가 고친 본문");
    existing.setRequired(true);
    when(repository.findByConsentKeyAndLocale(any(), any())).thenReturn(Optional.of(existing));

    initializer.run(null);

    verify(repository, never()).save(any());
    assertThat(existing.getBody()).isEqualTo("관리자가 고친 본문");
  }

  @Test
  @DisplayName("다른 언어는 시딩하지 않는다 — 법무 확인 전 약관이 배포로 자동 게시되면 안 된다")
  void seededLocales_areKoOnly() {
    assertThat(ConsentDocumentInitializer.SEEDED_LOCALES).containsExactly(AppLocale.KO);
  }

  @Test
  @DisplayName("필수 여부는 언어와 상관없이 법이 정한 값으로 바로잡는다 — 관리자 화면으로 게시한 문서도 포함")
  void syncsRequiredForEveryLocale() {
    ConsentDocument english = new ConsentDocument();
    english.setConsentKey(ConsentKey.TERMS);
    english.setLocale("en");
    english.setRequired(false); // 잘못 남은 값
    ConsentDocument marketing = new ConsentDocument();
    marketing.setConsentKey(ConsentKey.MARKETING);
    marketing.setLocale("en");
    marketing.setRequired(true); // 선택 항목이 필수로 남은 값
    when(repository.findAll()).thenReturn(List.of(english, marketing));

    initializer.run(null);

    assertThat(english.isRequired()).isTrue();
    assertThat(marketing.isRequired()).isFalse();
  }
}
```

- [ ] **Step 3: 실행해 실패를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.consent.infrastructure.config.ConsentDocumentInitializerTest'`
Expected: FAIL — 컴파일 오류(`bodyResource`·`getKoLabel`·`SEEDED_LOCALES` 가 없다).

- [ ] **Step 4: 파일을 옮긴다**

Run:
```bash
cd server/src/main/resources/consent && mkdir ko && git mv terms.txt privacy.txt overseas.txt age.txt marketing.txt ko/ && shasum -a 256 ko/*.txt
```
Expected: Step 1 의 다섯 해시와 같다(파일 이름 앞에 `ko/`).

- [ ] **Step 5: `ConsentKey` 를 고친다**

`ConsentKey.java` 25~51행(enum 선언부 전체)을 아래로 바꾼다. 위의 클래스 javadoc(6~22행)은 그대로 두고, 아래 두 문단을 그 javadoc 끝에 덧붙인다.

```java
 *
 * <p>{@code koLabel}·{@code koSummary} 는 <b>한국어 시드용 기본값</b>이다. 문서의 이름·요약은 언어마다
 * 약관 문서({@code ConsentDocument})가 자기 값을 들고 있고, 앱 응답과 관리자 화면은 그 값을 쓴다.
 * 한국어를 코드에 두는 곳은 여기 하나뿐이며 {@code ConsentDocumentInitializer} 만 읽는다.
```

```java
@Getter
@RequiredArgsConstructor
public enum ConsentKey {

  TERMS("termsAgreed", "서비스 이용약관", true,
    "이룸을 어떻게 쓰고, 무엇을 보장하는지", "terms.txt"),

  PRIVACY("privacyAgreed", "개인정보 수집·이용", true,
    "무엇을 모으고 언제까지 보관하는지", "privacy.txt"),

  OVERSEAS_TRANSFER("overseasTransferAgreed", "개인정보 국외 이전", true,
    "카드를 만들 때 해외 AI 서비스로 전달돼요", "overseas.txt"),

  // 나이 확인은 **계정을 만드는 보호자** 기준이다. 이룸이에게는 나이 제한이 없다 (#226).
  AGE_CONFIRM("guardianConfirmed", "만 14세 이상입니다", true,
    "계정을 만드는 보호자님의 나이를 확인해요", "age.txt"),

  MARKETING("marketingAgreed", "서비스 소식 받기", false,
    "새 기능과 안내를 받아볼 수 있어요", "marketing.txt");

  /** 앱과 주고받는 필드명. 앱의 {@code ConsentItem.key} 와 같다. */
  private final String field;
  /** 한국어 시드용 이름. 다른 언어의 이름은 그 언어 문서가 가진다. */
  private final String koLabel;
  /** 법이 정한 필수 여부. DB 값보다 우선한다. */
  private final boolean required;
  /** 한국어 시드용 한 줄 요약. */
  private final String koSummary;
  /** 언어 폴더 안의 본문 파일 이름. */
  private final String bodyFile;

  /** 이 약관의 기본 본문이 있는 classpath 경로. 예: {@code consent/ko/terms.txt}. */
  public String bodyResource(AppLocale locale) {
    return "consent/" + locale.code() + "/" + bodyFile;
  }
}
```
import 에 `com.chuseok22.elumserver.common.locale.AppLocale` 를 더한다.

- [ ] **Step 6: Initializer 를 고친다**

`ConsentDocumentInitializer.java` 의 클래스 javadoc 두 번째 문단(`본문은 resources/consent/*.txt 에 있고…`)을 `resources/consent/ko/*.txt` 로 고치고, 33행~89행(필드·`run`·`syncRequired`·`readDefaultBody`)을 아래로 바꾼다. import 에 `com.chuseok22.elumserver.common.locale.AppLocale`, `java.util.List` 를 더한다.

```java
  /** 앱 번들이 들고 있는 버전과 같다. 첫 시딩에만 쓴다. */
  private static final String INITIAL_VERSION = "2026-09-21";

  /**
   * 시딩하는 언어. <b>한국어뿐이다.</b>
   *
   * <p>다른 언어의 본문 파일이 폴더에 들어왔다고 배포 한 번에 약관이 자동 게시되면 법무 확인을
   * 우회한다. 다른 언어는 관리자 화면의 "최초 게시"로만 연다. 이 목록을 늘리는 것은 그 언어의 이름·요약
   * 시드까지 갖춘 뒤의 별도 변경이어야 한다.
   */
  public static final List<AppLocale> SEEDED_LOCALES = List.of(AppLocale.KO);

  private final ConsentDocumentRepository consentDocumentRepository;

  @Override
  @Transactional
  public void run(ApplicationArguments args) {
    for (AppLocale locale : SEEDED_LOCALES) {
      for (ConsentKey key : ConsentKey.values()) {
        if (consentDocumentRepository.findByConsentKeyAndLocale(key, locale.code()).isPresent()) {
          continue;
        }
        String body = readDefaultBody(key, locale);
        if (body == null) {
          // 본문을 못 읽었는데 빈 문서를 만들면 앱이 빈 약관을 띄운다. 그것보다는
          // 문서가 아예 없어서 앱이 번들 기본값으로 떨어지는 편이 낫다.
          log.error("약관 기본 본문을 읽지 못해 문서를 만들지 않습니다. key={} locale={}", key, locale);
          continue;
        }
        ConsentDocument document = new ConsentDocument();
        document.setConsentKey(key);
        document.setLocale(locale.code());
        document.setVersion(INITIAL_VERSION);
        document.setLabel(key.getKoLabel());
        document.setSummary(key.getKoSummary());
        document.setBody(body);
        document.setRequired(key.isRequired());
        document.setPublishedAt(LocalDateTime.now());
        consentDocumentRepository.save(document);
        log.info("약관 문서를 생성했습니다. key={} locale={} version={}", key, locale, INITIAL_VERSION);
      }
    }
    // 필수 여부는 언어와 상관없이 법이 정한다. 관리자 화면으로 게시한 다른 언어 문서도 같이 맞춘다.
    consentDocumentRepository.findAll().forEach(this::syncRequired);
  }

  /**
   * 필수 여부만은 코드를 따른다. 본문은 관리자가 고친 것을 존중하지만, 필수 여부는 법이 정한
   * 값이라 DB에 다른 값이 남아 있으면 그게 사고다 (예전 화면에서 끈 흔적).
   */
  private void syncRequired(ConsentDocument document) {
    boolean lawful = document.getConsentKey().isRequired();
    if (document.isRequired() != lawful) {
      log.warn("약관 필수 여부가 법이 정한 값과 달라 바로잡습니다. key={} locale={} {} -> {}",
        document.getConsentKey(), document.getLocale(), document.isRequired(), lawful);
      document.setRequired(lawful);
    }
  }

  private String readDefaultBody(ConsentKey key, AppLocale locale) {
    String path = key.bodyResource(locale);
    ClassPathResource resource = new ClassPathResource(path);
    try (var stream = resource.getInputStream()) {
      return StreamUtils.copyToString(stream, StandardCharsets.UTF_8).strip();
    } catch (IOException e) {
      log.error("약관 본문 파일을 읽지 못했습니다. path={}", path, e);
      return null;
    }
  }
}
```

- [ ] **Step 7: 옛 경로를 읽는 시험 둘을 고친다**

`WithdrawnRetentionMatchesPrivacyPolicyTest.java` 21~27행의 경로와 메시지를 바꾼다.

```java
      .getResourceAsStream("/consent/ko/privacy.txt")) {
      assertThat(in).as("consent/ko/privacy.txt 가 클래스패스에 있다").isNotNull();
```

`ConsentDocumentServiceTest.java` 62~72행 `document(...)` 도우미의 두 줄을 바꾼다.

```java
    document.setLabel(key.getKoLabel());
    document.setSummary(key.getKoSummary());
```

`client/test/consent_body_test.dart` 295~312행 — **원본이 없으면 조용히 넘기던 줄을 막는다.** 옛 경로가 사라지면 `continue` 때문에 이 시험이 아무것도 검사하지 않은 채 통과하게 된다. 서버 폴더가 있는 환경에서는 파일이 반드시 있어야 한다.

```dart
    test('L5 서버 원본(resources/consent/ko)도 번들과 같은 덩이로 나뉜다 (#376)', () {
      const files = {
        'termsAgreed': 'terms.txt',
        'privacyAgreed': 'privacy.txt',
        'overseasTransferAgreed': 'overseas.txt',
        'guardianConfirmed': 'age.txt',
        'marketingAgreed': 'marketing.txt',
      };
      // 클라이언트만 받은 환경에서는 서버 폴더가 없다. 있는데 파일이 없으면 경로가 바뀐 것이다 —
      // 조용히 건너뛰면 이 시험이 아무것도 검사하지 않은 채 초록불이 된다.
      final serverPresent = Directory('../server/src/main/resources').existsSync();
      for (final MapEntry(:key, :value) in files.entries) {
        final file = File('../server/src/main/resources/consent/ko/$value');
        if (!serverPresent) continue;
        expect(file.existsSync(), isTrue, reason: '$value 원본 경로가 바뀌었다');
        final bundle = consentItems.firstWhere((e) => e.key == key);
        expect(
          parseConsentBody(file.readAsStringSync()),
          parseConsentBody(bundle.body),
          reason: '$value 가 번들과 다르게 나뉜다',
        );
      }
    });
```
(`dart:io` 는 이 파일이 이미 `File` 을 쓰므로 import 되어 있다.)

- [ ] **Step 8: 통과를 확인한다**

Run:
```bash
cd server && ./gradlew test --tests 'com.chuseok22.elumserver.consent.infrastructure.config.ConsentDocumentInitializerTest' --tests 'com.chuseok22.elumserver.member.WithdrawnRetentionMatchesPrivacyPolicyTest' --tests 'com.chuseok22.elumserver.consent.application.service.ConsentDocumentServiceTest'
cd ../client && flutter test test/consent_body_test.dart
```
Expected: 서버 PASS(신규 5건 + 기존), 클라 PASS.

- [ ] **Step 9: 커밋 (`/pro-commit`)**

```bash
git add server/src/main/resources/consent \
  server/src/main/java/com/chuseok22/elumserver/consent/core/ConsentKey.java \
  server/src/main/java/com/chuseok22/elumserver/consent/infrastructure/config/ConsentDocumentInitializer.java \
  server/src/test/java/com/chuseok22/elumserver/consent/infrastructure/config/ConsentDocumentInitializerTest.java \
  server/src/test/java/com/chuseok22/elumserver/member/WithdrawnRetentionMatchesPrivacyPolicyTest.java \
  server/src/test/java/com/chuseok22/elumserver/consent/application/service/ConsentDocumentServiceTest.java \
  client/test/consent_body_test.dart
```

---

## Task 3: `ConsentDocumentService` 언어별 조회·게시·수정

**Files:**
- Modify: `server/src/main/java/com/chuseok22/elumserver/consent/application/service/ConsentDocumentService.java:1-192` (전체 교체)
- Modify: `server/src/main/java/com/chuseok22/elumserver/consent/infrastructure/repository/ConsentDocumentRepository.java` (옛 조회 두 줄 삭제)
- Modify: `server/src/main/java/com/chuseok22/elumserver/consent/infrastructure/repository/ConsentDocumentHistoryRepository.java` (옛 조회 삭제)
- Modify: `server/src/main/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorCode.java:163` 아래에 두 줄 추가
- Modify: `server/src/test/java/com/chuseok22/elumserver/consent/application/service/ConsentDocumentServiceTest.java:56-72, 183-190`
- Test: `server/src/test/java/com/chuseok22/elumserver/consent/application/service/ConsentDocumentServiceLocaleTest.java` (새)

**Interfaces:**
- Consumes: `AppLocale`, Task 1 의 저장소 조회, Task 2 의 `ConsentKey#getKoLabel`
- Produces (모두 `ConsentDocumentService`):
  - `List<ConsentDocument> getAll(AppLocale)` — 그 언어에 있는 문서 전부, `ConsentKey` 선언 순서
  - `List<ConsentDocument> getPublished(AppLocale)` — **필수 4종이 모두 있으면** `getAll`, 아니면 빈 목록
  - `boolean isPublished(AppLocale)`
  - `Optional<ConsentDocument> find(ConsentKey, AppLocale)`, `ConsentDocument get(ConsentKey, AppLocale)`
  - `List<ConsentDocumentHistory> getHistory(ConsentKey, AppLocale)`
  - `String bundleVersion(AppLocale)` — 그 언어의 필수 문서 중 가장 최근 버전, 없으면 `""`
  - `UpdateResult update(ConsentKey, AppLocale, String label, String summary, String body, boolean bumpVersion, String newVersion, String changedBy, String reason)`
  - `ConsentDocument publish(ConsentKey, AppLocale, String label, String summary, String body, String version, String changedBy, String reason)` — 최초 게시
  - 옛 시그니처(`getAll()`, `get(key)`, `getHistory(key)`, `bundleVersion()`, `update(8인자)`)는 `AppLocale.KO` 로 위임하는 편의 메서드로 남긴다
  - `ConsentDocumentService.FIRST_PUBLISH_PREFIX = "[최초 게시] "`
  - `ErrorCode.CONSENT_LOCALE_NOT_PUBLISHED(400)`, `ErrorCode.CONSENT_ALREADY_PUBLISHED(409)`

- [ ] **Step 1: 실패하는 시험을 쓴다**

`server/src/test/java/com/chuseok22/elumserver/consent/application/service/ConsentDocumentServiceLocaleTest.java`:

```java
package com.chuseok22.elumserver.consent.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService.UpdateResult;
import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocumentHistory;
import com.chuseok22.elumserver.consent.infrastructure.repository.ConsentDocumentHistoryRepository;
import com.chuseok22.elumserver.consent.infrastructure.repository.ConsentDocumentRepository;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

/**
 * 약관이 (키, 언어) 한 쌍으로 움직이는지 (이슈 #521).
 *
 * <p>핵심은 둘이다. 없는 언어는 <b>다른 언어로 대체하지 않는다</b>(읽을 수 없는 언어로 동의를
 * 받지 않는다). 그리고 필수 4종이 다 있어야 그 언어가 열린다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ConsentDocumentServiceLocaleTest {

  @Mock
  private ConsentDocumentRepository documentRepository;
  @Mock
  private ConsentDocumentHistoryRepository historyRepository;

  private ConsentDocumentService service;
  private final List<ConsentDocument> stored = new ArrayList<>();

  @BeforeEach
  void setUp() {
    service = new ConsentDocumentService(documentRepository, historyRepository);
    when(documentRepository.findAllByLocale(any())).thenAnswer(invocation -> stored.stream()
      .filter(document -> document.getLocale().equals(invocation.getArgument(0))).toList());
    when(documentRepository.findByConsentKeyAndLocale(any(), any())).thenAnswer(invocation -> stored.stream()
      .filter(document -> document.getConsentKey() == invocation.getArgument(0)
        && document.getLocale().equals(invocation.getArgument(1)))
      .findFirst());
    when(documentRepository.save(any(ConsentDocument.class))).thenAnswer(invocation -> {
      ConsentDocument saved = invocation.getArgument(0);
      stored.add(saved);
      return saved;
    });
  }

  private ConsentDocument add(ConsentKey key, String locale, String version) {
    ConsentDocument document = new ConsentDocument();
    document.setConsentKey(key);
    document.setLocale(locale);
    document.setVersion(version);
    document.setLabel(key.getKoLabel());
    document.setSummary(key.getKoSummary());
    document.setBody("본문 " + locale);
    document.setRequired(key.isRequired());
    document.setPublishedAt(LocalDateTime.now());
    stored.add(document);
    return document;
  }

  private void addRequired(String locale, String version) {
    for (ConsentKey key : ConsentKey.values()) {
      if (key.isRequired()) {
        add(key, locale, version);
      }
    }
  }

  @Test
  @DisplayName("필수 4종이 모두 있어야 그 언어가 게시된 것이다")
  void getPublished_complete() {
    addRequired("en", "2026-10-02");
    add(ConsentKey.MARKETING, "en", "2026-10-02");

    assertThat(service.getPublished(AppLocale.EN)).hasSize(5);
    assertThat(service.isPublished(AppLocale.EN)).isTrue();
  }

  @Test
  @DisplayName("필수가 하나라도 빠지면 그 언어는 비어 있다 — 일부만 내보내면 동의 화면에서 필수 항목이 사라진다")
  void getPublished_incomplete_isEmpty() {
    add(ConsentKey.TERMS, "ja", "2026-10-02");
    add(ConsentKey.PRIVACY, "ja", "2026-10-02");

    assertThat(service.getPublished(AppLocale.JA)).isEmpty();
    assertThat(service.isPublished(AppLocale.JA)).isFalse();
  }

  @Test
  @DisplayName("선택 항목(소식 받기)이 없어도 필수 4종이 있으면 열린다")
  void getPublished_marketingOptional() {
    addRequired("es", "2026-10-02");

    assertThat(service.getPublished(AppLocale.ES)).hasSize(4);
  }

  @Test
  @DisplayName("없는 언어는 en 이나 ko 로 대체하지 않는다")
  void getPublished_doesNotFallBack() {
    addRequired("ko", "2026-09-21");
    addRequired("en", "2026-10-02");

    assertThat(service.getPublished(AppLocale.ZH)).isEmpty();
    // 영어도 한국어도 있지만 중국어 요청에 섞여 나오지 않는다.
    assertThat(service.getAll(AppLocale.ZH)).isEmpty();
  }

  @Test
  @DisplayName("묶음 버전은 그 언어의 필수 문서만 센다")
  void bundleVersion_perLocale() {
    addRequired("ko", "2026-09-21");
    addRequired("en", "2026-10-02");
    add(ConsentKey.MARKETING, "en", "2027-01-01");

    assertThat(service.bundleVersion(AppLocale.KO)).isEqualTo("2026-09-21");
    assertThat(service.bundleVersion(AppLocale.EN)).isEqualTo("2026-10-02");
    assertThat(service.bundleVersion(AppLocale.JA)).isEmpty();
  }

  @Test
  @DisplayName("최초 게시는 문서를 만들고 사유 앞에 [최초 게시] 를 붙여 이력에 남긴다")
  void publish_createsDocumentAndHistory() {
    ConsentDocument created = service.publish(ConsentKey.TERMS, AppLocale.EN, "Terms of Service",
      "How to use Elum", "Article 1\r\nPurpose", "2026-10-02", "kimchi", "법무 확인 완료");

    assertThat(created.getLocale()).isEqualTo("en");
    assertThat(created.getVersion()).isEqualTo("2026-10-02");
    assertThat(created.getBody()).isEqualTo("Article 1\nPurpose"); // CRLF 는 LF 로
    assertThat(created.isRequired()).isTrue();
    ArgumentCaptor<ConsentDocumentHistory> captor = ArgumentCaptor.forClass(ConsentDocumentHistory.class);
    verify(historyRepository).save(captor.capture());
    assertThat(captor.getValue().getLocale()).isEqualTo("en");
    assertThat(captor.getValue().getReason()).isEqualTo(ConsentDocumentService.FIRST_PUBLISH_PREFIX + "법무 확인 완료");
    assertThat(captor.getValue().getChangedBy()).isEqualTo("kimchi");
  }

  @Test
  @DisplayName("이미 게시된 (키, 언어) 에 다시 최초 게시하면 409 다 — 덮어쓰기는 수정으로 한다")
  void publish_duplicate_rejected() {
    add(ConsentKey.TERMS, "en", "2026-10-02");

    assertThatThrownBy(() -> service.publish(ConsentKey.TERMS, AppLocale.EN, "T", "S", "B", "2026-10-03", "a", "r"))
      .extracting("errorCode").isEqualTo(ErrorCode.CONSENT_ALREADY_PUBLISHED);
    verify(historyRepository, never()).save(any());
  }

  @Test
  @DisplayName("최초 게시도 사유가 필수다")
  void publish_reasonRequired() {
    assertThatThrownBy(() -> service.publish(ConsentKey.TERMS, AppLocale.EN, "T", "S", "B", "2026-10-02", "a", " "))
      .extracting("errorCode").isEqualTo(ErrorCode.CONSENT_REASON_REQUIRED);
  }

  @ParameterizedTest
  @ValueSource(strings = {"", "v1", "2026-9-2", "2026-02-30"})
  @DisplayName("최초 게시 버전은 날짜 형식이어야 한다 — 지금보다 늦어야 한다는 비교는 없다(처음이라 비교 대상이 없다)")
  void publish_versionMustBeDate(String version) {
    assertThatThrownBy(() -> service.publish(ConsentKey.TERMS, AppLocale.EN, "T", "S", "B", version, "a", "r"))
      .extracting("errorCode").isIn(ErrorCode.CONSENT_VERSION_REQUIRED, ErrorCode.CONSENT_VERSION_INVALID);
  }

  @Test
  @DisplayName("수정은 그 언어의 행만 고치고 이력에도 언어를 남긴다 — 한국어 행은 그대로다")
  void update_touchesOnlyThatLocale() {
    ConsentDocument ko = add(ConsentKey.TERMS, "ko", "2026-09-21");
    ConsentDocument en = add(ConsentKey.TERMS, "en", "2026-10-02");

    UpdateResult result = service.update(ConsentKey.TERMS, AppLocale.EN, "Terms", "Summary",
      "New body", false, null, "kimchi", "오타");

    assertThat(result).isEqualTo(UpdateResult.SAVED);
    assertThat(en.getBody()).isEqualTo("New body");
    assertThat(ko.getBody()).isEqualTo("본문 ko");
    ArgumentCaptor<ConsentDocumentHistory> captor = ArgumentCaptor.forClass(ConsentDocumentHistory.class);
    verify(historyRepository).save(captor.capture());
    assertThat(captor.getValue().getLocale()).isEqualTo("en");
    assertThat(captor.getValue().getBody()).isEqualTo("본문 en");
  }

  @Test
  @DisplayName("버전 올리기의 '더 늦어야 한다'는 그 언어의 현재 버전과 비교한다")
  void update_bumpComparesWithSameLocale() {
    add(ConsentKey.TERMS, "ko", "2026-12-01");
    add(ConsentKey.TERMS, "en", "2026-10-02");

    // 한국어 버전(2026-12-01)보다 이르지만 영어 버전(2026-10-02)보다는 늦으므로 통과한다.
    UpdateResult result = service.update(ConsentKey.TERMS, AppLocale.EN, "T", "S", "다른 본문",
      true, "2026-11-01", "a", "r");

    assertThat(result).isEqualTo(UpdateResult.SAVED_AND_BUMPED);
  }
}
```

- [ ] **Step 2: 실행해 실패를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.consent.application.service.ConsentDocumentServiceLocaleTest'`
Expected: FAIL — 컴파일 오류(`getPublished`·`publish`·`ErrorCode.CONSENT_ALREADY_PUBLISHED` 없음).

- [ ] **Step 3: 에러 코드를 더한다**

`ErrorCode.java` 163행(`CONSENT_VERSION_NOT_NEWER`) 바로 아래에 두 줄을 더한다.

```java
  CONSENT_ALREADY_PUBLISHED(HttpStatus.CONFLICT, "이미 게시된 약관이에요."),
  // 읽을 수 있는 약관이 없는 언어로는 동의를 받지 않는다. 앱은 재시도 안내를 띄운다 (이슈 #521).
  CONSENT_LOCALE_NOT_PUBLISHED(HttpStatus.BAD_REQUEST, "이 언어의 약관이 아직 게시되지 않았어요."),
```
> 계획 2 가 `ErrorCode` 문구를 `MessageSource` 로 옮기는 중이면(에러 코드 이름이 키), 두 코드의 문구를 계획 2 의 리소스 파일에도 같은 이름으로 더한다. 계획 2 가 아직이면 위 한국어 인자 그대로 두면 된다 — 계획 2 의 추출 작업이 이 줄도 같이 옮긴다.

- [ ] **Step 4: 서비스를 교체한다**

`ConsentDocumentService.java` 전체를 아래로 바꾼다.

```java
package com.chuseok22.elumserver.consent.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocumentHistory;
import com.chuseok22.elumserver.consent.infrastructure.repository.ConsentDocumentHistoryRepository;
import com.chuseok22.elumserver.consent.infrastructure.repository.ConsentDocumentRepository;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeParseException;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 약관 조회·게시·수정. <b>모든 조회는 (약관 키, 언어) 한 쌍</b>이다 (이슈 #521).
 *
 * <p>없는 언어는 다른 언어로 대체하지 않는다. 동의는 읽을 수 있는 언어로 받아야 성립하므로,
 * 영어 약관을 일본어 휴대폰에 내보내지 않는다.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ConsentDocumentService {

  /** DB 컬럼(VARCHAR 255) 한도. 넘기면 저장 순간 500이 난다. */
  public static final int TEXT_FIELD_MAX_LENGTH = 255;

  /** 최초 게시는 직전 본문이 없다. 게시한 본문을 그대로 이력에 남기고 사유 앞에 이 말머리를 붙인다. */
  public static final String FIRST_PUBLISH_PREFIX = "[최초 게시] ";

  /** 버전은 날짜 하나다. 문자열 비교가 곧 날짜 비교가 되도록 형식을 고정한다. */
  private static final Pattern VERSION_FORMAT = Pattern.compile("\\d{4}-\\d{2}-\\d{2}");

  private final ConsentDocumentRepository consentDocumentRepository;
  private final ConsentDocumentHistoryRepository consentDocumentHistoryRepository;

  /** 저장이 실제로 무엇을 했는지. 안내 문구는 체크박스가 아니라 이 결과를 보고 만든다. */
  public enum UpdateResult {
    /** 바뀐 것이 없어 저장하지 않았다. */
    UNCHANGED,
    /** 내용만 바꿨다. 버전은 그대로다. */
    SAVED,
    /** 내용을 바꾸고 버전도 올렸다. */
    SAVED_AND_BUMPED,
  }

  // ── 조회 ────────────────────────────────────────────

  /** 그 언어에 있는 문서 전부. {@code ConsentKey} 선언 순서대로 준다(앱 동의 화면의 항목 순서). */
  public List<ConsentDocument> getAll(AppLocale locale) {
    return consentDocumentRepository.findAllByLocale(locale.code()).stream()
      .sorted(Comparator.comparing(document -> document.getConsentKey().ordinal()))
      .toList();
  }

  /** 한국어. 언어를 아직 모르는 호출부용 편의 메서드다. */
  public List<ConsentDocument> getAll() {
    return getAll(AppLocale.KO);
  }

  /**
   * 앱에 내보낼 문서. <b>필수 4종이 모두 있어야</b> 내보낸다 — 일부만 내보내면 앱이 필수 항목이 빠진
   * 동의 화면을 띄우고, 서버는 네 항목 {@code @AssertTrue} 라 가입이 영영 안 된다. 하나라도 빠졌으면 빈
   * 목록이고, 앱은 그 언어를 "아직 열리지 않았다"고 본다.
   */
  public List<ConsentDocument> getPublished(AppLocale locale) {
    List<ConsentDocument> documents = getAll(locale);
    Set<ConsentKey> present = documents.stream()
      .map(ConsentDocument::getConsentKey)
      .collect(Collectors.toSet());
    boolean complete = java.util.Arrays.stream(ConsentKey.values())
      .filter(ConsentKey::isRequired)
      .allMatch(present::contains);
    return complete ? documents : List.of();
  }

  public boolean isPublished(AppLocale locale) {
    return !getPublished(locale).isEmpty();
  }

  public Optional<ConsentDocument> find(ConsentKey key, AppLocale locale) {
    return consentDocumentRepository.findByConsentKeyAndLocale(key, locale.code());
  }

  public ConsentDocument get(ConsentKey key, AppLocale locale) {
    return find(key, locale)
      .orElseThrow(() -> new CustomException(ErrorCode.CONSENT_DOCUMENT_NOT_FOUND));
  }

  public ConsentDocument get(ConsentKey key) {
    return get(key, AppLocale.KO);
  }

  public List<ConsentDocumentHistory> getHistory(ConsentKey key, AppLocale locale) {
    return consentDocumentHistoryRepository
      .findTop50ByConsentKeyAndLocaleOrderByCreatedAtDesc(key, locale.code());
  }

  public List<ConsentDocumentHistory> getHistory(ConsentKey key) {
    return getHistory(key, AppLocale.KO);
  }

  /**
   * 회원이 동의했다고 기록할 <b>묶음 버전</b>. 그 언어의 문서만 센다.
   *
   * <p><b>필수 문서만 센다.</b> 나중에 재동의를 판정할 때 이 값과 회원 기록을 견주게
   * 되는데, 선택 항목(소식 받기)까지 세면 동의할 의무가 없는 항목이 바뀐 것만으로
   * 전원을 다시 막아 세우게 된다.
   *
   * <p>버전은 {@link #VERSION_FORMAT} 날짜만 받으므로 문자열 순서가 곧 시간 순서다.
   * 전에는 형식을 보지 않아 {@code v2} 한 번에 묶음 버전이 영영 고정됐다 (#278 QA).
   *
   * <p>⚠️ 지금은 기록에만 쓴다. 재동의 판정({@code Member#hasRequiredConsents})은
   * 아직 버전을 보지 않는다.
   */
  public String bundleVersion(AppLocale locale) {
    return getAll(locale).stream()
      .filter(document -> document.getConsentKey().isRequired())
      .map(ConsentDocument::getVersion)
      .max(Comparator.naturalOrder())
      // 문서가 하나도 없으면(초기화 실패·아직 열리지 않은 언어) 빈 문자열이다.
      .orElse("");
  }

  public String bundleVersion() {
    return bundleVersion(AppLocale.KO);
  }

  // ── 최초 게시 ───────────────────────────────────────

  /**
   * 새 언어의 약관 한 편을 처음 게시한다. 이미 있으면 409 다 — 고치는 것은 {@link #update} 다.
   *
   * <p>필수 4종이 모두 게시돼야 그 언어가 열린다({@link #getPublished}). 하나씩 게시해도 마지막 필수가
   * 들어가기 전까지는 앱에 나가지 않는다.
   *
   * <p>직전 본문이 없으므로 게시한 본문을 그대로 이력에 남긴다. 누가 왜 게시했는지가 근거다.
   */
  @Transactional
  public ConsentDocument publish(
    ConsentKey key,
    AppLocale locale,
    String label,
    String summary,
    String body,
    String version,
    String changedBy,
    String reason
  ) {
    requireReason(reason);
    Text text = normalize(label, summary, body);
    String publishedVersion = requireDateVersion(version);
    if (find(key, locale).isPresent()) {
      throw new CustomException(ErrorCode.CONSENT_ALREADY_PUBLISHED);
    }

    ConsentDocument document = new ConsentDocument();
    document.setConsentKey(key);
    document.setLocale(locale.code());
    document.setVersion(publishedVersion);
    document.setLabel(text.label());
    document.setSummary(text.summary());
    document.setBody(text.body());
    document.setRequired(key.isRequired());
    document.setPublishedAt(LocalDateTime.now());
    ConsentDocument saved = consentDocumentRepository.save(document);

    consentDocumentHistoryRepository.save(
      snapshotOf(saved, changedBy, FIRST_PUBLISH_PREFIX + reason.strip()));
    return saved;
  }

  // ── 수정 ────────────────────────────────────────────

  /**
   * 약관을 고친다. <b>고치기 직전 내용을 먼저 이력으로 남긴다</b> — 같은 트랜잭션이라
   * 이력 없는 덮어쓰기가 생길 수 없다.
   *
   * <p>필수 여부는 받지 않는다. 법이 정한 값이라 {@link ConsentKey#isRequired()} 를 따른다.
   *
   * @param bumpVersion 켰을 때만 버전을 올린다. 오타를 고칠 때마다 올리면 회원마다 어떤
   *                    문구에 동의했는지 가리기 어려워지므로 관리자가 고르게 둔다.
   * @return 실제로 한 일. 호출부는 이것으로 안내 문구를 만든다.
   */
  @Transactional
  public UpdateResult update(
    ConsentKey key,
    AppLocale locale,
    String label,
    String summary,
    String body,
    boolean bumpVersion,
    String newVersion,
    String changedBy,
    String reason
  ) {
    // 약관은 법적 문서라 "왜 바꿨는지"가 곧 근거다. 화면이 막더라도 요청을 직접 보내면
    // 뚫리므로 여기서 다시 막는다.
    requireReason(reason);
    Text text = normalize(label, summary, body);

    ConsentDocument document = get(key, locale);
    String bumpTo = bumpVersion ? validateNewVersion(document.getVersion(), newVersion) : null;

    boolean contentChanged = !text.body().equals(document.getBody())
      || !text.label().equals(document.getLabel())
      || !text.summary().equals(document.getSummary());

    if (!contentChanged && bumpTo == null) {
      return UpdateResult.UNCHANGED;
    }

    consentDocumentHistoryRepository.save(snapshotOf(document, changedBy, reason));

    document.setLabel(text.label());
    document.setSummary(text.summary());
    document.setBody(text.body());
    document.setRequired(key.isRequired());
    if (bumpTo == null) {
      return UpdateResult.SAVED;
    }
    document.setVersion(bumpTo);
    document.setPublishedAt(LocalDateTime.now());
    return UpdateResult.SAVED_AND_BUMPED;
  }

  /** 한국어 편의 메서드. */
  @Transactional
  public UpdateResult update(
    ConsentKey key,
    String label,
    String summary,
    String body,
    boolean bumpVersion,
    String newVersion,
    String changedBy,
    String reason
  ) {
    return update(key, AppLocale.KO, label, summary, body, bumpVersion, newVersion, changedBy, reason);
  }

  // ── 검증 ────────────────────────────────────────────

  private record Text(String label, String summary, String body) {

  }

  private void requireReason(String reason) {
    if (reason == null || reason.isBlank()) {
      throw new CustomException(ErrorCode.CONSENT_REASON_REQUIRED);
    }
  }

  /**
   * 브라우저 textarea 는 줄바꿈을 CRLF 로 제출한다. 정규화하지 않으면 저장만 눌러도
   * 바이트가 달라져 가짜 이력이 쌓이고, 앱 화면에 CR 이 섞여 들어간다.
   *
   * <p>공백만 있는 값은 비어 있는 것이다. 브라우저의 required 는 공백을 통과시킨다.
   * 한 항목이라도 비면 앱이 서버 약관 전체를 버리고 기본값으로 떨어지는데, 관리자는
   * "저장했습니다"를 보고 반영된 줄 안다 (#278 QA).
   */
  private Text normalize(String label, String summary, String body) {
    String normalizedBody = body == null ? "" : body.replace("\r\n", "\n").strip();
    String normalizedLabel = label == null ? "" : label.strip();
    String normalizedSummary = summary == null ? "" : summary.strip();
    if (normalizedBody.isEmpty() || normalizedLabel.isEmpty() || normalizedSummary.isEmpty()) {
      throw new CustomException(ErrorCode.CONSENT_FIELD_BLANK);
    }
    if (normalizedLabel.length() > TEXT_FIELD_MAX_LENGTH
      || normalizedSummary.length() > TEXT_FIELD_MAX_LENGTH) {
      throw new CustomException(ErrorCode.CONSENT_FIELD_TOO_LONG);
    }
    return new Text(normalizedLabel, normalizedSummary, normalizedBody);
  }

  /** 버전이 비어 있지 않고, 날짜 형식이며, 실제로 있는 날짜인지. */
  private String requireDateVersion(String version) {
    String candidate = version == null ? "" : version.strip();
    if (candidate.isEmpty()) {
      throw new CustomException(ErrorCode.CONSENT_VERSION_REQUIRED);
    }
    if (!VERSION_FORMAT.matcher(candidate).matches()) {
      throw new CustomException(ErrorCode.CONSENT_VERSION_INVALID);
    }
    try {
      LocalDate.parse(candidate); // 2026-02-30 같은 없는 날짜를 거른다
    } catch (DateTimeParseException e) {
      throw new CustomException(ErrorCode.CONSENT_VERSION_INVALID);
    }
    return candidate;
  }

  /**
   * 버전을 올리기로 했을 때의 새 값을 검사한다.
   *
   * <p>전에는 칸을 비워도, 지금과 같아도, 날짜가 아니어도 받았다. 그러고는 체크박스만 보고
   * "버전을 올렸습니다"라고 안내했다 (#278 QA).
   */
  private String validateNewVersion(String current, String newVersion) {
    String candidate = requireDateVersion(newVersion);
    // 과거로 되돌리면 "그 사람이 어떤 문구에 동의했나"의 순서가 뒤집힌다.
    if (candidate.compareTo(current) <= 0) {
      throw new CustomException(ErrorCode.CONSENT_VERSION_NOT_NEWER);
    }
    return candidate;
  }

  /** 바뀌기 직전 상태를 그대로 떠낸다. */
  private ConsentDocumentHistory snapshotOf(
    ConsentDocument document, String changedBy, String reason
  ) {
    ConsentDocumentHistory history = new ConsentDocumentHistory();
    history.setConsentKey(document.getConsentKey());
    history.setLocale(document.getLocale());
    history.setVersion(document.getVersion());
    history.setLabel(document.getLabel());
    history.setSummary(document.getSummary());
    history.setBody(document.getBody());
    history.setRequired(document.isRequired());
    history.setChangedBy(changedBy == null || changedBy.isBlank() ? "알 수 없음" : changedBy);
    history.setReason(reason.strip());
    return history;
  }
}
```

- [ ] **Step 5: 옛 조회를 지운다**

`ConsentDocumentRepository.java` 에서 `findByConsentKey(ConsentKey)` 와 `existsByConsentKey(ConsentKey)` 두 줄을 지운다. `ConsentDocumentHistoryRepository.java` 에서 `findTop50ByConsentKeyOrderByCreatedAtDesc(ConsentKey)` 를 지운다.

Run: `cd server && ./gradlew compileJava compileTestJava`
Expected: 컴파일 오류가 `ConsentDocumentServiceTest`(옛 조회를 목킹)에서만 난다 — 다음 Step 에서 고친다.

- [ ] **Step 6: 기존 시험 세 곳을 새 조회로 옮긴다**

`ConsentDocumentServiceTest.java`:

1. 56~58행(`setUp` 의 `terms = document(...)` 와 `when(...)`)을 바꾼다.
```java
    terms = document(ConsentKey.TERMS, "2026-09-18");
    when(documentRepository.findByConsentKeyAndLocale(ConsentKey.TERMS, "ko")).thenReturn(Optional.of(terms));
```
2. 62~72행 `document(...)` 도우미에 한 줄을 더한다(Task 2 에서 `getKoLabel` 로 이미 고쳤다).
```java
    document.setLocale("ko");
```
3. 마지막 시험(`bundleVersion_countsRequiredOnly`)의 `findAll` 목킹을 바꾼다.
```java
    when(documentRepository.findAllByLocale("ko")).thenReturn(List.of(terms, privacy, marketing));
```
(나머지 시험은 8인자 `update(...)` 편의 메서드와 `bundleVersion()` 을 그대로 쓴다.)

- [ ] **Step 7: 통과를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.consent.*'`
Expected: PASS — `ConsentDocumentServiceTest`(기존 전부) + `ConsentDocumentServiceLocaleTest`(신규 11건) + Task 1·2 시험.

- [ ] **Step 8: 커밋 (`/pro-commit`)**

```bash
git add server/src/main/java/com/chuseok22/elumserver/consent/application/service/ConsentDocumentService.java \
  server/src/main/java/com/chuseok22/elumserver/consent/infrastructure/repository/ConsentDocumentRepository.java \
  server/src/main/java/com/chuseok22/elumserver/consent/infrastructure/repository/ConsentDocumentHistoryRepository.java \
  server/src/main/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorCode.java \
  server/src/test/java/com/chuseok22/elumserver/consent/application/service/ConsentDocumentServiceTest.java \
  server/src/test/java/com/chuseok22/elumserver/consent/application/service/ConsentDocumentServiceLocaleTest.java
```

---

## Task 4: 약관 조회 API 와 동의 기록의 언어

**Files:**
- Modify: `server/src/main/java/com/chuseok22/elumserver/consent/application/controller/ConsentController.java:12-32`
- Modify: `server/src/main/java/com/chuseok22/elumserver/consent/application/controller/ConsentControllerDocs.java:19-58`
- Modify: `server/src/main/java/com/chuseok22/elumserver/member/application/dto/request/MemberConsentRequest.java:28-32`
- Modify: `server/src/main/java/com/chuseok22/elumserver/member/application/service/MemberService.java:3-27, 34-47, 154-168`
- Modify: `server/src/main/java/com/chuseok22/elumserver/member/application/controller/MemberController.java:48-54`
- Modify: `server/src/main/java/com/chuseok22/elumserver/member/application/controller/MemberControllerDocs.java:296-317`
- Modify: `server/src/test/java/com/chuseok22/elumserver/member/application/service/MemberServiceTest.java` (`@Mock` 추가 + 신규 시험)
- Test: `server/src/test/java/com/chuseok22/elumserver/consent/application/controller/ConsentControllerTest.java` (새)

**Interfaces:**
- Consumes: `AppLocale.fromAcceptLanguage(String)`, `AppLocale.fromCode(String)`, `ConsentDocumentService#getPublished(AppLocale)`, `#bundleVersion(AppLocale)`, `#isPublished(AppLocale)`, `Member#setConsentLocale(String)`
- Produces:
  - `ConsentController#documents(String acceptLanguage): ResponseEntity<ConsentDocumentsResponse>` — `Content-Language: <언어>`, `Vary: Accept-Language`, 게시되지 않은 언어는 `200 {"version":"","documents":[]}`
  - `MemberConsentRequest#consentLocale(): String` (선택 필드, 마지막 컴포넌트)
  - `MemberService#agreeConsents(String memberId, MemberConsentRequest request, AppLocale requestLocale): MemberConsentResponse` — 게시되지 않은 언어면 `CONSENT_LOCALE_NOT_PUBLISHED`, 응답 모양은 그대로

- [ ] **Step 1: 실패하는 컨트롤러 시험을 쓴다**

`server/src/test/java/com/chuseok22/elumserver/consent/application/controller/ConsentControllerTest.java`:

```java
package com.chuseok22.elumserver.consent.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.consent.application.dto.response.ConsentDocumentsResponse;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService;
import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.LocalDateTime;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;

/**
 * 약관 조회 API 의 언어 처리 (이슈 #521).
 *
 * <p>헤더가 없는 요청(이미 배포된 앱)의 응답 본문은 이전과 같아야 하고, 게시되지 않은 언어는
 * 다른 언어로 대체하지 않고 빈 목록을 준다.
 */
class ConsentControllerTest {

  private final ConsentDocumentService service = mock(ConsentDocumentService.class);
  private final ConsentController controller = new ConsentController(service);

  private ConsentDocument terms(String locale) {
    ConsentDocument document = new ConsentDocument();
    document.setConsentKey(ConsentKey.TERMS);
    document.setLocale(locale);
    document.setVersion("2026-09-21");
    document.setLabel("서비스 이용약관");
    document.setSummary("요약");
    document.setBody("제1조");
    document.setRequired(true);
    document.setPublishedAt(LocalDateTime.of(2026, 9, 21, 0, 0));
    return document;
  }

  @Test
  @DisplayName("헤더가 없으면 한국어다 — 본문 JSON 은 이전과 같은 모양이다")
  void noHeader_isKo_sameJsonShape() throws Exception {
    when(service.getPublished(AppLocale.KO)).thenReturn(List.of(terms("ko")));
    when(service.bundleVersion(AppLocale.KO)).thenReturn("2026-09-21");

    ResponseEntity<ConsentDocumentsResponse> response = controller.documents(null);

    assertThat(response.getStatusCode().value()).isEqualTo(200);
    assertThat(new ObjectMapper().writeValueAsString(response.getBody())).isEqualTo(
      "{\"version\":\"2026-09-21\",\"documents\":[{\"key\":\"termsAgreed\",\"label\":\"서비스 이용약관\","
        + "\"required\":true,\"summary\":\"요약\",\"body\":\"제1조\",\"version\":\"2026-09-21\"}]}");
    assertThat(response.getHeaders().getFirst(HttpHeaders.CONTENT_LANGUAGE)).isEqualTo("ko");
    assertThat(response.getHeaders().getVary()).contains("Accept-Language");
  }

  @Test
  @DisplayName("게시되지 않은 언어는 200 과 빈 목록이다 — en 이나 ko 로 대체하지 않는다")
  void unpublishedLocale_emptyNotFallback() {
    when(service.getPublished(AppLocale.JA)).thenReturn(List.of());

    ResponseEntity<ConsentDocumentsResponse> response = controller.documents("ja");

    assertThat(response.getStatusCode().value()).isEqualTo(200);
    assertThat(response.getBody().documents()).isEmpty();
    assertThat(response.getBody().version()).isEmpty();
    assertThat(response.getHeaders().getFirst(HttpHeaders.CONTENT_LANGUAGE)).isEqualTo("ja");
    verify(service, never()).getPublished(AppLocale.EN);
    verify(service, never()).getPublished(AppLocale.KO);
  }

  @Test
  @DisplayName("zh-Hans 는 zh 로, 미지원·깨진 값은 en 으로 읽는다(C1)")
  void acceptLanguage_followsContract() {
    when(service.getPublished(AppLocale.ZH)).thenReturn(List.of());
    when(service.getPublished(AppLocale.EN)).thenReturn(List.of());

    assertThat(controller.documents("zh-Hans").getHeaders().getFirst(HttpHeaders.CONTENT_LANGUAGE)).isEqualTo("zh");
    assertThat(controller.documents("xx-YY").getHeaders().getFirst(HttpHeaders.CONTENT_LANGUAGE)).isEqualTo("en");
  }

  @Test
  @DisplayName("게시된 언어는 그 언어 문서와 그 언어의 묶음 버전을 준다")
  void publishedLocale_returnsItsDocuments() {
    when(service.getPublished(AppLocale.EN)).thenReturn(List.of(terms("en")));
    when(service.bundleVersion(AppLocale.EN)).thenReturn("2026-10-02");

    ResponseEntity<ConsentDocumentsResponse> response = controller.documents("en");

    assertThat(response.getBody().version()).isEqualTo("2026-10-02");
    assertThat(response.getBody().documents()).hasSize(1);
  }
}
```

- [ ] **Step 2: 실행해 실패를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.consent.application.controller.ConsentControllerTest'`
Expected: FAIL — 컴파일 오류(`documents(String)` 없음).

- [ ] **Step 3: 컨트롤러를 고친다**

`ConsentController.java` 17~32행을 바꾼다. import 에 `com.chuseok22.elumserver.common.locale.AppLocale`, `org.springframework.http.HttpHeaders`, `org.springframework.web.bind.annotation.RequestHeader`, `java.util.List`, `com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument` 를 더한다.

```java
@RestController
@RequiredArgsConstructor
public class ConsentController implements ConsentControllerDocs {

  private final ConsentDocumentService consentDocumentService;

  @Override
  @LogMonitoring(logParameters = true, logExecutionTime = true)
  @GetMapping("/api/consents/documents")
  public ResponseEntity<ConsentDocumentsResponse> documents(
    @RequestHeader(value = HttpHeaders.ACCEPT_LANGUAGE, required = false) String acceptLanguage
  ) {
    // 헤더가 없으면 ko(이미 배포된 앱), 5개 밖이거나 깨진 값이면 en 이다 (C1).
    AppLocale locale = AppLocale.fromAcceptLanguage(acceptLanguage);
    // 그 언어의 게시본만 준다. 없으면 빈 목록이다 — 다른 언어 약관으로 동의받지 않는다.
    List<ConsentDocument> documents = consentDocumentService.getPublished(locale);
    String version = documents.isEmpty() ? "" : consentDocumentService.bundleVersion(locale);
    return ResponseEntity.ok()
      // 앱이 "요청한 언어가 온 것"을 확인하고 캐시에 넣는다. 본문 모양은 그대로 둔다.
      .header(HttpHeaders.CONTENT_LANGUAGE, locale.code())
      .header(HttpHeaders.VARY, HttpHeaders.ACCEPT_LANGUAGE)
      .body(new ConsentDocumentsResponse(
        version,
        documents.stream().map(ConsentDocumentResponse::from).toList()
      ));
  }
}
```

`ConsentControllerDocs.java` — 58행의 `ResponseEntity<ConsentDocumentsResponse> documents();` 를 바꾸고, import 에 `io.swagger.v3.oas.annotations.Parameter` 를 더하고, 설명(`description`)의 마지막 문단(`version 은 필수 항목 중…` 앞)에 두 문단을 더한다.

```java
      **언어.** `Accept-Language` 로 고릅니다(`ko` `en` `ja` `zh-Hans` `es`). 헤더가 없으면 `ko`, 5개
      밖이거나 깨진 값이면 `en` 입니다. **그 언어의 게시본만** 줍니다 — 없는 언어는 `en` 으로 대체하지
      않고 `documents` 가 빈 목록(`version` 도 빈 문자열)입니다. 읽을 수 없는 언어로 동의를 받을 수
      없기 때문입니다. 앱은 이때 "약관을 불러오지 못했어요"와 재시도를 보여줍니다.
      응답의 `Content-Language` 가 실제로 준 언어입니다. 앱은 요청한 언어와 같을 때만 캐시에 넣습니다.
```
```java
  ResponseEntity<ConsentDocumentsResponse> documents(
    @Parameter(description = "화면 언어. ko, en, ja, zh-Hans, es. 비우면 ko", example = "ko")
    String acceptLanguage
  );
```

- [ ] **Step 4: 컨트롤러 시험 통과를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.consent.application.controller.ConsentControllerTest'`
Expected: PASS (4건).

- [ ] **Step 5: 동의 기록의 실패 시험을 쓴다**

`MemberServiceTest.java` — import 에 `com.chuseok22.elumserver.common.locale.AppLocale`, `com.chuseok22.elumserver.consent.application.service.ConsentDocumentService`, `com.chuseok22.elumserver.member.application.dto.request.MemberConsentRequest` 를 더하고(이미 있으면 생략), 79행(`@InjectMocks` 위)에 목을 더한다.

```java
  @Mock
  private ConsentDocumentService consentDocumentService;
```
파일 끝(마지막 `}` 앞)에 시험 다섯 개를 더한다.

```java
  private MemberConsentRequest consentRequest(String consentLocale) {
    return new MemberConsentRequest(true, true, true, true, false, "2026-10-01", consentLocale);
  }

  @Test
  @DisplayName("헤더도 본문 언어도 없으면 ko 로 기록한다 — 이미 배포된 앱")
  void agreeConsents_noLocale_recordsKo() {
    Member member = activeMember("member-c1");
    when(memberRepository.findById("member-c1")).thenReturn(Optional.of(member));
    when(consentDocumentService.isPublished(AppLocale.KO)).thenReturn(true);

    memberService.agreeConsents("member-c1", consentRequest(null), AppLocale.fromAcceptLanguage(null));

    assertThat(member.getConsentLocale()).isEqualTo("ko");
    assertThat(member.getConsentVersion()).isEqualTo("2026-10-01");
  }

  @Test
  @DisplayName("본문의 consentLocale 이 헤더보다 먼저다 — 증빙은 사용자가 본 약관의 언어다")
  void agreeConsents_bodyLocaleWinsOverHeader() {
    Member member = activeMember("member-c2");
    when(memberRepository.findById("member-c2")).thenReturn(Optional.of(member));
    when(consentDocumentService.isPublished(AppLocale.JA)).thenReturn(true);

    memberService.agreeConsents("member-c2", consentRequest("ja"), AppLocale.EN);

    assertThat(member.getConsentLocale()).isEqualTo("ja");
  }

  @Test
  @DisplayName("게시되지 않은 언어로는 동의를 받지 않는다 — 회원 기록은 바뀌지 않는다")
  void agreeConsents_unpublishedLocale_rejected() {
    Member member = new Member();
    member.setId("member-c3");
    member.setStatus(MemberStatus.ACTIVE);
    when(memberRepository.findById("member-c3")).thenReturn(Optional.of(member));
    when(consentDocumentService.isPublished(AppLocale.ES)).thenReturn(false);

    assertThatThrownBy(() -> memberService.agreeConsents("member-c3", consentRequest(null), AppLocale.ES))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.CONSENT_LOCALE_NOT_PUBLISHED);
    assertThat(member.getTermsAgreed()).isFalse();
    assertThat(member.getConsentedAt()).isNull();
    assertThat(member.getConsentLocale()).isNull();
  }

  @Test
  @DisplayName("모르는 언어 코드를 본문에 보내면 같은 400 이다")
  void agreeConsents_unknownBodyLocale_rejected() {
    Member member = activeMember("member-c4");
    when(memberRepository.findById("member-c4")).thenReturn(Optional.of(member));

    assertThatThrownBy(() -> memberService.agreeConsents("member-c4", consentRequest("fr"), AppLocale.KO))
      .extracting("errorCode").isEqualTo(ErrorCode.CONSENT_LOCALE_NOT_PUBLISHED);
  }

  @Test
  @DisplayName("대문자·공백이 섞인 언어 코드도 읽는다")
  void agreeConsents_bodyLocaleIsNormalized() {
    Member member = activeMember("member-c5");
    when(memberRepository.findById("member-c5")).thenReturn(Optional.of(member));
    when(consentDocumentService.isPublished(AppLocale.EN)).thenReturn(true);

    memberService.agreeConsents("member-c5", consentRequest(" EN "), AppLocale.KO);

    assertThat(member.getConsentLocale()).isEqualTo("en");
  }
```
(`assertThatThrownBy`·`CustomException`·`ErrorCode`·`MemberStatus` import 가 이 파일에 없으면 더한다.)

- [ ] **Step 6: 실행해 실패를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.member.application.service.MemberServiceTest'`
Expected: FAIL — 컴파일 오류(`MemberConsentRequest` 인자 수, `agreeConsents` 3인자).

- [ ] **Step 7: 요청·서비스·컨트롤러를 고친다**

`MemberConsentRequest.java` — 28~32행(마지막 컴포넌트)을 바꾼다.

```java
  @Schema(description = "동의한 약관 버전. 약관 개정 시 재동의 대상을 가리는 데 쓴다.",
    example = "2026-09-17")
  String consentVersion,

  @Schema(description = """
    사용자가 **본** 약관의 언어(ko, en, ja, zh, es). 증빙은 본 문서의 언어여야 하므로 앱이 화면에 띄운 약관의
    언어를 보낸다. 없으면 Accept-Language 를 따르고, 그것도 없으면 ko 다(이미 배포된 앱).
    그 언어의 약관이 게시되지 않았으면 400(`CONSENT_LOCALE_NOT_PUBLISHED`)이다.
    """, example = "ko", nullable = true)
  String consentLocale
) {

}
```

`MemberService.java` — import 에 `com.chuseok22.elumserver.common.locale.AppLocale`, `com.chuseok22.elumserver.consent.application.service.ConsentDocumentService`, `java.util.Locale` 을 더하고, 필드(34~47행 사이, `entitlementService` 아래)에 한 줄을 더한다.

```java
  private final ConsentDocumentService consentDocumentService;
```
154~168행 `agreeConsents` 를 바꾼다(javadoc 은 그대로 두고 아래 문단을 덧붙인다).

```java
   *
   * <p><b>동의한 언어도 남긴다.</b> 어떤 사용자가 어떤 언어의 어떤 버전에 동의했는지 증명하려는 것이다.
   * 읽을 수 있는 약관이 게시되지 않은 언어로는 동의를 받지 않는다 — 동의는 읽을 수 있는 언어로 받아야 성립한다.
   */
  @Transactional
  public MemberConsentResponse agreeConsents(
    String memberId, MemberConsentRequest request, AppLocale requestLocale
  ) {
    Member member = requireMember(memberId);

    AppLocale consentLocale = resolveConsentLocale(request.consentLocale(), requestLocale);
    // 아무것도 바꾸기 전에 막는다. 게시되지 않은 언어면 회원 기록은 그대로다.
    if (!consentDocumentService.isPublished(consentLocale)) {
      throw new CustomException(ErrorCode.CONSENT_LOCALE_NOT_PUBLISHED);
    }

    member.setTermsAgreed(request.termsAgreed());
    member.setPrivacyAgreed(request.privacyAgreed());
    member.setOverseasTransferAgreed(request.overseasTransferAgreed());
    member.setGuardianConfirmed(request.guardianConfirmed());
    // 선택 항목은 동의하지 않아도 그대로 저장한다 — 거부 의사도 기록이다.
    member.setMarketingAgreed(request.marketingAgreed());
    member.setConsentedAt(LocalDateTime.now());
    member.setConsentVersion(request.consentVersion());
    member.setConsentLocale(consentLocale.code());

    return MemberConsentResponse.from(member);
  }

  /** 본문의 언어가 있으면 그것(사용자가 본 약관), 없으면 헤더에서 정한 언어. 모르는 코드는 게시되지 않은 언어와 같다. */
  private AppLocale resolveConsentLocale(String bodyLocale, AppLocale requestLocale) {
    if (bodyLocale == null || bodyLocale.isBlank()) {
      return requestLocale;
    }
    try {
      return AppLocale.fromCode(bodyLocale.strip().toLowerCase(Locale.ROOT));
    } catch (IllegalArgumentException e) {
      throw new CustomException(ErrorCode.CONSENT_LOCALE_NOT_PUBLISHED);
    }
  }
```
(바꾸기 전 javadoc 마지막 줄 `*/` 가 위 첫 줄 `*` 와 이어지도록, 기존 `*/` 한 줄을 지우고 위 블록으로 이어 붙인다.)

`MemberController.java` 48~54행:

```java
  @LogMonitoring(logParameters = true, logResult = true, logExecutionTime = true)
  @PostMapping("/consents")
  public ResponseEntity<MemberConsentResponse> agreeConsents(
    Authentication authentication,
    @RequestBody @Valid MemberConsentRequest request,
    @RequestHeader(value = "Accept-Language", required = false) String acceptLanguage
  ) {
    return ResponseEntity.ok(memberService.agreeConsents(
      authentication.getName(), request, AppLocale.fromAcceptLanguage(acceptLanguage)));
  }
```
import 에 `com.chuseok22.elumserver.common.locale.AppLocale` 를 더한다(`RequestHeader` 는 이미 import 되어 있다).

`MemberControllerDocs.java` 296~317행 — 설명에 한 문단을 더하고 시그니처를 바꾼다.

```java
      **동의한 언어도 기록합니다.** `consentLocale`(사용자가 본 약관의 언어)이 있으면 그것을, 없으면
      `Accept-Language` 를, 그것도 없으면 `ko` 를 기록합니다. 그 언어의 약관이 게시되지 않았으면
      400(`CONSENT_LOCALE_NOT_PUBLISHED`)입니다.
```
```java
  ResponseEntity<MemberConsentResponse> agreeConsents(
    Authentication authentication, MemberConsentRequest request,
    @io.swagger.v3.oas.annotations.Parameter(description = "화면 언어. 비우면 ko", example = "ko")
    String acceptLanguage);
```

- [ ] **Step 8: 통과를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.member.*' --tests 'com.chuseok22.elumserver.consent.*'`
Expected: PASS — 신규 5건(`MemberServiceTest`) + 4건(`ConsentControllerTest`) + 기존 전부.

- [ ] **Step 9: 전체 서버 시험**

Run: `cd server && ./gradlew test`
Expected: PASS.

- [ ] **Step 10: 커밋 (`/pro-commit`)**

```bash
git add server/src/main/java/com/chuseok22/elumserver/consent/application/controller/ConsentController.java \
  server/src/main/java/com/chuseok22/elumserver/consent/application/controller/ConsentControllerDocs.java \
  server/src/main/java/com/chuseok22/elumserver/member/application/dto/request/MemberConsentRequest.java \
  server/src/main/java/com/chuseok22/elumserver/member/application/service/MemberService.java \
  server/src/main/java/com/chuseok22/elumserver/member/application/controller/MemberController.java \
  server/src/main/java/com/chuseok22/elumserver/member/application/controller/MemberControllerDocs.java \
  server/src/test/java/com/chuseok22/elumserver/member/application/service/MemberServiceTest.java \
  server/src/test/java/com/chuseok22/elumserver/consent/application/controller/ConsentControllerTest.java
```

---

## Task 5: 공지 번역 스키마(V35)와 엔티티

**Files:**
- Create: `server/src/main/resources/db/migration/V35__create_app_notice_translation.sql`
- Create: `server/src/main/java/com/chuseok22/elumserver/notice/infrastructure/entity/AppNoticeTranslation.java`
- Modify: `server/src/main/java/com/chuseok22/elumserver/notice/infrastructure/entity/AppNotice.java:1-94` (전체 교체)
- Test: `server/src/test/java/com/chuseok22/elumserver/notice/NoticeTranslationMigrationTest.java` (새)
- Test: `server/src/test/java/com/chuseok22/elumserver/notice/infrastructure/entity/AppNoticeTranslationTest.java` (새)
- Test: `server/src/test/java/com/chuseok22/elumserver/notice/infrastructure/entity/AppNoticeTargetCountriesTest.java` (새 — 대상 국가)

**Interfaces:**
- Consumes: `AppLocale#code()`
- Produces:
  - `AppNoticeTranslation` — `getNotice(): AppNotice`, `getLocale(): String`, `getTitle(): String`, `getBody(): String`, `getButtonLabel(): String` (+ setter)
  - `AppNotice#getTranslations(): List<AppNoticeTranslation>`
  - `AppNotice#translation(AppLocale): Optional<AppNoticeTranslation>`
  - `AppNotice#hasTranslation(String code): boolean`
  - `AppNotice#putTranslation(AppLocale, String title, String body, String buttonLabel): AppNoticeTranslation` — 있으면 그 행을 고치고 없으면 만든다
  - `AppNotice#retainTranslations(Set<AppLocale>): void` — 목록 밖 언어 행을 지운다(고아 제거)
  - `AppNotice#getTitle()/getBody()/getButtonLabel()` + `setTitle/setBody/setButtonLabel` — **한국어 행**을 읽고 쓰는 편의 메서드(필드는 없다)
  - `AppNotice#hasButton(): boolean`(한국어 기준), `AppNotice#hasButton(AppNoticeTranslation): boolean`
  - 대상 국가(스펙 4.3.1): `AppNotice.TARGET_COUNTRIES_MAX_LENGTH = 255`, `AppNotice#getTargetCountries(): String` / `setTargetCountries(String)` (쉼표 구분 대문자 ISO 코드, `null` 또는 빈 값 = 전체 국가), `AppNotice#targetCountryList(): List<String>` (공백·빈 토큰 무시, 대문자로 맞춤, 중복 제거), `AppNotice#targetsRegion(String region): boolean` — 대상이 비면 `true`, 값이 있으면 `region` 이 목록에 있을 때만 `true`(**`region == null`(국가 미상)이면 `false`**)
  - 스키마: `app_notice.target_countries VARCHAR(255) NULL`(V35 에 같이 넣는다)

- [ ] **Step 1: 실패하는 시험을 쓴다**

`server/src/test/java/com/chuseok22/elumserver/notice/NoticeTranslationMigrationTest.java`:

```java
package com.chuseok22.elumserver.notice;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNoticeTranslation;
import jakarta.persistence.Column;
import jakarta.persistence.Table;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.stream.Collectors;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 공지 번역 표(V35)가 엔티티와 같고, 기존 공지의 한국어 글을 잃지 않고 옮기는지 글로 확인한다 (이슈 #521).
 *
 * <p>운영은 {@code ddl-auto: validate} 라 열 이름·길이가 어긋나면 서버가 뜨지 않는다. DB 를 띄우지 않는다.
 */
class NoticeTranslationMigrationTest {

  private static final Path V35 = Path.of(
    "src/main/resources/db/migration/V35__create_app_notice_translation.sql");

  @Test
  @DisplayName("V35 는 공지당 언어당 한 행이다 — (notice_id, locale) 유니크, 공지를 지우면 번역도 지워진다")
  void v35_oneRowPerNoticeAndLocale() throws IOException {
    String sql = normalizedSql();
    assertThat(sql).contains("create table if not exists app_notice_translation (");
    assertThat(sql).contains("notice_id varchar(255) not null references app_notice (id) on delete cascade");
    assertThat(sql).contains("constraint uk_app_notice_translation_notice_locale unique (notice_id, locale)");
  }

  @Test
  @DisplayName("V35 는 기존 공지의 제목·본문·버튼 문구를 ko 행으로 옮긴다 — 다시 돌려도 중복을 만들지 않는다")
  void v35_movesExistingTextToKo() throws IOException {
    String sql = normalizedSql();
    assertThat(sql).contains("insert into app_notice_translation");
    assertThat(sql).contains("select gen_random_uuid()::text, n.id, 'ko', n.title, n.body, n.button_label");
    assertThat(sql).contains(
      "not exists (select 1 from app_notice_translation t where t.notice_id = n.id and t.locale = 'ko')");
  }

  @Test
  @DisplayName("V35 는 옛 열을 지우지 않고 NOT NULL 만 푼다 — 새 서버는 더 이상 쓰지 않고 옛 서버는 그대로 읽고 쓴다")
  void v35_keepsLegacyColumns() throws IOException {
    String sql = normalizedSql();
    assertThat(sql).contains("alter table app_notice alter column title drop not null;");
    assertThat(sql).contains("alter table app_notice alter column body drop not null;");
    assertThat(sql).doesNotContain("drop column").doesNotContain("drop table").doesNotContain("set not null");
  }

  @Test
  @DisplayName("V35 는 대상 국가 열을 NULL 허용·기본값 없이 더한다 — 기존 공지는 전부 전체 국가이고 옛 서버는 그대로 돈다")
  void v35_addsNullableTargetCountries() throws IOException {
    String sql = normalizedSql();
    assertThat(sql).contains(
      "alter table app_notice add column if not exists target_countries varchar(255);");
    // NOT NULL·DEFAULT 를 걸면 옛 서버가 공지를 만들 때 깨진다 (MigrationRollbackContractTest 의 "추가만 한다").
    assertThat(sql).doesNotContain("target_countries varchar(255) not null")
      .doesNotContain("target_countries varchar(255) default");
  }

  @Test
  @DisplayName("엔티티의 대상 국가 열은 V35 와 같다 — 255자, NULL 허용")
  void entityMatchesTargetCountriesColumn() throws Exception {
    Column column = AppNotice.class.getDeclaredField("targetCountries").getAnnotation(Column.class);
    assertThat(column.length()).isEqualTo(AppNotice.TARGET_COUNTRIES_MAX_LENGTH).isEqualTo(255);
    assertThat(column.nullable()).isTrue();
  }

  @Test
  @DisplayName("엔티티는 V35 와 같다 — 열 길이는 공지와 같은 40·1000·20, 언어는 8")
  void entityMatchesMigration() throws Exception {
    Table table = AppNoticeTranslation.class.getAnnotation(Table.class);
    assertThat(table.name()).isEqualTo("app_notice_translation");
    assertThat(table.uniqueConstraints()[0].columnNames()).containsExactly("notice_id", "locale");

    assertThat(column("locale").length()).isEqualTo(8);
    assertThat(column("title").length()).isEqualTo(AppNotice.TITLE_MAX_LENGTH);
    assertThat(column("title").nullable()).isFalse();
    assertThat(column("body").length()).isEqualTo(AppNotice.BODY_MAX_LENGTH);
    assertThat(column("body").nullable()).isFalse();
    assertThat(column("buttonLabel").length()).isEqualTo(AppNotice.BUTTON_LABEL_MAX_LENGTH);
    assertThat(column("buttonLabel").nullable()).isTrue();
  }

  private static Column column(String field) throws NoSuchFieldException {
    return AppNoticeTranslation.class.getDeclaredField(field).getAnnotation(Column.class);
  }

  /** 주석을 빼고 공백을 하나로, 소문자로 — 주석에 적힌 설명이 검사를 속이지 않게 한다. */
  private String normalizedSql() throws IOException {
    return Files.readAllLines(V35).stream()
      .map(line -> line.contains("--") ? line.substring(0, line.indexOf("--")) : line)
      .collect(Collectors.joining(" "))
      .replaceAll("\\s+", " ")
      .toLowerCase();
  }
}
```

`server/src/test/java/com/chuseok22/elumserver/notice/infrastructure/entity/AppNoticeTranslationTest.java`:

```java
package com.chuseok22.elumserver.notice.infrastructure.entity;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.Set;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** 공지 한 장이 언어별 글을 들고 있는 방식 (이슈 #521). 한국어 편의 메서드가 기존 호출부를 지킨다. */
class AppNoticeTranslationTest {

  @Test
  @DisplayName("setTitle·setBody·setButtonLabel 은 한국어 행을 만들고 고친다")
  void koAccessors_writeKoRow() {
    AppNotice notice = new AppNotice();
    notice.setTitle("제목");
    notice.setBody("본문");
    notice.setButtonLabel("자세히");

    assertThat(notice.getTranslations()).hasSize(1);
    assertThat(notice.translation(AppLocale.KO)).hasValueSatisfying(text -> {
      assertThat(text.getLocale()).isEqualTo("ko");
      assertThat(text.getNotice()).isSameAs(notice);
    });
    assertThat(notice.getTitle()).isEqualTo("제목");
    assertThat(notice.getBody()).isEqualTo("본문");
    assertThat(notice.getButtonLabel()).isEqualTo("자세히");
  }

  @Test
  @DisplayName("한국어 행이 없으면 getTitle 은 null 이다 — 화면이 죽지 않는다")
  void koAccessors_nullWhenMissing() {
    AppNotice notice = new AppNotice();
    assertThat(notice.getTitle()).isNull();
    assertThat(notice.getBody()).isNull();
    assertThat(notice.getButtonLabel()).isNull();
  }

  @Test
  @DisplayName("putTranslation 은 같은 언어를 두 번 넣어도 한 행이다 — (notice_id, locale) 유니크를 지킨다")
  void putTranslation_upserts() {
    AppNotice notice = new AppNotice();
    notice.putTranslation(AppLocale.EN, "Hello", "Body", null);
    notice.putTranslation(AppLocale.EN, "Hi", "Body 2", "More");

    assertThat(notice.getTranslations()).hasSize(1);
    assertThat(notice.translation(AppLocale.EN)).hasValueSatisfying(text -> {
      assertThat(text.getTitle()).isEqualTo("Hi");
      assertThat(text.getBody()).isEqualTo("Body 2");
      assertThat(text.getButtonLabel()).isEqualTo("More");
    });
    assertThat(notice.hasTranslation("en")).isTrue();
    assertThat(notice.hasTranslation("ja")).isFalse();
  }

  @Test
  @DisplayName("retainTranslations 는 목록 밖 언어를 지운다 — 관리자가 한 언어를 비우면 그 언어가 사라진다")
  void retainTranslations_removesOthers() {
    AppNotice notice = new AppNotice();
    notice.putTranslation(AppLocale.KO, "제목", "본문", null);
    notice.putTranslation(AppLocale.EN, "Hello", "Body", null);
    notice.putTranslation(AppLocale.JA, "こんにちは", "本文", null);

    notice.retainTranslations(Set.of(AppLocale.KO, AppLocale.EN));

    assertThat(notice.translation(AppLocale.JA)).isEmpty();
    assertThat(notice.getTranslations()).hasSize(2);
  }

  @Test
  @DisplayName("버튼은 그 언어의 문구와 공유 링크가 둘 다 있을 때만 있다")
  void hasButton_needsLabelAndSharedUrl() {
    AppNotice notice = new AppNotice();
    notice.setButtonUrl("https://example.com");
    AppNoticeTranslation ko = notice.putTranslation(AppLocale.KO, "제목", "본문", "자세히");
    AppNoticeTranslation en = notice.putTranslation(AppLocale.EN, "Hello", "Body", null);

    assertThat(notice.hasButton()).isTrue();
    assertThat(notice.hasButton(ko)).isTrue();
    // 링크는 공유하지만 영어 문구가 없으면 영어에는 버튼이 없다.
    assertThat(notice.hasButton(en)).isFalse();

    notice.setButtonUrl(null);
    assertThat(notice.hasButton(ko)).isFalse();
  }
}
```

`server/src/test/java/com/chuseok22/elumserver/notice/infrastructure/entity/AppNoticeTargetCountriesTest.java`:

```java
package com.chuseok22.elumserver.notice.infrastructure.entity;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 공지의 대상 국가 판단 (이슈 #521, 스펙 4.3.1).
 *
 * <p>대상이 비면 전체 국가다. 값이 있으면 그 국가만이고, <b>국가를 모르는 요청은 값이 있는 공지를 못 본다</b>.
 */
class AppNoticeTargetCountriesTest {

  private AppNotice notice(String targetCountries) {
    AppNotice notice = new AppNotice();
    notice.setTargetCountries(targetCountries);
    return notice;
  }

  @Test
  @DisplayName("대상이 null·빈 값·쉼표뿐이면 전체 국가다 — 어떤 국가에도, 국가 미상에도 보인다")
  void emptyTargets_meansEveryone() {
    for (String targets : new String[] {null, "", "  ", " , ,"}) {
      AppNotice notice = notice(targets);
      assertThat(notice.targetCountryList()).as("[%s]", targets).isEmpty();
      assertThat(notice.targetsRegion("KR")).as("[%s] KR", targets).isTrue();
      assertThat(notice.targetsRegion("US")).as("[%s] US", targets).isTrue();
      assertThat(notice.targetsRegion(null)).as("[%s] 국가 미상", targets).isTrue();
    }
  }

  @Test
  @DisplayName("대상이 있으면 목록에 든 국가에만 보인다")
  void listedTargets_onlyThoseCountries() {
    AppNotice notice = notice("KR,JP");

    assertThat(notice.targetsRegion("KR")).isTrue();
    assertThat(notice.targetsRegion("JP")).isTrue();
    assertThat(notice.targetsRegion("US")).isFalse();
  }

  @Test
  @DisplayName("국가 미상(null)에게는 대상이 지정된 공지가 보이지 않는다 — 대상이 하나뿐이어도")
  void unknownRegion_onlyUntargeted() {
    assertThat(notice("KR").targetsRegion(null)).isFalse();
    assertThat(notice("KR,JP").targetsRegion(null)).isFalse();
    assertThat(notice(null).targetsRegion(null)).isTrue();
  }

  @Test
  @DisplayName("DB 를 손으로 고친 값도 터지지 않는다 — 공백·빈 토큰·소문자·중복을 다듬어 읽는다")
  void targetCountryList_toleratesHandEditedValue() {
    AppNotice notice = notice(" kr, JP ,,kr");

    assertThat(notice.targetCountryList()).containsExactly("KR", "JP");
    assertThat(notice.targetsRegion("KR")).isTrue();
  }
}
```

- [ ] **Step 2: 실행해 실패를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.notice.NoticeTranslationMigrationTest' --tests 'com.chuseok22.elumserver.notice.infrastructure.entity.AppNoticeTranslationTest' --tests 'com.chuseok22.elumserver.notice.infrastructure.entity.AppNoticeTargetCountriesTest'`
Expected: FAIL — 컴파일 오류(`AppNoticeTranslation`·`setTargetCountries` 없음).

- [ ] **Step 3: 마이그레이션을 쓴다**

`server/src/main/resources/db/migration/V35__create_app_notice_translation.sql`:

```sql
-- 공지에 언어별 번역 행을 단다 (이슈 #521, 다국어 하위 계획 4).
--
-- 지금까지 공지 한 장은 제목·본문·버튼 문구를 한국어로 직접 들고 있었다. 이제 언어마다 한 행씩
-- app_notice_translation 에 둔다. 이미지·링크·기간·플랫폼·우선순위·판은 공지 한 장이 공유한다.
--
-- 옛 열(app_notice.title / body / button_label)은 지우지 않는다. 새 서버는 더 이상 쓰지 않지만
-- 옛 서버 이미지로 되돌려도 그대로 돌아가야 한다. 새 공지에는 title·body 를 채우지 않으므로
-- NOT NULL 만 푼다. (되돌린 뒤 옛 서버가 보는 글은 이 마이그레이션 시점의 한국어 글이다.)
--
-- 무중단 배포(Blue/Green)에서 두 서버가 잠깐 함께 돈다. 그 사이 옛 서버가 만든 공지는 번역 행이
-- 없어 새 서버가 건너뛴다(앱에 안 나간다). 몇 분 안의 일이고 관리자가 다시 저장하면 채워진다.
--
-- prod 는 ddl-auto: validate 라 Hibernate 가 표를 만들지 않는다. 로컬(ddl-auto: update)에서 이미
-- 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다. 다시 돌려도 안전하다(멱등).

CREATE TABLE IF NOT EXISTS app_notice_translation (
  id           VARCHAR(255)  NOT NULL,
  notice_id    VARCHAR(255)  NOT NULL REFERENCES app_notice (id) ON DELETE CASCADE,
  -- ko en ja zh es. 서버 AppLocale#code() 와 같다.
  locale       VARCHAR(8)    NOT NULL,
  -- **강조** 표기를 그대로 담는다. 길이는 표기까지 센다. app_notice 와 같은 한도.
  title        VARCHAR(40)   NOT NULL,
  body         VARCHAR(1000) NOT NULL,
  button_label VARCHAR(20),
  created_at   TIMESTAMP(6),
  updated_at   TIMESTAMP(6),
  CONSTRAINT pk_app_notice_translation PRIMARY KEY (id),
  CONSTRAINT uk_app_notice_translation_notice_locale UNIQUE (notice_id, locale)
);

-- 기존 공지의 한국어 글을 ko 행으로 옮긴다.
INSERT INTO app_notice_translation (id, notice_id, locale, title, body, button_label, created_at, updated_at)
SELECT gen_random_uuid()::text, n.id, 'ko', n.title, n.body, n.button_label, now(), now()
FROM app_notice n
WHERE n.title IS NOT NULL
  AND n.body IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM app_notice_translation t WHERE t.notice_id = n.id AND t.locale = 'ko');

ALTER TABLE app_notice ALTER COLUMN title DROP NOT NULL;
ALTER TABLE app_notice ALTER COLUMN body DROP NOT NULL;

-- 공지를 보여줄 대상 국가 (스펙 4.3.1). NULL 또는 빈 값 = 전체 국가, 값이 있으면 쉼표로 구분한 ISO 3166-1 alpha-2
-- 대문자 코드 목록이다(예: KR,JP). 형식은 서버(NoticeService)가 저장 전에 맞춘다.
--
-- 기본값 없이 NULL 로 더하므로 기존 공지는 모두 전체 국가라 지금과 똑같이 보인다. NOT NULL·DEFAULT 도 걸지 않는다 —
-- 옛 서버가 이 열을 모른 채 공지를 만들어도 돌아야 한다. (옛 서버로 되돌리면 대상 국가를 정한 공지도 모두에게
-- 보인다. 대상 국가를 쓰기 전에는 일어나지 않는다.) 다시 돌려도 안전하다(멱등).
ALTER TABLE app_notice ADD COLUMN IF NOT EXISTS target_countries VARCHAR(255);
```

- [ ] **Step 4: 엔티티를 쓴다**

`server/src/main/java/com/chuseok22/elumserver/notice/infrastructure/entity/AppNoticeTranslation.java`:

```java
package com.chuseok22.elumserver.notice.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Getter;
import lombok.Setter;

/**
 * 공지 한 장의 한 언어 글 (이슈 #521). 제목·본문·버튼 문구만 언어마다 다르다.
 *
 * <p>링크·이미지·기간은 {@link AppNotice} 가 공유한다. 버튼 문구가 비어 있으면 그 언어에는 버튼이 없다.
 */
@Entity
@Getter
@Setter
@Table(
  name = "app_notice_translation",
  uniqueConstraints = @UniqueConstraint(
    name = "uk_app_notice_translation_notice_locale", columnNames = {"notice_id", "locale"})
)
public class AppNoticeTranslation extends BaseEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "notice_id", nullable = false)
  private AppNotice notice;

  /** 언어 코드({@code ko} {@code en} …). {@code AppLocale#code()} 와 같다. */
  @Column(nullable = false, length = 8)
  private String locale;

  /** {@code **강조**} 표기를 그대로 담는다. 길이는 표기까지 센다(컬럼 한도라서). */
  @Column(nullable = false, length = AppNotice.TITLE_MAX_LENGTH)
  private String title;

  /** 줄바꿈은 LF 로 담는다. */
  @Column(nullable = false, length = AppNotice.BODY_MAX_LENGTH)
  private String body;

  @Column(length = AppNotice.BUTTON_LABEL_MAX_LENGTH)
  private String buttonLabel;
}
```

`AppNotice.java` 전체를 아래로 바꾼다.

```java
package com.chuseok22.elumserver.notice.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.notice.core.NoticePlatform;
import com.chuseok22.elumserver.notice.core.NoticeStatus;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.Set;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.Fetch;
import org.hibernate.annotations.FetchMode;

/**
 * 보호자 홈 팝업에 나가는 공지 한 장 (이슈 #370).
 *
 * <p>보지 않기 일수는 여기 두지 않는다. 팝업 하나에 체크박스가 하나라 공지마다 일수가
 * 다르면 설명할 수 없다 — 관리자 설정 {@code NOTICE_HIDE_DAYS} 하나로 둔다.
 *
 * <p>제목·본문·버튼 문구는 언어마다 {@link AppNoticeTranslation} 에 있다 (이슈 #521). 한국어 행은 필수이고
 * 나머지는 선택이다(서비스가 지킨다). 이미지·링크·기간·플랫폼은 공지 한 장이 모든 언어에 공유한다.
 */
@Entity
@Getter
@Setter
public class AppNotice extends BaseEntity {

  public static final int TITLE_MAX_LENGTH = 40;
  public static final int BODY_MAX_LENGTH = 1000;
  public static final int BUTTON_LABEL_MAX_LENGTH = 20;
  public static final int BUTTON_URL_MAX_LENGTH = 500;
  public static final int TARGET_COUNTRIES_MAX_LENGTH = 255;

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  /**
   * 언어별 글. open-in-view 가 꺼져 있어 관리자 템플릿이 읽을 수 있게 즉시 읽는다 — 공지는 관리자가 손으로 올리는
   * 몇십 건이고 한 장에 언어는 최대 5개라 가볍다.
   */
  @OneToMany(mappedBy = "notice", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.EAGER)
  @Fetch(FetchMode.SUBSELECT)
  private List<AppNoticeTranslation> translations = new ArrayList<>();

  /** 저장소 열쇠. 경로가 아니다. 없으면 글만 있는 공지다. */
  private String imageKey;

  /** 모든 언어가 공유한다. 문구는 언어마다, 링크는 하나다. 링크는 https 만. */
  @Column(length = BUTTON_URL_MAX_LENGTH)
  private String buttonUrl;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private NoticePlatform platform = NoticePlatform.ALL;

  /**
   * 대상 국가. 쉼표로 구분한 ISO 3166-1 alpha-2 대문자 코드({@code KR,JP}). {@code null} 이나 빈 값이면 전체
   * 국가다. 언어와 달리 공지 한 장이 하나를 공유한다. 형식(두 글자 대문자·중복 없음)은 저장 전에
   * {@code NoticeService} 가 맞춘다.
   */
  @Column(length = TARGET_COUNTRIES_MAX_LENGTH)
  private String targetCountries;

  /** 클수록 먼저. 같으면 시작이 늦은 것이 먼저다. */
  @Column(nullable = false)
  private int priority;

  /**
   * "다시 보이게"로 저장할 때마다 오른다. 앱은 숨긴 기록에 이 값을 함께 적어 두고,
   * 값이 달라지면 숨김을 무시한다.
   */
  @Column(nullable = false)
  private int revision = 1;

  /** 한국 시각. 서버 시계로 판단한다. */
  @Column(nullable = false)
  private LocalDateTime startsAt;

  /** 한국 시각. 비면 끌 때까지. 종료 시각 그 순간부터 빠진다. */
  private LocalDateTime endsAt;

  /** 기간과 별개로 관리자가 켜고 끈다. */
  @Column(nullable = false)
  private boolean enabled;

  @Column(nullable = false)
  private String createdBy;

  @Column(nullable = false)
  private String updatedBy;

  public NoticeStatus statusAt(LocalDateTime now) {
    return NoticeStatus.of(enabled, startsAt, endsAt, now);
  }

  // ── 대상 국가 ───────────────────────────────────────

  /**
   * 대상 국가 목록. 비면 전체 국가다. DB 를 손으로 고친 값(공백·빈 토큰·소문자·중복)도 터지지 않게 다듬어 읽는다.
   * 템플릿(목록 화면)도 이것을 쓴다.
   */
  public List<String> targetCountryList() {
    if (targetCountries == null) {
      return List.of();
    }
    return Arrays.stream(targetCountries.split(","))
      .map(String::strip)
      .filter(code -> !code.isEmpty())
      .map(code -> code.toUpperCase(Locale.ROOT))
      .distinct()
      .toList();
  }

  /**
   * 이 공지가 [region] 국가에 나가는가. 대상이 비면 어느 국가에든 나간다. 값이 있으면 목록에 든 국가에만 나가고,
   * <b>국가를 모르는 요청([region] 이 {@code null})에는 나가지 않는다</b> — 대상을 정한 공지가 엉뚱한 국가에 새지
   * 않게 한다(스펙 4.3.1).
   */
  public boolean targetsRegion(String region) {
    List<String> targets = targetCountryList();
    if (targets.isEmpty()) {
      return true;
    }
    return region != null && targets.contains(region);
  }

  // ── 언어별 글 ───────────────────────────────────────

  public Optional<AppNoticeTranslation> translation(AppLocale locale) {
    return translations.stream()
      .filter(text -> text.getLocale().equals(locale.code()))
      .findFirst();
  }

  /** 템플릿이 언어별 채움 상태(✓/−)를 그릴 때 쓴다. */
  public boolean hasTranslation(String code) {
    return translations.stream().anyMatch(text -> text.getLocale().equals(code));
  }

  /**
   * 그 언어 글을 넣는다. 이미 있으면 <b>그 행을 고친다</b> — 새 행을 만들면 (공지, 언어) 유니크에 걸리고,
   * 지우고 다시 만들면 flush 순서에 따라 같은 키가 잠깐 겹친다.
   */
  public AppNoticeTranslation putTranslation(
    AppLocale locale, String title, String body, String buttonLabel
  ) {
    AppNoticeTranslation text = translation(locale).orElseGet(() -> {
      AppNoticeTranslation created = new AppNoticeTranslation();
      created.setNotice(this);
      created.setLocale(locale.code());
      translations.add(created);
      return created;
    });
    text.setTitle(title);
    text.setBody(body);
    text.setButtonLabel(buttonLabel);
    return text;
  }

  /** 목록에 없는 언어 행을 지운다. 관리자가 한 언어를 비우고 저장하면 그 언어가 사라진다(고아 제거). */
  public void retainTranslations(Set<AppLocale> keep) {
    translations.removeIf(text -> keep.stream().noneMatch(locale -> locale.code().equals(text.getLocale())));
  }

  // ── 한국어 편의 메서드 ──────────────────────────────
  // 관리자 목록·로그·기존 시험이 한국어 제목을 그대로 쓴다. 필드가 아니라서 Hibernate 는 무시한다.

  public String getTitle() {
    return translation(AppLocale.KO).map(AppNoticeTranslation::getTitle).orElse(null);
  }

  public String getBody() {
    return translation(AppLocale.KO).map(AppNoticeTranslation::getBody).orElse(null);
  }

  public String getButtonLabel() {
    return translation(AppLocale.KO).map(AppNoticeTranslation::getButtonLabel).orElse(null);
  }

  public void setTitle(String title) {
    koRow().setTitle(title);
  }

  public void setBody(String body) {
    koRow().setBody(body);
  }

  public void setButtonLabel(String buttonLabel) {
    koRow().setButtonLabel(buttonLabel);
  }

  private AppNoticeTranslation koRow() {
    return translation(AppLocale.KO).orElseGet(() -> {
      AppNoticeTranslation created = new AppNoticeTranslation();
      created.setNotice(this);
      created.setLocale(AppLocale.KO.code());
      translations.add(created);
      return created;
    });
  }

  /** 한국어 기준. 문구와 링크는 둘 다 있거나 둘 다 없다. */
  public boolean hasButton() {
    return getButtonLabel() != null && buttonUrl != null;
  }

  /** 그 언어 글 기준 — 링크는 공유하지만 문구가 비어 있으면 그 언어에는 버튼이 없다. */
  public boolean hasButton(AppNoticeTranslation text) {
    return text.getButtonLabel() != null && buttonUrl != null;
  }
}
```

- [ ] **Step 5: 통과를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.notice.*' --tests 'com.chuseok22.elumserver.common.MigrationRollbackContractTest'`
Expected: 신규 시험 PASS(`AppNoticeTargetCountriesTest` 4건, `NoticeTranslationMigrationTest` 6건). 기존 공지 시험은 `AppNoticeResponse.from` 이 제거되기 전이라 **컴파일이 깨지지 않는다**(Task 6 에서 바꾼다). 단 `AppNoticeResponse` 가 `notice.getButtonLabel()`·`hasButton()` 을 그대로 쓰므로 한국어 행만 있는 기존 시험은 전부 통과해야 한다.

- [ ] **Step 6: 커밋 (`/pro-commit`)**

```bash
git add server/src/main/resources/db/migration/V35__create_app_notice_translation.sql \
  server/src/main/java/com/chuseok22/elumserver/notice/infrastructure/entity/AppNotice.java \
  server/src/main/java/com/chuseok22/elumserver/notice/infrastructure/entity/AppNoticeTranslation.java \
  server/src/test/java/com/chuseok22/elumserver/notice/NoticeTranslationMigrationTest.java \
  server/src/test/java/com/chuseok22/elumserver/notice/infrastructure/entity/AppNoticeTranslationTest.java \
  server/src/test/java/com/chuseok22/elumserver/notice/infrastructure/entity/AppNoticeTargetCountriesTest.java
```

---

## Task 6: `NoticeService` 언어 선택과 검증, 공지 API

**Files:**
- Create: `server/src/main/java/com/chuseok22/elumserver/notice/application/dto/request/NoticeTextInput.java`
- Create: `server/src/main/java/com/chuseok22/elumserver/notice/core/NoticeLocaleException.java`
- Modify: `server/src/main/java/com/chuseok22/elumserver/notice/application/dto/request/NoticeInput.java:1-27`
- Modify: `server/src/main/java/com/chuseok22/elumserver/notice/application/dto/response/AppNoticeResponse.java:51-62`
- Modify: `server/src/main/java/com/chuseok22/elumserver/notice/application/service/NoticeService.java:3-33, 99-112, 249-317`
- Modify: `server/src/main/java/com/chuseok22/elumserver/notice/application/controller/NoticeController.java:27-39`
- Modify: `server/src/main/java/com/chuseok22/elumserver/notice/application/controller/NoticeControllerDocs.java:62-67`
- Modify: `server/src/main/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorCode.java:182` 아래에 다섯 줄 추가
- Modify: `server/src/test/java/com/chuseok22/elumserver/notice/application/controller/NoticeControllerTest.java:35-47`
- Test: `server/src/test/java/com/chuseok22/elumserver/notice/application/service/NoticeLocaleTest.java` (새)
- Test: `server/src/test/java/com/chuseok22/elumserver/notice/application/service/NoticeCountryTest.java` (새 — 대상 국가 노출 규칙·저장 검증)

**Interfaces:**
- Consumes: Task 5 의 `AppNotice#translation/putTranslation/retainTranslations`, `AppNotice#targetsRegion/targetCountryList/setTargetCountries`, `AppLocale#fallbackChain()`, 계획 2 의 `CurrentRegion.get()`(대문자 ISO 코드 또는 `null` = 국가 미상. **소비만 한다**)
- Produces:
  - `NoticeTextInput(String title, String body, String buttonLabel)` + `isBlank(): boolean`
  - `NoticeInput(..., boolean enabled, Map<String, NoticeTextInput> translations, String targetCountries)` — 마지막 두 컴포넌트. 옛 9인자·10인자 생성자는 `translations = Map.of()`·`targetCountries = ""` 로 남는다. 대상 국가는 쉼표로 구분한 문자열 그대로 받는다(검증은 서비스에서)
  - `NoticeLocaleException(ErrorCode, AppLocale)` extends `CustomException`, `getLocale(): AppLocale`
  - `NoticeService#publishedFor(String platform, AppLocale locale, String region): AppNoticesResponse` — 순서: 게시 기간·켜짐 → 플랫폼 → **대상 국가(`region`; `null` = 국가 미상)** → 언어 글 고르기(요청 → `en` → `ko`) → 최대 5개. `publishedFor(platform, locale)` 은 `KR`(헤더 없는 옛 앱), `publishedFor(platform)` 은 `KO`·`KR` 로 위임
  - `NoticeService.normalizeTargetCountries(String): String` (package-private static) — 쉼표 구분 → 공백 제거·빈 토큰 무시·중복 제거(처음 나온 순서 유지) → 두 글자 대문자만 허용 → 255자 이내. 비면 `null`(전체 국가). 어기면 `CustomException`
  - `AppNoticeResponse.from(AppNotice, AppNoticeTranslation)` (옛 `from(AppNotice)` 는 지운다)
  - `NoticeController#notices(String platform, String acceptLanguage)` — `Vary: Accept-Language, X-Elum-Region`. 국가는 `CurrentRegion.get()` 으로 읽어 서비스에 넘긴다
  - `ErrorCode.NOTICE_TRANSLATION_INCOMPLETE(400)`, `ErrorCode.NOTICE_LOCALE_INVALID(400)`, `ErrorCode.NOTICE_TARGET_COUNTRIES_INVALID(400)`, `ErrorCode.NOTICE_TARGET_COUNTRIES_TOO_LONG(400)`

- [ ] **Step 1: 실패하는 시험을 쓴다**

`server/src/test/java/com/chuseok22/elumserver/notice/application/service/NoticeLocaleTest.java`:

```java
package com.chuseok22.elumserver.notice.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.NoticeProperties;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.notice.application.dto.request.NoticeInput;
import com.chuseok22.elumserver.notice.application.dto.request.NoticeTextInput;
import com.chuseok22.elumserver.notice.application.dto.response.AppNoticeResponse;
import com.chuseok22.elumserver.notice.application.dto.response.AppNoticesResponse;
import com.chuseok22.elumserver.notice.core.NoticeLocaleException;
import com.chuseok22.elumserver.notice.core.NoticePlatform;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import com.chuseok22.elumserver.notice.infrastructure.repository.AppNoticeRepository;
import com.chuseok22.elumserver.notice.infrastructure.storage.LocalFileNoticeImageStorage;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

/**
 * 공지의 언어 선택과 언어별 저장 검증 (이슈 #521).
 *
 * <p>고르는 순서는 요청 → en → ko 다. 한국어는 필수라 어떤 공지든 마지막에는 한국어가 나온다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class NoticeLocaleTest {

  private static final Instant NOW = Instant.parse("2026-09-23T03:00:00Z"); // 한국 12:00
  private static final LocalDateTime NOW_KST = LocalDateTime.of(2026, 9, 23, 12, 0);

  @TempDir
  Path tempDir;

  @Mock
  private AppNoticeRepository repository;
  @Mock
  private SystemConfigService systemConfigService;

  private final List<AppNotice> stored = new ArrayList<>();
  private NoticeService service;

  @BeforeEach
  void setUp() {
    service = new NoticeService(repository, systemConfigService,
      new LocalFileNoticeImageStorage(new NoticeProperties(tempDir.toString())),
      Clock.fixed(NOW, ZoneOffset.UTC));
    when(repository.findAll()).thenReturn(stored);
    when(repository.save(any(AppNotice.class))).thenAnswer(invocation -> {
      AppNotice notice = invocation.getArgument(0);
      if (notice.getId() == null) {
        notice.setId("notice-" + (stored.size() + 1));
        stored.add(notice);
      }
      return notice;
    });
    when(repository.findById(any())).thenAnswer(invocation -> stored.stream()
      .filter(notice -> notice.getId().equals(invocation.getArgument(0))).findFirst());
    when(systemConfigService.getInt(ConfigKey.NOTICE_HIDE_DAYS)).thenReturn(7);
  }

  /** 지금 게시 중인 공지. 한국어 글과 공유 링크가 있고 한국어 버튼 문구가 있다. */
  private AppNotice live(String id) {
    AppNotice notice = new AppNotice();
    notice.setId(id);
    notice.setTitle("제목 " + id);
    notice.setBody("본문 " + id);
    notice.setButtonLabel("자세히");
    notice.setButtonUrl("https://example.com");
    notice.setPlatform(NoticePlatform.ALL);
    notice.setStartsAt(NOW_KST.minusDays(1));
    notice.setEnabled(true);
    notice.setCreatedBy("admin");
    notice.setUpdatedBy("admin");
    stored.add(notice);
    return notice;
  }

  private AppNoticeResponse only(AppNoticesResponse response) {
    assertThat(response.notices()).hasSize(1);
    return response.notices().get(0);
  }

  // ── 앱에 주는 글 ────────────────────────────────────

  @Test
  @DisplayName("그 언어 글이 있으면 그것, 없으면 en, 그것도 없으면 ko 다")
  void pick_requestThenEnThenKo() {
    AppNotice notice = live("n1");
    notice.putTranslation(AppLocale.EN, "Hello", "Body", null);
    notice.putTranslation(AppLocale.ES, "Hola", "Cuerpo", null);

    assertThat(only(service.publishedFor("IOS", AppLocale.ES)).title()).isEqualTo("Hola");
    // 일본어 글이 없다 — 영어로 대체한다.
    assertThat(only(service.publishedFor("IOS", AppLocale.JA)).title()).isEqualTo("Hello");
    assertThat(only(service.publishedFor("IOS", AppLocale.KO)).title()).isEqualTo("제목 n1");
  }

  @Test
  @DisplayName("영어도 없으면 한국어로 내려간다 — 공지가 통째로 사라지지 않는다")
  void pick_fallsBackToKo() {
    live("n1");

    assertThat(only(service.publishedFor("IOS", AppLocale.ZH)).title()).isEqualTo("제목 n1");
    assertThat(only(service.publishedFor("IOS", AppLocale.EN)).title()).isEqualTo("제목 n1");
  }

  @Test
  @DisplayName("번역 행이 하나도 없는 공지는 건너뛴다 — 다른 공지는 그대로 나간다")
  void pick_skipsNoticeWithoutAnyText() {
    live("n1");
    AppNotice broken = new AppNotice();
    broken.setId("broken");
    broken.setPlatform(NoticePlatform.ALL);
    broken.setStartsAt(NOW_KST.minusDays(2));
    broken.setEnabled(true);
    broken.setCreatedBy("admin");
    broken.setUpdatedBy("admin");
    stored.add(broken);

    assertThat(service.publishedFor("IOS", AppLocale.KO).notices())
      .extracting(AppNoticeResponse::id).containsExactly("n1");
  }

  @Test
  @DisplayName("버튼은 언어마다 따로다 — 링크는 같아도 그 언어 문구가 없으면 그 언어에는 버튼이 없다")
  void button_perLanguage() {
    AppNotice notice = live("n1");
    notice.putTranslation(AppLocale.EN, "Hello", "Body", null);
    notice.putTranslation(AppLocale.ES, "Hola", "Cuerpo", "Ver más");

    assertThat(only(service.publishedFor("IOS", AppLocale.KO)).button().label()).isEqualTo("자세히");
    assertThat(only(service.publishedFor("IOS", AppLocale.EN)).button()).isNull();
    AppNoticeResponse.Button es = only(service.publishedFor("IOS", AppLocale.ES)).button();
    assertThat(es.label()).isEqualTo("Ver más");
    assertThat(es.url()).isEqualTo("https://example.com");
  }

  @Test
  @DisplayName("헤더가 없는 옛 앱의 응답 본문은 이전과 같은 모양이다")
  void headerless_sameJson() throws Exception {
    live("n1");

    AppNoticesResponse response = service.publishedFor("IOS");

    assertThat(new ObjectMapper().writeValueAsString(response)).isEqualTo(
      "{\"hideDays\":7,\"notices\":[{\"id\":\"n1\",\"revision\":1,\"title\":\"제목 n1\",\"body\":\"본문 n1\","
        + "\"imageUrl\":null,\"button\":{\"label\":\"자세히\",\"url\":\"https://example.com\"}}]}");
  }

  // ── 저장 ────────────────────────────────────────────

  private NoticeInput input(Map<String, NoticeTextInput> translations) {
    return new NoticeInput("베타 기간 안내", "하루 3개까지 만들 수 있어요", "", "",
      "ALL", "0", "2026-09-23T09:00", "", true, translations);
  }

  @Test
  @DisplayName("한국어와 영어를 함께 저장한다 — 한국어는 최상위 필드, 나머지는 번역 행이다")
  void create_koAndEn() {
    AppNotice saved = service.create(input(Map.of(
      "en", new NoticeTextInput("**Three cards** a day", "Body\r\nline", ""))), null, "admin");

    assertThat(saved.getTranslations()).hasSize(2);
    assertThat(saved.getTitle()).isEqualTo("베타 기간 안내");
    assertThat(saved.translation(AppLocale.EN)).hasValueSatisfying(text -> {
      assertThat(text.getTitle()).isEqualTo("**Three cards** a day");
      assertThat(text.getBody()).isEqualTo("Body\nline"); // CRLF 는 LF 로
      assertThat(text.getButtonLabel()).isNull();
    });
  }

  @Test
  @DisplayName("칸을 전부 비운 언어는 없는 것으로 본다 — 저장되지 않는다")
  void create_blankLanguageIsSkipped() {
    AppNotice saved = service.create(input(Map.of("ja", new NoticeTextInput(" ", "", ""))), null, "admin");

    assertThat(saved.getTranslations()).hasSize(1);
    assertThat(saved.hasTranslation("ja")).isFalse();
  }

  @Test
  @DisplayName("다른 언어는 제목과 본문을 함께 적어야 한다 — 하나만 적으면 언어를 알려 주며 아무것도 쓰지 않는다")
  void create_titleOnly_incomplete() {
    assertThatThrownBy(() -> service.create(
      input(Map.of("en", new NoticeTextInput("Hello", "", ""))), null, "admin"))
      .isInstanceOfSatisfying(NoticeLocaleException.class, e -> {
        assertThat(e.getErrorCode()).isEqualTo(ErrorCode.NOTICE_TRANSLATION_INCOMPLETE);
        assertThat(e.getLocale()).isEqualTo(AppLocale.EN);
      });
    verify(repository, never()).save(any(AppNotice.class));
  }

  @Test
  @DisplayName("버튼 문구만 적고 제목·본문을 비운 언어도 미완성이다")
  void create_labelOnly_incomplete() {
    assertThatThrownBy(() -> service.create(
      input(Map.of("en", new NoticeTextInput("", "", "More"))), null, "admin"))
      .extracting("errorCode").isEqualTo(ErrorCode.NOTICE_TRANSLATION_INCOMPLETE);
  }

  @Test
  @DisplayName("다른 언어의 제목도 40자·강조 짝 규칙을 지킨다 — 어느 언어인지 알려 준다")
  void create_translationRules_nameTheLocale() {
    assertThatThrownBy(() -> service.create(
      input(Map.of("es", new NoticeTextInput("a".repeat(41), "Cuerpo", ""))), null, "admin"))
      .isInstanceOfSatisfying(NoticeLocaleException.class, e -> {
        assertThat(e.getErrorCode()).isEqualTo(ErrorCode.NOTICE_TITLE_TOO_LONG);
        assertThat(e.getLocale()).isEqualTo(AppLocale.ES);
      });
    assertThatThrownBy(() -> service.create(
      input(Map.of("en", new NoticeTextInput("**Hello", "Body", ""))), null, "admin"))
      .extracting("errorCode").isEqualTo(ErrorCode.NOTICE_TITLE_EMPHASIS_UNPAIRED);
  }

  @Test
  @DisplayName("한국어가 비면 영어가 있어도 막는다 — 한국어는 필수다")
  void create_koRequired() {
    NoticeInput noKo = new NoticeInput("", "", "", "", "ALL", "0", "2026-09-23T09:00", "", true,
      Map.of("en", new NoticeTextInput("Hello", "Body", "")));

    assertThatThrownBy(() -> service.create(noKo, null, "admin"))
      .isInstanceOfSatisfying(NoticeLocaleException.class, e -> {
        assertThat(e.getErrorCode()).isEqualTo(ErrorCode.NOTICE_TITLE_BLANK);
        assertThat(e.getLocale()).isEqualTo(AppLocale.KO);
      });
  }

  @Test
  @DisplayName("모르는 언어 코드나 translations 안의 ko 는 거절한다 — 화면 밖에서 직접 보낸 요청")
  void create_unknownLocaleKey_rejected() {
    assertThatThrownBy(() -> service.create(
      input(Map.of("fr", new NoticeTextInput("Salut", "Corps", ""))), null, "admin"))
      .extracting("errorCode").isEqualTo(ErrorCode.NOTICE_LOCALE_INVALID);
    assertThatThrownBy(() -> service.create(
      input(Map.of("ko", new NoticeTextInput("제목", "본문", ""))), null, "admin"))
      .extracting("errorCode").isEqualTo(ErrorCode.NOTICE_LOCALE_INVALID);
  }

  @Test
  @DisplayName("다른 언어의 버튼 문구는 링크가 있어야 적을 수 있다")
  void create_translationLabelNeedsUrl() {
    assertThatThrownBy(() -> service.create(
      input(Map.of("en", new NoticeTextInput("Hello", "Body", "More"))), null, "admin"))
      .isInstanceOfSatisfying(NoticeLocaleException.class, e -> {
        assertThat(e.getErrorCode()).isEqualTo(ErrorCode.NOTICE_BUTTON_INCOMPLETE);
        assertThat(e.getLocale()).isEqualTo(AppLocale.EN);
      });
  }

  @Test
  @DisplayName("고칠 때 한 언어를 비우면 그 언어 행이 사라지고 한국어는 그대로다")
  void update_blankingRemovesLanguage() {
    AppNotice saved = service.create(input(Map.of(
      "en", new NoticeTextInput("Hello", "Body", ""))), null, "admin");
    assertThat(saved.hasTranslation("en")).isTrue();

    AppNotice updated = service.update(saved.getId(),
      input(Map.of("en", new NoticeTextInput("", "", ""))), false, null, false, "admin");

    assertThat(updated.hasTranslation("en")).isFalse();
    assertThat(updated.getTitle()).isEqualTo("베타 기간 안내");
  }

  @Test
  @DisplayName("고칠 때 영어를 고쳐도 한국어 글이 바뀌지 않고 언어 행은 중복되지 않는다")
  void update_editsEnglishInPlace() {
    AppNotice saved = service.create(input(Map.of(
      "en", new NoticeTextInput("Hello", "Body", ""))), null, "admin");

    AppNotice updated = service.update(saved.getId(),
      input(Map.of("en", new NoticeTextInput("Hi", "Body 2", ""))), false, null, false, "admin");

    assertThat(updated.getTranslations()).hasSize(2);
    assertThat(updated.translation(AppLocale.EN).map(text -> text.getTitle())).isEqualTo(Optional.of("Hi"));
  }
}
```

`server/src/test/java/com/chuseok22/elumserver/notice/application/service/NoticeCountryTest.java`:

```java
package com.chuseok22.elumserver.notice.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.NoticeProperties;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.notice.application.dto.request.NoticeInput;
import com.chuseok22.elumserver.notice.application.dto.response.AppNoticeResponse;
import com.chuseok22.elumserver.notice.application.dto.response.AppNoticesResponse;
import com.chuseok22.elumserver.notice.core.NoticePlatform;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import com.chuseok22.elumserver.notice.infrastructure.repository.AppNoticeRepository;
import com.chuseok22.elumserver.notice.infrastructure.storage.LocalFileNoticeImageStorage;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.IntStream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

/**
 * 공지의 대상 국가 노출 규칙과 저장 검증 (이슈 #521, 스펙 4.3.1).
 *
 * <p>요청 국가는 컨트롤러가 {@code CurrentRegion.get()} 으로 읽어 넘긴다. 헤더 없는 옛 앱은 {@code KR},
 * 형식이 틀린 헤더는 {@code null}(국가 미상)이다. 국가 미상에게는 대상을 정하지 않은 공지만 보인다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class NoticeCountryTest {

  private static final Instant NOW = Instant.parse("2026-09-23T03:00:00Z"); // 한국 12:00
  private static final LocalDateTime NOW_KST = LocalDateTime.of(2026, 9, 23, 12, 0);

  @TempDir
  Path tempDir;

  @Mock
  private AppNoticeRepository repository;
  @Mock
  private SystemConfigService systemConfigService;

  private final List<AppNotice> stored = new ArrayList<>();
  private NoticeService service;

  @BeforeEach
  void setUp() {
    service = new NoticeService(repository, systemConfigService,
      new LocalFileNoticeImageStorage(new NoticeProperties(tempDir.toString())),
      Clock.fixed(NOW, ZoneOffset.UTC));
    when(repository.findAll()).thenReturn(stored);
    when(repository.save(any(AppNotice.class))).thenAnswer(invocation -> {
      AppNotice notice = invocation.getArgument(0);
      if (notice.getId() == null) {
        notice.setId("notice-" + (stored.size() + 1));
        stored.add(notice);
      }
      return notice;
    });
    when(repository.findById(any())).thenAnswer(invocation -> stored.stream()
      .filter(notice -> notice.getId().equals(invocation.getArgument(0))).findFirst());
    when(systemConfigService.getInt(ConfigKey.NOTICE_HIDE_DAYS)).thenReturn(7);
  }

  /** 지금 게시 중인 공지. [priority] 가 클수록 먼저 나온다. */
  private AppNotice live(String id, String targetCountries, int priority) {
    AppNotice notice = new AppNotice();
    notice.setId(id);
    notice.setTitle("제목 " + id);
    notice.setBody("본문 " + id);
    notice.setButtonUrl("https://example.com");
    notice.setButtonLabel("자세히");
    notice.setPlatform(NoticePlatform.ALL);
    notice.setPriority(priority);
    notice.setTargetCountries(targetCountries);
    notice.setStartsAt(NOW_KST.minusDays(1));
    notice.setEnabled(true);
    notice.setCreatedBy("admin");
    notice.setUpdatedBy("admin");
    stored.add(notice);
    return notice;
  }

  private List<String> ids(AppNoticesResponse response) {
    return response.notices().stream().map(AppNoticeResponse::id).toList();
  }

  // ── 노출 규칙 ───────────────────────────────────────

  @Test
  @DisplayName("대상이 비어 있는 공지(null·빈 값)는 어느 국가에도, 국가 미상에도 보인다")
  void noTarget_shownToEveryRegionIncludingUnknown() {
    live("all", null, 2);
    live("blank", "", 1);

    for (String region : new String[] {"KR", "US", "JP", null}) {
      assertThat(ids(service.publishedFor("IOS", AppLocale.KO, region)))
        .as("국가 %s", region).containsExactly("all", "blank");
    }
  }

  @Test
  @DisplayName("대상이 있으면 목록에 든 국가에만 보인다")
  void targeted_shownOnlyToListedRegions() {
    live("kr-jp", "KR,JP", 0);

    assertThat(ids(service.publishedFor("IOS", AppLocale.KO, "KR"))).containsExactly("kr-jp");
    assertThat(ids(service.publishedFor("IOS", AppLocale.KO, "JP"))).containsExactly("kr-jp");
    assertThat(service.publishedFor("IOS", AppLocale.KO, "US").notices()).isEmpty();
  }

  @Test
  @DisplayName("국가 미상(null)에게는 대상이 지정된 공지가 새지 않는다 — 대상이 비어 있는 공지만 보인다")
  void unknownRegion_neverSeesTargeted() {
    live("targeted", "KR", 5);
    live("open", null, 1);

    assertThat(ids(service.publishedFor("IOS", AppLocale.KO, null))).containsExactly("open");
    // 같은 데이터를 한국 사용자는 둘 다 본다 — 필터가 국가 미상에만 걸린다.
    assertThat(ids(service.publishedFor("IOS", AppLocale.KO, "KR"))).containsExactly("targeted", "open");
  }

  @Test
  @DisplayName("다른 국가 공지가 5개 슬롯을 차지하지 않는다 — 국가는 limit 앞에서 거른다")
  void otherCountryNoticesDoNotTakeSlots() {
    for (int i = 0; i < NoticeService.MAX_SLIDES; i++) {
      live("jp-" + i, "JP", 100 + i);
    }
    live("open", null, 1);

    assertThat(ids(service.publishedFor("IOS", AppLocale.KO, "KR"))).containsExactly("open");
    assertThat(ids(service.publishedFor("IOS", AppLocale.KO, null))).containsExactly("open");
    assertThat(service.publishedFor("IOS", AppLocale.KO, "JP").notices()).hasSize(NoticeService.MAX_SLIDES);
  }

  @Test
  @DisplayName("플랫폼·기간·켜짐·우선순위와 함께 동작한다 — 국가가 맞아도 다른 조건이 안 맞으면 빠진다")
  void combinesWithPlatformPeriodAndOrder() {
    AppNotice iosOnly = live("ios-kr", "KR", 3);
    iosOnly.setPlatform(NoticePlatform.IOS);
    live("all-kr", "KR", 2);
    AppNotice ended = live("ended-kr", "KR", 9);
    ended.setEndsAt(NOW_KST.minusHours(1));
    AppNotice off = live("off-kr", "KR", 9);
    off.setEnabled(false);
    AppNotice future = live("future-kr", "KR", 9);
    future.setStartsAt(NOW_KST.plusDays(1));

    // 우선순위 순서가 그대로다(3 → 2).
    assertThat(ids(service.publishedFor("IOS", AppLocale.KO, "KR"))).containsExactly("ios-kr", "all-kr");
    assertThat(ids(service.publishedFor("ANDROID", AppLocale.KO, "KR"))).containsExactly("all-kr");
    assertThat(service.publishedFor("IOS", AppLocale.KO, "JP").notices()).isEmpty();
  }

  @Test
  @DisplayName("헤더가 없는 기존 앱은 KR 이다 — 대상이 비어 있는 기존 공지는 전과 같이 보이고, 다른 국가용은 안 보인다")
  void headerlessOldApp_seesWhatItAlwaysSaw() {
    live("old", null, 0);
    live("jp-only", "JP", 9);
    live("kr-only", "KR", 8);

    // 국가 인자가 없는 호출은 헤더 없는 옛 앱과 같다.
    assertThat(ids(service.publishedFor("IOS"))).containsExactly("kr-only", "old");
    assertThat(ids(service.publishedFor("IOS", AppLocale.KO))).containsExactly("kr-only", "old");
    assertThat(ids(service.publishedFor("IOS", AppLocale.KO, "KR"))).containsExactly("kr-only", "old");
  }

  @Test
  @DisplayName("응답 본문에는 대상 국가가 나가지 않는다 — 대상이 있어도 없어도 같은 모양이다")
  void response_doesNotExposeTargetCountries() throws Exception {
    live("n1", "KR", 0);

    String json = new ObjectMapper().writeValueAsString(service.publishedFor("IOS"));

    assertThat(json).doesNotContain("targetCountries").doesNotContain("KR");
    assertThat(json).isEqualTo(
      "{\"hideDays\":7,\"notices\":[{\"id\":\"n1\",\"revision\":1,\"title\":\"제목 n1\",\"body\":\"본문 n1\","
        + "\"imageUrl\":null,\"button\":{\"label\":\"자세히\",\"url\":\"https://example.com\"}}]}");
  }

  // ── 저장 ────────────────────────────────────────────

  private NoticeInput inputWith(String targetCountries) {
    return new NoticeInput("베타 기간 안내", "하루 3개까지 만들 수 있어요", "", "",
      "ALL", "0", "2026-09-23T09:00", "", true, Map.of(), targetCountries);
  }

  @Test
  @DisplayName("공백·빈 토큰·중복을 다듬어 저장한다 — 처음 나온 순서를 지킨다")
  void create_normalizes() {
    AppNotice saved = service.create(inputWith(" KR , JP ,KR,\n"), null, "admin");

    assertThat(saved.getTargetCountries()).isEqualTo("KR,JP");
  }

  @Test
  @DisplayName("비었거나 쉼표·공백뿐이면 전체 국가다 — null 로 저장한다")
  void create_blank_meansAll() {
    for (String blank : new String[] {null, "", "  ", " , ,"}) {
      stored.clear();
      AppNotice saved = service.create(inputWith(blank), null, "admin");
      assertThat(saved.getTargetCountries()).as("[%s]", blank).isNull();
    }
  }

  @Test
  @DisplayName("형식이 틀린 코드는 거절하고 아무것도 저장하지 않는다 — 소문자·세 글자·숫자·한글·전각·다른 구분자")
  void create_rejectsMalformed() {
    for (String bad : new String[] {"kr", "Kr", "KOR", "K", "K1", "한국", "KR JP", "KR;JP", "KR|JP", "ＫＲ", "KR,jp"}) {
      assertThatThrownBy(() -> service.create(inputWith(bad), null, "admin"))
        .as("[%s]", bad)
        .extracting("errorCode").isEqualTo(ErrorCode.NOTICE_TARGET_COUNTRIES_INVALID);
    }
    verify(repository, never()).save(any(AppNotice.class));
  }

  @Test
  @DisplayName("허용 국가 목록은 없다 — 형식만 맞으면 새 국가 코드도 받는다")
  void create_acceptsAnyWellFormedCode() {
    AppNotice saved = service.create(inputWith("ZZ,XK"), null, "admin");

    assertThat(saved.getTargetCountries()).isEqualTo("ZZ,XK");
  }

  /** "AA,AB,…" 서로 다른 두 글자 코드 [count] 개. */
  private String codes(int count) {
    return IntStream.range(0, count)
      .mapToObj(i -> "" + (char) ('A' + i / 26) + (char) ('A' + i % 26))
      .collect(Collectors.joining(","));
  }

  @Test
  @DisplayName("255자까지다 — 85개(254자)는 되고 86개(257자)는 막는다")
  void create_maxLength() {
    AppNotice saved = service.create(inputWith(codes(85)), null, "admin");
    assertThat(saved.getTargetCountries()).hasSize(254);

    assertThatThrownBy(() -> service.create(inputWith(codes(86)), null, "admin"))
      .extracting("errorCode").isEqualTo(ErrorCode.NOTICE_TARGET_COUNTRIES_TOO_LONG);
  }

  @Test
  @DisplayName("고칠 때 바꾸고 비울 수 있다 — 비우면 전체 국가로 돌아간다")
  void update_changeAndClear() {
    AppNotice saved = service.create(inputWith("KR"), null, "admin");

    AppNotice changed = service.update(saved.getId(), inputWith("JP, US"), false, null, false, "admin");
    assertThat(changed.getTargetCountries()).isEqualTo("JP,US");

    AppNotice cleared = service.update(saved.getId(), inputWith(""), false, null, false, "admin");
    assertThat(cleared.getTargetCountries()).isNull();
  }

  @Test
  @DisplayName("고치다 형식이 틀리면 거절하고 지금 값을 건드리지 않는다")
  void update_invalid_keepsOldValue() {
    AppNotice saved = service.create(inputWith("KR"), null, "admin");

    assertThatThrownBy(() -> service.update(saved.getId(), inputWith("kr,jp"), false, null, false, "admin"))
      .extracting("errorCode").isEqualTo(ErrorCode.NOTICE_TARGET_COUNTRIES_INVALID);

    assertThat(saved.getTargetCountries()).isEqualTo("KR");
  }
}
```

- [ ] **Step 2: 실행해 실패를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.notice.application.service.NoticeLocaleTest' --tests 'com.chuseok22.elumserver.notice.application.service.NoticeCountryTest'`
Expected: FAIL — 컴파일 오류(`NoticeTextInput`·`NoticeLocaleException`·`publishedFor(String, AppLocale)`·`publishedFor(String, AppLocale, String)`·`NoticeInput` 열한 번째 인자 없음).

- [ ] **Step 3: 에러 코드와 입력·예외 타입을 더한다**

`ErrorCode.java` 182행(`NOTICE_IMAGE_SAVE_FAILED`) 바로 아래에 세 줄을 더한다.

```java
  // 언어별 공지 (이슈 #521). 한국어는 필수라 비면 NOTICE_TITLE_BLANK 같은 기존 코드로 막힌다.
  NOTICE_TRANSLATION_INCOMPLETE(HttpStatus.BAD_REQUEST, "다른 언어는 제목과 본문을 함께 적어주세요."),
  NOTICE_LOCALE_INVALID(HttpStatus.BAD_REQUEST, "알 수 없는 언어예요."),
  // 대상 국가 (이슈 #521). 허용 목록은 없고 형식(두 글자 대문자)과 길이만 본다.
  NOTICE_TARGET_COUNTRIES_INVALID(HttpStatus.BAD_REQUEST, "대상 국가는 KR,JP 처럼 두 글자 대문자 코드를 쉼표로 적어주세요."),
  NOTICE_TARGET_COUNTRIES_TOO_LONG(HttpStatus.BAD_REQUEST, "대상 국가는 255자까지 적을 수 있어요."),
```

`NoticeTextInput.java`:

```java
package com.chuseok22.elumserver.notice.application.dto.request;

/**
 * 한 언어의 공지 글 (이슈 #521). 한국어 이외의 언어에 쓴다 — 한국어는 {@link NoticeInput} 의 최상위 필드다.
 *
 * <p>전부 문자열로 받는다(검증은 {@code NoticeService} 한 곳에서). 세 칸이 모두 비면 그 언어는 없는 것이다.
 */
public record NoticeTextInput(String title, String body, String buttonLabel) {

  public boolean isBlank() {
    return blank(title) && blank(body) && blank(buttonLabel);
  }

  private static boolean blank(String value) {
    return value == null || value.isBlank();
  }
}
```

`NoticeLocaleException.java`:

```java
package com.chuseok22.elumserver.notice.core;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import lombok.Getter;

/**
 * 어느 언어 칸이 틀렸는지 함께 알리는 공지 저장 오류 (이슈 #521).
 *
 * <p>관리자 화면은 언어 탭 뒤에 칸이 숨어 있어 "제목이 너무 길어요"만으로는 어느 탭을 열어야 할지 모른다.
 */
@Getter
public class NoticeLocaleException extends CustomException {

  private final AppLocale locale;

  public NoticeLocaleException(ErrorCode errorCode, AppLocale locale) {
    super(errorCode);
    this.locale = locale;
  }
}
```

`NoticeInput.java` — 11~26행(javadoc 마지막 `@param` 과 record)을 바꾼다.

```java
 * @param startsAt 한국 시각 {@code 2026-09-23T09:00} (브라우저 {@code datetime-local} 값)
 * @param endsAt   비우면 끌 때까지
 * @param translations 한국어 이외 언어의 글. 키는 언어 코드({@code en} {@code ja} {@code zh} {@code es}).
 *                 한국어는 위의 {@code title}·{@code body}·{@code buttonLabel} 이고 필수다 (이슈 #521)
 * @param targetCountries 대상 국가. 쉼표로 구분한 두 글자 대문자 코드({@code KR,JP}), 비우면 전체 국가.
 *                 문자열 그대로 받고 형식은 {@code NoticeService} 가 검사한다 (request DTO 에는 검증을 두지 않는다)
 */
public record NoticeInput(
  String title,
  String body,
  String buttonLabel,
  String buttonUrl,
  String platform,
  String priority,
  String startsAt,
  String endsAt,
  boolean enabled,
  Map<String, NoticeTextInput> translations,
  String targetCountries
) {

  public NoticeInput {
    translations = translations == null ? Map.of() : translations;
    targetCountries = targetCountries == null ? "" : targetCountries;
  }

  /** 언어별 글은 있고 대상 국가는 없는(전체 국가) 입력. */
  public NoticeInput(
    String title, String body, String buttonLabel, String buttonUrl, String platform,
    String priority, String startsAt, String endsAt, boolean enabled,
    Map<String, NoticeTextInput> translations
  ) {
    this(title, body, buttonLabel, buttonUrl, platform, priority, startsAt, endsAt, enabled, translations, "");
  }

  /** 한국어만 있는 입력. 번역이 없던 시절의 호출부와 시험이 그대로 쓴다. */
  public NoticeInput(
    String title, String body, String buttonLabel, String buttonUrl, String platform,
    String priority, String startsAt, String endsAt, boolean enabled
  ) {
    this(title, body, buttonLabel, buttonUrl, platform, priority, startsAt, endsAt, enabled, Map.of());
  }
}
```
(상단에 `import java.util.Map;` 를 더한다.)

- [ ] **Step 4: 응답·서비스·컨트롤러를 고친다**

`AppNoticeResponse.java` 51~62행의 `from` 을 바꾼다. import 에 `AppNoticeTranslation` 을 더한다.

```java
  /** 그 언어로 고른 글([text])로 한 장을 만든다. 이미지·링크는 공지가 공유한다. */
  public static AppNoticeResponse from(AppNotice notice, AppNoticeTranslation text) {
    return new AppNoticeResponse(
      notice.getId(),
      notice.getRevision(),
      text.getTitle(),
      text.getBody(),
      imageUrlOf(notice),
      notice.hasButton(text) ? new Button(text.getButtonLabel(), notice.getButtonUrl()) : null
    );
  }
```

`NoticeService.java`:

1. import 에 추가: `com.chuseok22.elumserver.common.locale.AppLocale`, `com.chuseok22.elumserver.notice.application.dto.request.NoticeTextInput`, `com.chuseok22.elumserver.notice.core.NoticeLocaleException`, `com.chuseok22.elumserver.notice.infrastructure.entity.AppNoticeTranslation`, `java.util.EnumMap`, `java.util.LinkedHashSet`, `java.util.Map`, `java.util.Optional`, `java.util.Set`, `java.util.regex.Pattern`. import `com.chuseok22.elumserver.common.locale.CurrentRegion` 도 더한다(`CurrentRegion.DEFAULT` 상수만 쓴다 — 요청 컨텍스트는 읽지 않는다). 상수 하나를 `MAX_SLIDES`(50행) 아래에 둔다.

```java
  /** 대상 국가 한 개의 형식. 허용 목록은 두지 않는다 — 형식만 본다. */
  private static final Pattern COUNTRY_CODE = Pattern.compile("[A-Z]{2}");
```

2. 99~112행(`publishedFor`)을 바꾼다.

```java
  /**
   * 앱에 줄 공지. 게시 중이고 이 플랫폼에 닿는 것을 순서대로 최대 5개. 언어를 모르는 호출부(헤더 없는 옛 앱)는
   * 한국어다.
   *
   * <p>숨김은 기기에 있으므로 서버는 거르지 않는다 — 앱이 숨긴 것을 빼고 남은 것을 보여준다.
   */
  public AppNoticesResponse publishedFor(String platform) {
    return publishedFor(platform, AppLocale.KO);
  }

  /**
   * 그 언어로 고른 글을 담아 준다. 고르는 순서는 요청 언어 → en → ko 다. 번역 행이 하나도 없는 공지는
   * 건너뛴다 — 글 없는 팝업이 뜨는 것보다 그 공지만 빠지는 편이 낫다(다른 공지는 그대로 나간다).
   *
   * <p>[region] 은 요청 국가다(컨트롤러가 {@code CurrentRegion.get()} 으로 읽어 넘긴다). 대상 국가를 정하지 않은
   * 공지는 어느 국가에나, 정한 공지는 그 국가에만 나간다. <b>{@code null}(국가 미상)에는 대상을 정하지 않은
   * 공지만</b> 나간다 (스펙 4.3.1).
   */
  public AppNoticesResponse publishedFor(String platform, AppLocale locale, String region) {
    NoticePlatform requested = NoticePlatform.parse(platform);
    List<AppNoticeResponse> notices = liveInSlideOrder().stream()
      .filter(notice -> notice.getPlatform().reaches(requested))
      // 국가는 limit 앞에서 거른다. 다른 국가용 공지가 5개 슬롯을 차지하면 이 국가 공지가 밀려난다.
      .filter(notice -> notice.targetsRegion(region))
      .map(notice -> pick(notice, locale).map(text -> AppNoticeResponse.from(notice, text)))
      .flatMap(Optional::stream)
      .limit(MAX_SLIDES)
      .toList();
    return new AppNoticesResponse(hideDays(), notices);
  }

  /** 국가를 모르는 호출부는 헤더 없는 옛 앱과 같다 — {@code KR}({@code CurrentRegion.DEFAULT}). */
  public AppNoticesResponse publishedFor(String platform, AppLocale locale) {
    return publishedFor(platform, locale, CurrentRegion.DEFAULT);
  }

  /** 요청 언어 → en → ko 순으로 처음 있는 글. */
  private Optional<AppNoticeTranslation> pick(AppNotice notice, AppLocale locale) {
    Optional<AppNoticeTranslation> picked = locale.fallbackChain().stream()
      .map(notice::translation)
      .flatMap(Optional::stream)
      .findFirst();
    if (picked.isEmpty()) {
      log.warn("[공지] 번역 행이 없어 건너뜁니다: 공지 {}", notice.getId());
    }
    return picked;
  }
```

3. 249~317행(`Draft` 와 `validate`, 앞의 javadoc 포함)을 바꾼다.

```java
  /** 검증을 통과한, 다듬은 값. 이것만 엔티티에 들어간다. */
  private record Draft(
    Map<AppLocale, Text> texts, String buttonUrl, NoticePlatform platform,
    int priority, LocalDateTime startsAt, LocalDateTime endsAt, boolean enabled, String targetCountries
  ) {

    void applyTo(AppNotice notice) {
      texts.forEach((locale, text) ->
        notice.putTranslation(locale, text.title(), text.body(), text.buttonLabel()));
      // 비운 언어는 없는 것이다. 목록에 없는 언어 행은 지운다.
      notice.retainTranslations(texts.keySet());
      notice.setButtonUrl(buttonUrl);
      notice.setPlatform(platform);
      notice.setPriority(priority);
      notice.setStartsAt(startsAt);
      notice.setEndsAt(endsAt);
      notice.setEnabled(enabled);
      notice.setTargetCountries(targetCountries);
    }
  }

  /** 한 언어의 다듬은 글. */
  private record Text(String title, String body, String buttonLabel) {

  }

  private Draft validate(NoticeInput input) {
    String buttonUrl = trim(input.buttonUrl());
    Map<AppLocale, Text> texts = new EnumMap<>(AppLocale.class);

    // 한국어는 필수다. 비면 NOTICE_TITLE_BLANK 같은 기존 코드로 막힌다.
    texts.put(AppLocale.KO,
      validateText(AppLocale.KO, input.title(), input.body(), input.buttonLabel(), buttonUrl));

    for (Map.Entry<String, NoticeTextInput> entry : input.translations().entrySet()) {
      AppLocale locale = parseTranslationLocale(entry.getKey());
      NoticeTextInput text = entry.getValue();
      // 세 칸을 다 비운 언어는 없는 것이다. 대체 순서(en → ko)로 보여준다.
      if (text == null || text.isBlank()) {
        continue;
      }
      texts.put(locale,
        validateText(locale, text.title(), text.body(), text.buttonLabel(), buttonUrl));
    }

    NoticePlatform platform = NoticePlatform.parse(input.platform());
    int priority = parsePriority(input.priority());
    LocalDateTime startsAt = parseDateTime(input.startsAt());
    if (startsAt == null) {
      throw new CustomException(ErrorCode.NOTICE_PERIOD_INVALID);
    }
    LocalDateTime endsAt = parseDateTime(input.endsAt());
    if (endsAt != null && !startsAt.isBefore(endsAt)) {
      throw new CustomException(ErrorCode.NOTICE_PERIOD_INVALID);
    }

    String targetCountries = normalizeTargetCountries(input.targetCountries());

    return new Draft(texts, emptyToNull(buttonUrl), platform, priority, startsAt, endsAt, input.enabled(),
      targetCountries);
  }

  /** translations 의 키. 모르는 코드와 ko(최상위 필드가 한국어다)는 화면이 만들 수 없으므로 거절한다. */
  private AppLocale parseTranslationLocale(String code) {
    try {
      AppLocale locale = AppLocale.fromCode(code);
      if (locale != AppLocale.KO) {
        return locale;
      }
    } catch (IllegalArgumentException | NullPointerException ignored) {
      // 아래에서 같은 오류로 거절한다
    }
    throw new CustomException(ErrorCode.NOTICE_LOCALE_INVALID);
  }

  /**
   * 쉼표로 구분한 대상 국가를 다듬는다 (스펙 4.3.1). 공백과 빈 토큰(끝 쉼표)은 봐 주고 중복은 처음 것만 남긴다.
   * 코드는 <b>두 글자 대문자</b>만 받는다 — 소문자를 몰래 고치면 관리자가 쓴 값과 저장된 값이 달라지므로 거절한다.
   * 허용 국가 목록은 두지 않는다. 비면 {@code null}(전체 국가).
   *
   * <p>길이는 다듬은 뒤 255자(열 길이)로 막는다. 검사에 걸리면 아무것도 저장하지 않는다(호출부가 저장 전에
   * 부른다).
   */
  static String normalizeTargetCountries(String raw) {
    if (raw == null || raw.isBlank()) {
      return null;
    }
    Set<String> codes = new LinkedHashSet<>();
    for (String token : raw.split(",", -1)) {
      String code = token.strip();
      if (code.isEmpty()) {
        continue;
      }
      if (!COUNTRY_CODE.matcher(code).matches()) {
        throw new CustomException(ErrorCode.NOTICE_TARGET_COUNTRIES_INVALID);
      }
      codes.add(code);
    }
    if (codes.isEmpty()) {
      return null;
    }
    String joined = String.join(",", codes);
    if (joined.length() > AppNotice.TARGET_COUNTRIES_MAX_LENGTH) {
      throw new CustomException(ErrorCode.NOTICE_TARGET_COUNTRIES_TOO_LONG);
    }
    return joined;
  }

  /**
   * 한 언어의 글을 검사한다. 걸리면 <b>어느 언어인지</b> 함께 알린다 — 관리자 화면은 언어 탭 뒤에 칸이 있다.
   *
   * <p>한국어는 기존 규칙 그대로다(비면 막고, 버튼은 문구와 링크가 짝). 다른 언어는 제목과 본문이 함께 있어야
   * 하고, 버튼 문구는 선택이지만 적으면 링크가 있어야 한다. 링크 자체의 검사는 한 번만 한다(공유 값이라서).
   */
  private Text validateText(
    AppLocale locale, String rawTitle, String rawBody, String rawLabel, String buttonUrl
  ) {
    boolean ko = locale == AppLocale.KO;

    // 제목은 한 줄 칸이지만 요청을 직접 보내면 줄바꿈이 들어올 수 있다. 앱 제목 줄이 깨지지 않게 편다.
    String title = trim(rawTitle).replaceAll("[\\r\\n]+", " ");
    // 브라우저 textarea 는 줄바꿈을 CRLF 로 보낸다. LF 로 맞춰야 앱에 CR 이 섞이지 않고,
    // 글자 수도 줄마다 1자씩 부풀지 않는다.
    String body = trim(rawBody == null ? null : rawBody.replace("\r\n", "\n"));

    // 공백만, 표기만(****) 있는 제목은 저장하면 앱에 빈 제목이 뜬다. 브라우저 required 는 공백을 통과시킨다.
    boolean titleBlank = NoticeEmphasis.visibleText(title).isBlank();
    if (!ko && (titleBlank || body.isEmpty())) {
      throw new NoticeLocaleException(ErrorCode.NOTICE_TRANSLATION_INCOMPLETE, locale);
    }
    if (titleBlank) {
      throw new NoticeLocaleException(ErrorCode.NOTICE_TITLE_BLANK, locale);
    }
    if (title.length() > AppNotice.TITLE_MAX_LENGTH) {
      throw new NoticeLocaleException(ErrorCode.NOTICE_TITLE_TOO_LONG, locale);
    }
    if (!NoticeEmphasis.isPaired(title)) {
      throw new NoticeLocaleException(ErrorCode.NOTICE_TITLE_EMPHASIS_UNPAIRED, locale);
    }

    if (body.isEmpty()) {
      throw new NoticeLocaleException(ErrorCode.NOTICE_BODY_BLANK, locale);
    }
    if (body.length() > AppNotice.BODY_MAX_LENGTH) {
      throw new NoticeLocaleException(ErrorCode.NOTICE_BODY_TOO_LONG, locale);
    }

    String buttonLabel = trim(rawLabel);
    if (ko ? buttonLabel.isEmpty() != buttonUrl.isEmpty()
      : (!buttonLabel.isEmpty() && buttonUrl.isEmpty())) {
      throw new NoticeLocaleException(ErrorCode.NOTICE_BUTTON_INCOMPLETE, locale);
    }
    if (buttonLabel.length() > AppNotice.BUTTON_LABEL_MAX_LENGTH) {
      throw new NoticeLocaleException(ErrorCode.NOTICE_BUTTON_LABEL_TOO_LONG, locale);
    }
    if (ko && !buttonUrl.isEmpty() && !isHttpsUrl(buttonUrl)) {
      throw new NoticeLocaleException(ErrorCode.NOTICE_BUTTON_URL_INVALID, locale);
    }

    return new Text(title, body, emptyToNull(buttonLabel));
  }
```
(`isHttpsUrl`·`parsePriority`·`parseDateTime`·`trim`·`emptyToNull` 은 그대로 둔다.)

`NoticeController.java` 27~39행:

```java
  @Override
  @LogMonitoring(logParameters = true, logResult = false, logExecutionTime = true)
  @GetMapping("/api/app/notices")
  public ResponseEntity<AppNoticesResponse> notices(
    @RequestParam(value = "platform", required = false) String platform,
    @RequestHeader(value = HttpHeaders.ACCEPT_LANGUAGE, required = false) String acceptLanguage
  ) {
    // 헤더가 없으면 ko(이미 배포된 앱), 5개 밖이거나 깨진 값이면 en 이다 (C1).
    AppLocale locale = AppLocale.fromAcceptLanguage(acceptLanguage);
    // 국가는 휴대폰 지역 설정(X-Elum-Region)이다. 헤더가 없으면 KR, 형식이 틀리면 null(국가 미상) — C1-2.
    String region = CurrentRegion.get();
    return ResponseEntity.ok()
      .cacheControl(CACHE)
      // 60초 캐시가 언어·국가를 섞지 않게 한다. 없으면 중간 캐시가 한국 응답을 영어·일본 요청에 준다.
      .varyBy(HttpHeaders.ACCEPT_LANGUAGE, CurrentRegion.HEADER)
      .body(noticeService.publishedFor(platform, locale, region));
  }
```
import 에 `com.chuseok22.elumserver.common.locale.AppLocale`, `com.chuseok22.elumserver.common.locale.CurrentRegion`, `org.springframework.http.HttpHeaders`, `org.springframework.web.bind.annotation.RequestHeader` 를 더한다. 헤더 이름은 `CurrentRegion.HEADER` 를 쓴다(응답이 국가에 따라 달라지므로 `Vary` 에 넣는다).

`NoticeControllerDocs.java` 62~67행:

```java
  ResponseEntity<AppNoticesResponse> notices(
    @Parameter(description = "IOS 또는 ANDROID. 비우면 전체 대상 공지만 준다", example = "IOS")
    String platform,
    @Parameter(description = "화면 언어. ko, en, ja, zh-Hans, es. 비우면 ko. 그 언어 글이 없으면 en, 그것도 없으면 ko 글을 준다",
      example = "ko")
    String acceptLanguage
  );
```
그리고 설명(`description`)의 `- 60초 캐시됩니다…` 줄(33행)을 아래 두 줄로 바꾼다.

```java
      - 언어는 `Accept-Language` 로 고릅니다. 그 언어 글이 없으면 `en`, 그것도 없으면 `ko` 글을 줍니다.
        이미지·링크·기간은 모든 언어가 같고, 버튼은 그 언어 문구가 있을 때만 있습니다.
      - 국가는 `X-Elum-Region`(휴대폰 지역 설정, 예 `KR`)으로 정합니다. 헤더가 없으면 `KR` 입니다. 공지에 대상 국가가
        있으면 그 국가에만 나가고, 지역을 알 수 없는(형식이 틀린) 요청에는 대상 국가가 없는 공지만 나갑니다.
      - 60초 캐시되고 `Vary: Accept-Language, X-Elum-Region` 이 붙습니다(`Cache-Control: max-age=60`).
```

`NoticeControllerTest.java` 35~47행(첫 시험)을 새 시그니처에 맞춘다.

```java
  @Test
  @DisplayName("목록은 서비스가 준 그대로이고 60초 캐시되며 언어별로 구분된다")
  void notices_cacheable() {
    AppNoticesResponse body = new AppNoticesResponse(7, List.of(
      new AppNoticeResponse("n1", 1, "**하루 3개**까지", "본문", null, null)));
    // 요청 밖(단위 시험)에서 CurrentRegion.get() 은 KR 이다 — 헤더 없는 옛 앱과 같다.
    when(noticeService.publishedFor("IOS", AppLocale.KO, "KR")).thenReturn(body);

    ResponseEntity<AppNoticesResponse> response = controller.notices("IOS", null);

    assertThat(response.getStatusCode().value()).isEqualTo(200);
    assertThat(response.getBody()).isEqualTo(body);
    assertThat(response.getHeaders().getFirst(HttpHeaders.CACHE_CONTROL)).isEqualTo("max-age=60");
    // 캐시가 언어와 국가를 섞지 않는다.
    assertThat(response.getHeaders().getVary()).contains("Accept-Language", "X-Elum-Region");
  }

  @Test
  @DisplayName("Accept-Language 로 고른 언어를 서비스에 넘긴다 — zh-Hans 는 zh, 깨진 값은 en")
  void notices_passesLocale() {
    controller.notices("IOS", "ja");
    controller.notices("IOS", "zh-Hans");
    controller.notices("IOS", "xx-YY");

    org.mockito.Mockito.verify(noticeService).publishedFor("IOS", AppLocale.JA, "KR");
    org.mockito.Mockito.verify(noticeService).publishedFor("IOS", AppLocale.ZH, "KR");
    org.mockito.Mockito.verify(noticeService).publishedFor("IOS", AppLocale.EN, "KR");
  }
```
import 에 `com.chuseok22.elumserver.common.locale.AppLocale` 를 더한다.

- [ ] **Step 5: 통과를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.notice.*'`
Expected: PASS — 신규 `NoticeLocaleTest` 15건, `NoticeCountryTest` 14건, `NoticeControllerTest` 3건, 기존 `NoticeSaveTest`·`NoticePublishTest`·`NoticeImageFlowTest` 전부(한국어 편의 메서드와 9인자 `NoticeInput` 생성자가 지킨다).

- [ ] **Step 6: 전체 서버 시험**

Run: `cd server && ./gradlew test`
Expected: 컴파일은 통과하고, 관리자 공지 시험(`AdminNoticeControllerTest`·`AdminNoticeTemplateTest`)도 PASS 여야 한다(아직 컨트롤러·템플릿을 안 바꿨고 `getTitle()` 이 한국어를 준다). 실패하면 Task 8 로 넘어가기 전에 원인을 본다.

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add server/src/main/java/com/chuseok22/elumserver/notice \
  server/src/main/java/com/chuseok22/elumserver/common/infrastructure/exception/ErrorCode.java \
  server/src/test/java/com/chuseok22/elumserver/notice/application/service/NoticeLocaleTest.java \
  server/src/test/java/com/chuseok22/elumserver/notice/application/service/NoticeCountryTest.java \
  server/src/test/java/com/chuseok22/elumserver/notice/application/controller/NoticeControllerTest.java
```

---

## Task 7: 관리자 약관 화면 — `consents` · `consent-edit` · `consent-history`

**Files:**
- Create: `server/src/main/java/com/chuseok22/elumserver/admin/application/dto/response/AdminLocaleOption.java`
- Create: `server/src/main/java/com/chuseok22/elumserver/admin/application/dto/response/AdminLocaleStatus.java`
- Create: `server/src/main/java/com/chuseok22/elumserver/admin/application/dto/response/AdminConsentRow.java`
- Modify: `server/src/main/java/com/chuseok22/elumserver/admin/application/dto/request/ConsentEditForm.java:12-26`
- Modify: `server/src/main/java/com/chuseok22/elumserver/admin/application/controller/AdminConsentController.java:1-141` (전체 교체)
- Modify: `server/src/main/resources/templates/admin/consents.html:7-90` (전체 교체)
- Modify: `server/src/main/resources/templates/admin/consent-edit.html:7-120` (전체 교체)
- Modify: `server/src/main/resources/templates/admin/consent-history.html:7-66` (전체 교체)
- Test: `server/src/test/java/com/chuseok22/elumserver/admin/application/controller/AdminConsentControllerTest.java` (새)
- Test: `server/src/test/java/com/chuseok22/elumserver/admin/application/controller/AdminConsentTemplateTest.java` (새)

**Interfaces:**
- Consumes: Task 3 의 `ConsentDocumentService#find/getAll/isPublished/bundleVersion/update/publish/getHistory`
- Produces:
  - `AdminLocaleOption(String code, String label)`, `AdminLocaleOption.all(): List<AdminLocaleOption>`, `AdminLocaleOption.labelOf(AppLocale): String`
  - `AdminLocaleStatus(String code, String label, boolean open, int published, int total)`
  - `AdminConsentRow(ConsentKey key, ConsentDocument document)` — `document` 가 null 이면 그 언어에는 미게시
  - `ConsentEditForm.blank(String today): ConsentEditForm`
  - 화면 경로: `GET /admin/consents?locale=`, `GET /admin/consents/{key}?locale=`, `GET /admin/consents/{key}/history?locale=`, `POST /admin/consents/{key}` (폼 필드 `locale` 추가). `locale` 을 생략하면 `ko` 다

- [ ] **Step 1: 실패하는 컨트롤러 시험을 쓴다**

`server/src/test/java/com/chuseok22/elumserver/admin/application/controller/AdminConsentControllerTest.java`:

```java
package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.dto.response.AdminConsentRow;
import com.chuseok22.elumserver.admin.application.dto.response.AdminLocaleStatus;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService.UpdateResult;
import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import java.security.Principal;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.ui.ExtendedModelMap;
import org.springframework.web.servlet.mvc.support.RedirectAttributesModelMap;

/**
 * 관리자 약관 화면의 언어 처리 (이슈 #521).
 *
 * <p>언어는 쿼리 {@code ?locale=} 이고 생략하면 한국어다. 없는 (키, 언어) 는 최초 게시로 이어진다.
 */
class AdminConsentControllerTest {

  private final ConsentDocumentService service = mock(ConsentDocumentService.class);
  private final AdminConsentController controller = new AdminConsentController(service);
  private final Principal admin = () -> "kimchi";

  private ExtendedModelMap model;
  private MockHttpServletResponse response;
  private RedirectAttributesModelMap redirect;

  @BeforeEach
  void setUp() {
    model = new ExtendedModelMap();
    response = new MockHttpServletResponse();
    redirect = new RedirectAttributesModelMap();
    when(service.getAll(any(AppLocale.class))).thenReturn(List.of());
    when(service.isPublished(any(AppLocale.class))).thenReturn(false);
    when(service.find(any(), any())).thenReturn(Optional.empty());
  }

  private ConsentDocument document(ConsentKey key, String locale) {
    ConsentDocument document = new ConsentDocument();
    document.setConsentKey(key);
    document.setLocale(locale);
    document.setLabel(key.getKoLabel());
    document.setSummary(key.getKoSummary());
    document.setBody("본문");
    document.setVersion("2026-09-21");
    document.setRequired(key.isRequired());
    return document;
  }

  @Test
  @DisplayName("목록은 ?locale= 없이 열면 한국어이고, 키마다 한 줄이며 없는 언어의 줄은 document 가 null 이다")
  void list_defaultsToKo_rowPerKey() {
    when(service.find(ConsentKey.TERMS, AppLocale.KO)).thenReturn(Optional.of(document(ConsentKey.TERMS, "ko")));

    String view = controller.list("ko", model);

    assertThat(view).isEqualTo("admin/consents");
    assertThat(model.get("localeCode")).isEqualTo("ko");
    @SuppressWarnings("unchecked")
    List<AdminConsentRow> rows = (List<AdminConsentRow>) model.get("rows");
    assertThat(rows).hasSize(ConsentKey.values().length);
    assertThat(rows.get(0).document()).isNotNull();
    assertThat(rows.get(1).document()).isNull();
  }

  @Test
  @DisplayName("언어 탭마다 필수 몇 개가 게시됐는지와 열렸는지를 센다")
  void list_localeStatuses() {
    ConsentDocument terms = document(ConsentKey.TERMS, "en");
    ConsentDocument marketing = document(ConsentKey.MARKETING, "en");
    when(service.getAll(AppLocale.EN)).thenReturn(List.of(terms, marketing));

    controller.list("en", model);

    @SuppressWarnings("unchecked")
    List<AdminLocaleStatus> statuses = (List<AdminLocaleStatus>) model.get("localeStatuses");
    assertThat(statuses).extracting(AdminLocaleStatus::code).containsExactly("ko", "en", "ja", "zh", "es");
    AdminLocaleStatus en = statuses.get(1);
    // 선택(소식 받기)은 세지 않는다. 필수는 4종 중 1종이다.
    assertThat(en.published()).isEqualTo(1);
    assertThat(en.total()).isEqualTo(4);
    assertThat(en.open()).isFalse();
  }

  @Test
  @DisplayName("모르는 언어 코드는 400 으로 막는다 — 주소를 손으로 고쳐도 서버가 터지지 않는다")
  void unknownLocale_rejected() {
    assertThatThrownBy(() -> controller.list("fr", model))
      .isInstanceOf(CustomException.class)
      .extracting("errorCode").isEqualTo(ErrorCode.INVALID_INPUT_VALUE);
  }

  @Test
  @DisplayName("게시되지 않은 언어의 편집 화면은 빈 폼이다 — 최초 게시 화면이고 한국어 원문을 참고로 준다")
  void edit_unpublished_blankFormWithReference() {
    ConsentDocument ko = document(ConsentKey.TERMS, "ko");
    when(service.find(ConsentKey.TERMS, AppLocale.KO)).thenReturn(Optional.of(ko));

    String view = controller.edit(ConsentKey.TERMS, "en", model);

    assertThat(view).isEqualTo("admin/consent-edit");
    assertThat(model.get("document")).isNull();
    assertThat(model.get("reference")).isSameAs(ko);
    assertThat(model.get("localeCode")).isEqualTo("en");
  }

  @Test
  @DisplayName("한국어 편집 화면에는 참고 원문이 없다 — 자기 자신이다")
  void edit_ko_noReference() {
    when(service.find(ConsentKey.TERMS, AppLocale.KO)).thenReturn(Optional.of(document(ConsentKey.TERMS, "ko")));

    controller.edit(ConsentKey.TERMS, "ko", model);

    assertThat(model.get("reference")).isNull();
    assertThat(model.get("document")).isNotNull();
  }

  @Test
  @DisplayName("없는 (키, 언어) 에 저장하면 최초 게시로 보내고, 그 언어 이름을 안내한다")
  void post_unpublished_publishes() {
    when(service.isPublished(AppLocale.EN)).thenReturn(false);

    String view = controller.update(ConsentKey.TERMS, "en", "Terms of Service", "Summary", "Body",
      false, "2026-10-02", "법무 확인 완료", admin, model, response, redirect);

    assertThat(view).isEqualTo("redirect:/admin/consents?locale=en");
    verify(service).publish(ConsentKey.TERMS, AppLocale.EN, "Terms of Service", "Summary", "Body",
      "2026-10-02", "kimchi", "법무 확인 완료");
    verify(service, never()).update(any(), any(AppLocale.class), any(), any(), any(), anyBoolean(), any(), any(), any());
    assertThat((String) redirect.getFlashAttributes().get("message")).contains("영어").contains("서비스 이용약관을");
  }

  @Test
  @DisplayName("필수 4종이 모두 게시돼 그 언어가 열리면 안내에 그렇게 적는다")
  void post_publish_announcesOpening() {
    when(service.isPublished(AppLocale.EN)).thenReturn(true);

    controller.update(ConsentKey.AGE_CONFIRM, "en", "Over 14", "Summary", "Body",
      false, "2026-10-02", "r", admin, model, response, redirect);

    assertThat((String) redirect.getFlashAttributes().get("message")).contains("이 언어가 열렸");
  }

  @Test
  @DisplayName("있는 (키, 언어) 는 수정이다 — 그 언어로 고친다")
  void post_existing_updates() {
    when(service.find(ConsentKey.TERMS, AppLocale.EN)).thenReturn(Optional.of(document(ConsentKey.TERMS, "en")));
    when(service.update(eq(ConsentKey.TERMS), eq(AppLocale.EN), any(), any(), any(), anyBoolean(), any(), any(), any()))
      .thenReturn(UpdateResult.SAVED);

    String view = controller.update(ConsentKey.TERMS, "en", "Terms", "Summary", "Body",
      false, null, "오타", admin, model, response, redirect);

    assertThat(view).isEqualTo("redirect:/admin/consents?locale=en");
    verify(service, never()).publish(any(), any(), any(), any(), any(), any(), any(), any());
  }

  @Test
  @DisplayName("저장이 걸리면 400 으로 입력값 그대로 다시 그리고 언어를 유지한다")
  void post_rejected_rerendersWithLocale() {
    when(service.find(ConsentKey.TERMS, AppLocale.EN)).thenReturn(Optional.empty());
    when(service.publish(any(), any(), any(), any(), any(), any(), any(), any()))
      .thenThrow(new CustomException(ErrorCode.CONSENT_REASON_REQUIRED));

    String view = controller.update(ConsentKey.TERMS, "en", "Terms", "Summary", "Body",
      false, "2026-10-02", "", admin, model, response, redirect);

    assertThat(view).isEqualTo("admin/consent-edit");
    assertThat(response.getStatus()).isEqualTo(400);
    assertThat(model.get("localeCode")).isEqualTo("en");
    assertThat((String) model.get("errorMessage")).contains("E-CNS-001");
  }

  @Test
  @DisplayName("이력은 그 언어의 것만 보인다")
  void history_perLocale() {
    controller.history(ConsentKey.TERMS, "en", model);

    verify(service).getHistory(ConsentKey.TERMS, AppLocale.EN);
    verify(service, never()).getHistory(ConsentKey.TERMS, AppLocale.KO);
  }
}
```

- [ ] **Step 2: 실행해 실패를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.admin.application.controller.AdminConsentControllerTest'`
Expected: FAIL — 컴파일 오류(`AdminConsentRow`·`list(String, Model)` 등 없음).

- [ ] **Step 3: DTO 와 폼을 쓴다**

`AdminLocaleOption.java`:

```java
package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.Arrays;
import java.util.List;

/**
 * 관리자 화면의 언어 이름 (이슈 #521). 운영자는 한국어를 쓰므로 한국어 이름이다.
 * 앱에 나가는 문구가 아니라 번역 대상이 아니다.
 */
public record AdminLocaleOption(String code, String label) {

  public static List<AdminLocaleOption> all() {
    return Arrays.stream(AppLocale.values())
      .map(locale -> new AdminLocaleOption(locale.code(), labelOf(locale)))
      .toList();
  }

  public static String labelOf(AppLocale locale) {
    return switch (locale) {
      case KO -> "한국어";
      case EN -> "영어";
      case JA -> "일본어";
      case ZH -> "중국어(간체)";
      case ES -> "스페인어";
    };
  }
}
```

`AdminLocaleStatus.java`:

```java
package com.chuseok22.elumserver.admin.application.dto.response;

/**
 * 약관 화면 언어 탭의 상태 (이슈 #521).
 *
 * @param open      필수 4종이 모두 게시돼 앱 가입 화면이 이 언어로 열리는가
 * @param published 게시된 필수 약관 수
 * @param total     필수 약관 수(법이 정한 값)
 */
public record AdminLocaleStatus(String code, String label, boolean open, int published, int total) {

}
```

`AdminConsentRow.java`:

```java
package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;

/**
 * 약관 목록의 한 줄 (이슈 #521). 선택한 언어에 문서가 없으면 {@code document} 가 null 이다 —
 * "미게시"로 보이고 최초 게시 링크가 달린다.
 */
public record AdminConsentRow(ConsentKey key, ConsentDocument document) {

}
```

`ConsentEditForm.java` — record 본문에 팩토리를 더한다(12~26행 안, `of` 아래).

```java
  /** 아직 게시되지 않은 언어의 최초 게시 폼. 새 버전 칸에 오늘 날짜를 미리 넣는다. */
  public static ConsentEditForm blank(String today) {
    return new ConsentEditForm("", "", "", false, today, "");
  }
```

- [ ] **Step 4: 컨트롤러를 교체한다**

`AdminConsentController.java` 전체를 아래로 바꾼다.

```java
package com.chuseok22.elumserver.admin.application.controller;

import com.chuseok22.elumserver.admin.application.dto.request.ConsentEditForm;
import com.chuseok22.elumserver.admin.application.dto.response.AdminConsentRow;
import com.chuseok22.elumserver.admin.application.dto.response.AdminLocaleOption;
import com.chuseok22.elumserver.admin.application.dto.response.AdminLocaleStatus;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService.UpdateResult;
import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import jakarta.servlet.http.HttpServletResponse;
import java.security.Principal;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/**
 * 약관을 관리자 화면에서 고친다 (이슈 #278). 약관은 (키, 언어) 한 쌍이다 (이슈 #521).
 *
 * <p>전에는 문구 한 줄을 고치려 해도 앱을 다시 빌드해 심사를 받아야 했다.
 *
 * <p>언어는 쿼리 {@code ?locale=} 이고 생략하면 한국어다. 없는 (키, 언어) 에 저장하면 <b>최초 게시</b>다 —
 * 필수 4종이 모두 게시돼야 그 언어가 앱 가입 화면으로 열린다. 없는 언어는 영어로 대체하지 않는다.
 */
@Controller
@RequiredArgsConstructor
public class AdminConsentController {

  private static final String EDIT_VIEW = "admin/consent-edit";

  private final ConsentDocumentService consentDocumentService;

  @GetMapping("/admin/consents")
  public String list(
    @RequestParam(value = "locale", defaultValue = "ko") String localeCode, Model model
  ) {
    AppLocale locale = parseLocale(localeCode);
    List<AdminConsentRow> rows = Arrays.stream(ConsentKey.values())
      .map(key -> new AdminConsentRow(key, consentDocumentService.find(key, locale).orElse(null)))
      .toList();
    model.addAttribute("rows", rows);
    model.addAttribute("localeCode", locale.code());
    model.addAttribute("localeLabel", AdminLocaleOption.labelOf(locale));
    model.addAttribute("localeStatuses", localeStatuses());
    model.addAttribute("published", consentDocumentService.isPublished(locale));
    model.addAttribute("bundleVersion", consentDocumentService.bundleVersion(locale));
    return "admin/consents";
  }

  @GetMapping("/admin/consents/{key}")
  public String edit(
    @PathVariable ConsentKey key,
    @RequestParam(value = "locale", defaultValue = "ko") String localeCode,
    Model model
  ) {
    AppLocale locale = parseLocale(localeCode);
    Optional<ConsentDocument> existing = consentDocumentService.find(key, locale);
    String today = LocalDate.now().toString();
    ConsentEditForm form = existing
      .map(document -> ConsentEditForm.of(document, today))
      .orElseGet(() -> ConsentEditForm.blank(today));
    fillEditModel(model, key, locale, existing.orElse(null), form);
    return EDIT_VIEW;
  }

  @GetMapping("/admin/consents/{key}/history")
  public String history(
    @PathVariable ConsentKey key,
    @RequestParam(value = "locale", defaultValue = "ko") String localeCode,
    Model model
  ) {
    AppLocale locale = parseLocale(localeCode);
    model.addAttribute("key", key);
    model.addAttribute("localeCode", locale.code());
    model.addAttribute("localeLabel", AdminLocaleOption.labelOf(locale));
    model.addAttribute("localeStatuses", localeStatuses());
    model.addAttribute("document", consentDocumentService.find(key, locale).orElse(null));
    model.addAttribute("histories", consentDocumentService.getHistory(key, locale));
    return "admin/consent-history";
  }

  /**
   * 저장한다. 필수 여부는 받지 않는다 — 법이 정한 값이라 관리자가 바꿀 수 없다.
   *
   * <p>그 언어에 아직 문서가 없으면 최초 게시다. 이때 {@code newVersion} 이 게시 버전이다.
   *
   * <p><b>검증에 걸리면 리다이렉트하지 않고 입력한 값 그대로 다시 그린다.</b>
   * 리다이렉트하면 DB 값을 다시 읽어 고치던 전문이 사라진다.
   */
  @PostMapping("/admin/consents/{key}")
  public String update(
    @PathVariable ConsentKey key,
    @RequestParam(value = "locale", defaultValue = "ko") String localeCode,
    @RequestParam("label") String label,
    @RequestParam("summary") String summary,
    @RequestParam("body") String body,
    @RequestParam(value = "bumpVersion", defaultValue = "false") boolean bumpVersion,
    @RequestParam(value = "newVersion", required = false) String newVersion,
    @RequestParam(value = "reason", defaultValue = "") String reason,
    Principal principal,
    Model model,
    HttpServletResponse response,
    RedirectAttributes redirectAttributes
  ) {
    AppLocale locale = parseLocale(localeCode);
    String who = principal == null ? null : principal.getName();
    boolean firstPublish = consentDocumentService.find(key, locale).isEmpty();
    // 안내 문구의 이름. 한국어가 아니면 이름이 외국어라 한국어 조사를 붙일 수 없으므로 한국어 항목 이름을 쓴다.
    String name = locale == AppLocale.KO ? label.strip() : key.getKoLabel();
    String where = "[" + AdminLocaleOption.labelOf(locale) + "] ";

    String message;
    try {
      if (firstPublish) {
        consentDocumentService.publish(key, locale, label, summary, body, newVersion, who, reason);
        message = where + name + objectParticle(name) + " 게시했습니다. 버전 " + newVersion.strip()
          + (consentDocumentService.isPublished(locale)
          ? " 필수 4종이 모두 게시돼 이 언어가 열렸습니다. 이제 이 언어 휴대폰에서 가입할 수 있습니다."
          : " 필수 4종이 모두 게시되면 이 언어가 열립니다.");
      } else {
        UpdateResult result = consentDocumentService.update(
          key, locale, label, summary, body, bumpVersion, newVersion, who, reason);
        message = where + switch (result) {
          case UNCHANGED -> "바뀐 내용이 없어 저장하지 않았습니다.";
          case SAVED -> name + objectParticle(name) + " 저장했습니다.";
          case SAVED_AND_BUMPED -> name + objectParticle(name) + " 저장하고 버전을 올렸습니다. 새 버전 "
            + consentDocumentService.get(key, locale).getVersion();
        };
      }
    } catch (CustomException e) {
      fillEditModel(model, key, locale, consentDocumentService.find(key, locale).orElse(null),
        new ConsentEditForm(label, summary, body, bumpVersion, newVersion, reason));
      model.addAttribute("errorMessage", failureReason(e));
      // 화면은 그대로 그리되 상태 코드는 실패로 둔다. 200으로 두면 모니터링이 성공으로 센다.
      response.setStatus(HttpStatus.BAD_REQUEST.value());
      return EDIT_VIEW;
    }

    redirectAttributes.addFlashAttribute("message", message);
    return "redirect:/admin/consents?locale=" + locale.code();
  }

  // ── 도움 ────────────────────────────────────────────

  /** 주소를 손으로 고쳐 모르는 언어가 들어와도 서버가 터지지 않게 400 으로 막는다. */
  private AppLocale parseLocale(String code) {
    try {
      return AppLocale.fromCode(code);
    } catch (IllegalArgumentException | NullPointerException e) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
  }

  private void fillEditModel(
    Model model, ConsentKey key, AppLocale locale, ConsentDocument document, ConsentEditForm form
  ) {
    model.addAttribute("key", key);
    model.addAttribute("localeCode", locale.code());
    model.addAttribute("localeLabel", AdminLocaleOption.labelOf(locale));
    // null 이면 이 언어에는 아직 문서가 없다 — 최초 게시 화면이다.
    model.addAttribute("document", document);
    model.addAttribute("form", form);
    // 번역하는 사람이 한국어 원문을 곁에서 본다. 한국어를 편집할 때는 자기 자신이라 없다.
    model.addAttribute("reference", locale == AppLocale.KO
      ? null : consentDocumentService.find(key, AppLocale.KO).orElse(null));
    model.addAttribute("localeStatuses", localeStatuses());
  }

  /** 언어 탭마다 필수가 몇 종 게시됐는지와 열렸는지. 선택(소식 받기)은 세지 않는다. */
  private List<AdminLocaleStatus> localeStatuses() {
    int totalRequired = (int) Arrays.stream(ConsentKey.values()).filter(ConsentKey::isRequired).count();
    return Arrays.stream(AppLocale.values()).map(locale -> {
      int published = (int) consentDocumentService.getAll(locale).stream()
        .filter(document -> document.getConsentKey().isRequired())
        .count();
      return new AdminLocaleStatus(locale.code(), AdminLocaleOption.labelOf(locale),
        consentDocumentService.isPublished(locale), published, totalRequired);
    }).toList();
  }

  /** 오류마다 무엇을 고치면 되는지와 추적용 코드를 함께 준다. */
  private String failureReason(CustomException e) {
    return switch (e.getErrorCode()) {
      case CONSENT_REASON_REQUIRED ->
        "수정 사유를 적어주세요. 약관은 법적 문서라 변경 근거가 남아야 합니다. (E-CNS-001)";
      case CONSENT_FIELD_BLANK ->
        "항목 이름·요약·전문은 비워둘 수 없습니다. 하나라도 비면 앱이 서버 약관 전체를 버립니다. (E-CNS-002)";
      case CONSENT_FIELD_TOO_LONG ->
        "항목 이름과 요약은 " + ConsentDocumentService.TEXT_FIELD_MAX_LENGTH
          + "자까지 적을 수 있습니다. (E-CNS-003)";
      case CONSENT_VERSION_REQUIRED ->
        "버전을 올리려면 새 버전을 적어주세요. (E-CNS-004)";
      case CONSENT_VERSION_INVALID ->
        "버전은 2026-09-21 같은 날짜로 적어주세요. (E-CNS-005)";
      case CONSENT_VERSION_NOT_NEWER ->
        "새 버전은 지금 버전보다 늦은 날짜여야 합니다. (E-CNS-006)";
      case CONSENT_ALREADY_PUBLISHED ->
        "이 언어의 이 약관은 이미 게시돼 있습니다. 목록에서 다시 열어 고쳐 주세요. (E-CNS-007)";
      default -> "저장하지 못했습니다. (E-CNS-000)";
    };
  }

  /**
   * 목적격 조사. 항목 이름이 다섯 개인데 받침이 제각각이라 하나로 고정할 수 없다
   * ({@code 이용약관}은 "을", {@code 만 14세 이상입니다}는 "를"). {@code 을(를)}로
   * 뭉뚱그리면 관공서 문투가 된다.
   *
   * <p>한글이 아닌 글자로 끝나면 "을"을 준다 — 틀릴 수는 있어도 화면이 깨지지는 않는다.
   */
  private String objectParticle(String word) {
    if (word == null || word.isBlank()) {
      return "을";
    }
    char last = word.strip().charAt(word.strip().length() - 1);
    if (last < 0xAC00 || last > 0xD7A3) {
      return "을";
    }
    // 한글 음절은 (초성, 중성, 종성) 조합이고 종성 자리가 28칸이다. 나머지가 0이면 받침이 없다.
    return (last - 0xAC00) % 28 == 0 ? "를" : "을";
  }
}
```

- [ ] **Step 5: 컨트롤러 시험 통과를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.admin.application.controller.AdminConsentControllerTest'`
Expected: PASS (10건).

- [ ] **Step 6: 실패하는 템플릿 시험을 쓴다**

`server/src/test/java/com/chuseok22/elumserver/admin/application/controller/AdminConsentTemplateTest.java`:

```java
package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.request.ConsentEditForm;
import com.chuseok22.elumserver.admin.application.dto.response.AdminConsentRow;
import com.chuseok22.elumserver.admin.application.dto.response.AdminLocaleStatus;
import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.thymeleaf.context.Context;
import org.thymeleaf.context.IExpressionContext;
import org.thymeleaf.linkbuilder.StandardLinkBuilder;
import org.thymeleaf.spring6.SpringTemplateEngine;
import org.thymeleaf.templatemode.TemplateMode;
import org.thymeleaf.templateresolver.ClassLoaderTemplateResolver;

/**
 * 약관 관리 화면이 언어별로 그려지는지 (이슈 #521). 서버를 띄우지 않고 템플릿 엔진만으로 그린다.
 * 태그 여닫기는 {@code AdminTemplateTagBalanceTest} 가 따로 본다.
 */
class AdminConsentTemplateTest {

  private SpringTemplateEngine engine;

  @BeforeEach
  void setUp() {
    ClassLoaderTemplateResolver resolver = new ClassLoaderTemplateResolver();
    resolver.setPrefix("templates/");
    resolver.setSuffix(".html");
    resolver.setTemplateMode(TemplateMode.HTML);
    resolver.setCharacterEncoding("UTF-8");
    engine = new SpringTemplateEngine();
    engine.setTemplateResolver(resolver);
    // 웹 요청 없이 그리므로 @{/...} 링크에 붙일 컨텍스트 경로가 없다. 빈 값으로 둔다.
    engine.setLinkBuilder(new StandardLinkBuilder() {
      @Override
      protected String computeContextPath(IExpressionContext context, String base, Map<String, Object> parameters) {
        return "";
      }
    });
  }

  private ConsentDocument document(ConsentKey key, String locale, String version) {
    ConsentDocument document = new ConsentDocument();
    document.setConsentKey(key);
    document.setLocale(locale);
    document.setVersion(version);
    document.setLabel(key.getKoLabel());
    document.setSummary(key.getKoSummary());
    document.setBody("제1조 목적\n본문");
    document.setRequired(key.isRequired());
    document.setPublishedAt(LocalDateTime.of(2026, 9, 21, 9, 0));
    return document;
  }

  private List<AdminLocaleStatus> statuses() {
    return List.of(
      new AdminLocaleStatus("ko", "한국어", true, 4, 4),
      new AdminLocaleStatus("en", "영어", false, 1, 4),
      new AdminLocaleStatus("ja", "일본어", false, 0, 4),
      new AdminLocaleStatus("zh", "중국어(간체)", false, 0, 4),
      new AdminLocaleStatus("es", "스페인어", false, 0, 4));
  }

  private String renderList(String localeCode, String localeLabel, boolean published, List<AdminConsentRow> rows) {
    Context context = new Context();
    context.setVariable("rows", rows);
    context.setVariable("localeCode", localeCode);
    context.setVariable("localeLabel", localeLabel);
    context.setVariable("localeStatuses", statuses());
    context.setVariable("published", published);
    context.setVariable("bundleVersion", published ? "2026-09-21" : "");
    return engine.process("admin/consents", context);
  }

  private String renderEdit(String localeCode, String localeLabel, ConsentDocument document, ConsentDocument reference) {
    Context context = new Context();
    Map<String, Object> variables = new HashMap<>();
    variables.put("key", ConsentKey.TERMS);
    variables.put("localeCode", localeCode);
    variables.put("localeLabel", localeLabel);
    variables.put("document", document);
    variables.put("reference", reference);
    variables.put("form", document == null
      ? ConsentEditForm.blank("2026-10-02") : ConsentEditForm.of(document, "2026-10-02"));
    variables.put("localeStatuses", statuses());
    variables.put("errorMessage", null);
    context.setVariables(variables);
    return engine.process("admin/consent-edit", context);
  }

  private String renderHistory(String localeCode, String localeLabel, ConsentDocument document) {
    Context context = new Context();
    Map<String, Object> variables = new HashMap<>();
    variables.put("key", ConsentKey.TERMS);
    variables.put("localeCode", localeCode);
    variables.put("localeLabel", localeLabel);
    variables.put("document", document);
    variables.put("histories", List.of());
    variables.put("localeStatuses", statuses());
    context.setVariables(variables);
    return engine.process("admin/consent-history", context);
  }

  private List<AdminConsentRow> rowsWithOnlyTerms(String locale) {
    return Arrays.stream(ConsentKey.values())
      .map(key -> new AdminConsentRow(key, key == ConsentKey.TERMS ? document(key, locale, "2026-09-21") : null))
      .toList();
  }

  @Test
  @DisplayName("목록은 다섯 언어 탭과 ✓/− 상태를 보이고 선택한 언어로 링크가 걸린다")
  void list_rendersLanguageTabs() {
    String html = renderList("en", "영어", false, rowsWithOnlyTerms("en"));

    assertThat(html).contains("한국어").contains("영어").contains("일본어").contains("중국어(간체)").contains("스페인어");
    assertThat(html).contains("✓").contains("−");
    assertThat(html).contains("/admin/consents?locale=ja");
    assertThat(html).contains("tab-active");
  }

  @Test
  @DisplayName("게시되지 않은 줄은 '미게시'와 '게시하기' 링크로 그려진다 — 언어가 붙은 편집 주소로")
  void list_unpublishedRowsLinkToFirstPublish() {
    String html = renderList("en", "영어", false, rowsWithOnlyTerms("en"));

    assertThat(html).contains("미게시").contains("게시하기");
    assertThat(html).contains("/admin/consents/PRIVACY?locale=en");
  }

  @Test
  @DisplayName("열리지 않은 언어는 가입이 막힌다는 것과 en 으로 대체하지 않는다는 것을 알린다")
  void list_explainsClosedLanguage() {
    String html = renderList("ja", "일본어", false, rowsWithOnlyTerms("ja"));

    assertThat(html).contains("아직 열리지 않았").contains("영어나 한국어 약관으로 대체하지 않");
  }

  @Test
  @DisplayName("열린 언어는 묶음 버전을 보인다")
  void list_openedLanguageShowsBundleVersion() {
    String html = renderList("ko", "한국어", true, rowsWithOnlyTerms("ko"));

    assertThat(html).contains("2026-09-21").doesNotContain("아직 열리지 않았");
  }

  @Test
  @DisplayName("게시되지 않은 언어의 편집은 최초 게시 폼이다 — 언어가 폼에 실리고 버전 올리기 체크는 없다")
  void edit_unpublishedIsFirstPublish() {
    String html = renderEdit("en", "영어", null, document(ConsentKey.TERMS, "ko", "2026-09-21"));

    assertThat(html).contains("name=\"locale\"").contains("value=\"en\"");
    assertThat(html).contains("게시 버전").contains("최초 게시");
    assertThat(html).doesNotContain("name=\"bumpVersion\"");
    // 번역하는 사람이 한국어 원문을 곁에서 본다.
    assertThat(html).contains("한국어 원문").contains("제1조 목적");
  }

  @Test
  @DisplayName("게시된 언어의 편집은 지금 버전과 '버전을 올립니다'를 보인다")
  void edit_existingShowsBump() {
    String html = renderEdit("en", "영어", document(ConsentKey.TERMS, "en", "2026-10-02"),
      document(ConsentKey.TERMS, "ko", "2026-09-21"));

    assertThat(html).contains("name=\"bumpVersion\"").contains("2026-10-02");
    assertThat(html).doesNotContain("최초 게시");
  }

  @Test
  @DisplayName("한국어 편집에는 원문 참고 칸이 없다")
  void edit_koHasNoReference() {
    String html = renderEdit("ko", "한국어", document(ConsentKey.TERMS, "ko", "2026-09-21"), null);

    assertThat(html).doesNotContain("한국어 원문");
  }

  @Test
  @DisplayName("이력 화면은 언어를 보이고, 게시되지 않은 언어는 그렇다고 말한다")
  void history_unpublished() {
    String html = renderHistory("ja", "일본어", null);

    assertThat(html).contains("일본어").contains("아직 게시되지 않았");
  }
}
```

- [ ] **Step 7: 실행해 실패를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.admin.application.controller.AdminConsentTemplateTest'`
Expected: FAIL — 템플릿이 `localeStatuses`·`key` 변수를 몰라 표현식 오류 또는 문구 불일치.

- [ ] **Step 8: 템플릿 세 개를 교체한다**

`consents.html` 7~90행(`<main>` 전체)을 아래로 바꾼다.

```html
<main th:fragment="content" class="flex-1 p-4 lg:p-8 space-y-6">
  <div th:replace="~{admin/fragments/admin-ui :: pageHeader('약관 관리',
       '앱 동의 화면에 나가는 문구입니다. 여기서 고치면 앱을 새로 올리지 않아도 반영됩니다.')}"></div>

  <div th:if="${message}" class="alert alert-success" th:text="${message}"></div>
  <div th:if="${errorMessage}" class="alert alert-error" th:text="${errorMessage}"></div>

  <!-- 언어마다 약관이 따로다. ✓ 는 필수 4종이 모두 게시돼 앱 가입 화면이 그 언어로 열린다는 뜻이다. -->
  <div role="tablist" class="tabs tabs-boxed w-fit max-w-full flex-wrap" aria-label="약관 언어">
    <a th:each="st : ${localeStatuses}" role="tab" class="tab gap-1"
       th:classappend="${st.code == localeCode} ? 'tab-active'"
       th:href="@{/admin/consents(locale=${st.code})}"
       th:title="|필수 ${st.published}/${st.total}종 게시|">
      <span th:text="${st.label}">한국어</span>
      <span class="font-mono text-xs" th:text="${st.open} ? '✓' : '−'">✓</span>
    </a>
  </div>

  <div class="card bg-base-200">
    <div class="card-body space-y-1 text-sm">
      <th:block th:if="${published}">
        <p>
          <b th:text="${localeLabel}">한국어</b> 회원 동의 기록에 남는 <b>묶음 버전</b>은
          <code class="font-mono" th:text="${bundleVersion}">-</code> 입니다.
          필수 항목 중 가장 최근 버전이며, 선택 항목은 세지 않습니다.
        </p>
      </th:block>
      <th:block th:unless="${published}">
        <p class="font-semibold text-warning">
          <span th:text="${localeLabel}">영어</span> 약관은 아직 열리지 않았습니다.
          필수 4종(이용약관·개인정보·국외 이전·나이 확인)을 모두 게시하면 앱 가입 화면이 이 언어로 열립니다.
        </p>
        <p>
          그 전에는 이 언어 휴대폰에서 가입할 수 없습니다. 동의는 읽을 수 있는 언어로 받아야 성립하므로
          영어나 한국어 약관으로 대체하지 않습니다.
        </p>
      </th:block>
      <p class="text-base-content/60">
        앱은 받은 내용을 저장해 두고 평소엔 그것을 읽습니다.
        서버를 못 봐도 앱에 담긴 기본값으로 화면이 뜨므로 한국어 가입은 막히지 않습니다.
      </p>
    </div>
  </div>

  <div class="overflow-x-auto">
    <table class="table table-sm">
      <thead>
      <tr>
        <th>항목</th>
        <th>구분</th>
        <th>버전</th>
        <th>이 버전 적용일</th>
        <th>마지막 수정</th>
        <th></th>
      </tr>
      </thead>
      <tbody>
      <tr th:each="row : ${rows}" th:with="doc=${row.document}">
        <td>
          <th:block th:if="${doc != null}">
            <div class="font-semibold whitespace-nowrap" th:text="${doc.label}">항목</div>
            <div class="text-xs text-base-content/60" th:text="${doc.summary}">요약</div>
          </th:block>
          <th:block th:unless="${doc != null}">
            <div class="font-semibold whitespace-nowrap text-base-content/60" th:text="${row.key.koLabel}">항목</div>
            <div class="text-xs text-base-content/60">이 언어에는 아직 게시되지 않았습니다</div>
          </th:block>
        </td>
        <td>
          <span th:if="${row.key.required}" class="badge badge-primary badge-sm whitespace-nowrap">필수</span>
          <span th:unless="${row.key.required}" class="badge badge-ghost badge-sm whitespace-nowrap">선택</span>
        </td>
        <td class="font-mono whitespace-nowrap">
          <span th:if="${doc != null}" th:text="${doc.version}">버전</span>
          <span th:unless="${doc != null}" class="badge badge-warning badge-sm">미게시</span>
        </td>
        <td class="whitespace-nowrap text-xs"
            th:text="${doc != null} ? ${#temporals.format(doc.publishedAt, 'yyyy-MM-dd HH:mm')} : '-'">적용일</td>
        <td class="whitespace-nowrap text-xs"
            th:text="${doc != null and doc.updatedAt != null} ? ${#temporals.format(doc.updatedAt, 'yyyy-MM-dd HH:mm')} : '-'">수정</td>
        <td class="whitespace-nowrap">
          <a th:if="${doc != null}" th:href="@{/admin/consents/{key}(key=${row.key},locale=${localeCode})}"
             class="btn btn-primary btn-xs">고치기</a>
          <a th:unless="${doc != null}" th:href="@{/admin/consents/{key}(key=${row.key},locale=${localeCode})}"
             class="btn btn-outline btn-primary btn-xs">게시하기</a>
          <a th:href="@{/admin/consents/{key}/history(key=${row.key},locale=${localeCode})}"
             class="btn btn-ghost btn-xs">이력</a>
        </td>
      </tr>
      </tbody>
    </table>
  </div>

  <div class="card bg-base-200">
    <div class="card-body text-sm space-y-2">
      <h2 class="card-title text-base">고치기 전에 알아둘 것</h2>
      <ul class="list-disc space-y-1 pl-5 text-base-content/80">
        <li>
          <b>필수·선택은 바꿀 수 없습니다.</b> 법이 정한 값이라 화면에 보여주기만 합니다.
        </li>
        <li>
          <b>언어마다 약관이 따로입니다.</b> 한 언어를 고쳐도 다른 언어는 바뀌지 않습니다.
          다른 언어는 <b>법무 확인을 거친 본문만</b> 게시합니다. 번역을 임의로 바꾸지 않습니다.
        </li>
        <li>
          <b>필수 4종이 모두 게시돼야 그 언어가 열립니다.</b> 열린 뒤에는 영어로 대체하지 않고 그 언어 약관만 나갑니다.
        </li>
        <li>
          <b>버전을 올려도 기존 회원에게 다시 묻지는 않습니다.</b>
          새로 동의하는 사람만 새 버전으로 기록됩니다. 기존 회원의 재동의가
          법적으로 필요한 변경이라면 앱 공지 등으로 따로 알려야 합니다.
        </li>
        <li>오타를 고칠 때는 버전을 올리지 마세요. 어떤 문구에 동의했는지 가리기 어려워집니다.</li>
        <li>
          게시된 개인정보처리방침(<code class="font-mono">twin-fang.github.io/elum/privacy.html</code>,
          다른 언어는 <code class="font-mono">/{언어}/privacy.html</code>)과
          <b>내용이 같아야 합니다.</b> 한쪽만 고치면 심사에서 불일치로 지적받습니다.
        </li>
        <li>수정 사유는 반드시 남습니다. 약관은 법적 문서라 변경 근거가 곧 증빙입니다.</li>
      </ul>
    </div>
  </div>
</main>
```

`consent-edit.html` 7~120행(`<main>` 전체)을 아래로 바꾼다.

```html
<main th:fragment="content" class="flex-1 p-4 lg:p-8 space-y-6">
  <div class="flex flex-wrap items-center gap-2">
    <a th:href="@{/admin/consents(locale=${localeCode})}" class="btn btn-ghost btn-sm">← 목록</a>
    <h1 class="text-2xl font-bold" th:text="${document != null} ? ${document.label} : ${key.koLabel}">항목</h1>
    <span class="badge badge-outline" th:text="${localeLabel}">한국어</span>
    <span th:if="${document != null}" class="badge badge-outline font-mono" th:text="${document.version}">버전</span>
    <span th:unless="${document != null}" class="badge badge-warning">미게시 · 최초 게시</span>
    <a th:href="@{/admin/consents/{key}/history(key=${key},locale=${localeCode})}"
       class="btn btn-ghost btn-sm ml-auto">이력 보기</a>
  </div>

  <!-- 같은 항목을 다른 언어로 옮겨 가는 탭. 저장하지 않은 입력은 사라지므로 옮기기 전에 저장한다. -->
  <div role="tablist" class="tabs tabs-boxed w-fit max-w-full flex-wrap" aria-label="약관 언어">
    <a th:each="st : ${localeStatuses}" role="tab" class="tab gap-1"
       th:classappend="${st.code == localeCode} ? 'tab-active'"
       th:href="@{/admin/consents/{key}(key=${key},locale=${st.code})}">
      <span th:text="${st.label}">한국어</span>
      <span class="font-mono text-xs" th:text="${st.open} ? '✓' : '−'">✓</span>
    </a>
  </div>

  <!-- 검증에 걸리면 이 화면을 입력값 그대로 다시 그린다. 리다이렉트하면 고치던 전문이 사라진다. -->
  <div th:if="${errorMessage}" class="alert alert-error" role="alert" th:text="${errorMessage}"></div>

  <div th:if="${document == null}" class="alert alert-info text-sm" role="status">
    <span>
      <b th:text="${localeLabel}">영어</b> 약관을 <b>최초 게시</b>합니다.
      <b>법무 확인을 거친 본문만</b> 넣어 주세요. 필수 4종이 모두 게시되면 앱 가입 화면이 이 언어로 열립니다.
    </span>
  </div>

  <details th:if="${reference != null}" class="collapse collapse-arrow bg-base-200">
    <summary class="collapse-title text-sm font-semibold">한국어 원문 보기 (참고)</summary>
    <div class="collapse-content">
      <p class="mb-2 text-xs text-base-content/60" th:text="${reference.summary}">요약</p>
      <pre class="max-h-96 overflow-auto rounded bg-base-100 p-3 text-sm leading-relaxed whitespace-pre-wrap font-sans"
           th:text="${reference.body}">본문</pre>
    </div>
  </details>

  <form th:action="@{/admin/consents/{key}(key=${key})}" method="post" class="space-y-6">
    <input type="hidden" name="locale" th:value="${localeCode}"/>
    <div class="card bg-base-100 shadow-md">
      <div class="card-body space-y-4">
        <div class="grid gap-4 md:grid-cols-2">
          <label class="form-control">
            <div class="label"><span class="label-text">항목 이름</span></div>
            <input type="text" name="label" class="input input-bordered" maxlength="255"
                   th:value="${form.label}" required/>
            <div class="label"><span class="label-text-alt">동의 화면 목록에 보이는 줄입니다</span></div>
          </label>
          <label class="form-control">
            <div class="label"><span class="label-text">한 줄 요약</span></div>
            <input type="text" name="summary" class="input input-bordered" maxlength="255"
                   th:value="${form.summary}" required/>
            <div class="label"><span class="label-text-alt">항목 이름 아래에 작게 붙습니다</span></div>
          </label>
        </div>

        <!-- 필수 여부는 법이 정한다. 관리자가 바꿀 수 있게 두었더니, 끄는 순간 사용자가 켜지 않은
             항목이 동의한 것으로 기록됐다 (#278 QA). 보여주기만 한다. -->
        <div class="flex items-start gap-3">
          <span th:if="${key.required}" class="badge badge-primary whitespace-nowrap">필수</span>
          <span th:unless="${key.required}" class="badge badge-ghost whitespace-nowrap">선택</span>
          <span class="text-xs text-base-content/60"
                th:text="${key.required}
                  ? '법이 요구하는 항목이라 선택으로 바꿀 수 없습니다'
                  : '광고성 정보 수신은 법상 선택이어야 해서 필수로 바꿀 수 없습니다'">설명</span>
        </div>

        <label class="form-control">
          <div class="label"><span class="label-text">전문</span></div>
          <textarea name="body" class="textarea textarea-bordered h-96 text-sm leading-relaxed"
                    th:text="${form.body}" required></textarea>
        </label>
      </div>
    </div>

    <div class="card bg-base-200">
      <div class="card-body space-y-4">
        <h2 class="card-title text-base"
            th:text="${document == null} ? '이 게시를 어떻게 남길까요' : '이 수정을 어떻게 남길까요'">이 수정을 어떻게 남길까요</h2>

        <label class="form-control">
          <div class="label">
            <span class="label-text"
                  th:text="${document == null} ? '게시 사유' : '수정 사유'">수정 사유</span>
            <span class="label-text"><span class="text-error">*</span></span>
          </div>
          <input type="text" name="reason" class="input input-bordered" th:value="${form.reason}"
                 placeholder="예: 문의 이메일 주소 변경 / 개인정보 보유 기간 문구 정정 / 영어 약관 처음 올림(법무 확인 완료)" required/>
          <div class="label">
            <span class="label-text-alt">
              약관은 법적 문서입니다. <b>무엇을 왜 바꿨는지가 곧 증빙</b>이라 비워둘 수 없습니다
            </span>
          </div>
        </label>

        <div class="divider my-0"></div>

        <!-- 이미 있는 문서: 버전을 올릴지 고른다. -->
        <th:block th:if="${document != null}">
          <label class="label cursor-pointer justify-start gap-3">
            <input type="checkbox" name="bumpVersion" value="true" class="checkbox checkbox-warning"
                   id="bump-version" th:checked="${form.bumpVersion}"/>
            <span class="label-text">
              버전을 올립니다
              <span class="block text-xs text-base-content/60">
                이후 동의하는 사람은 새 버전으로 기록됩니다. <b>기존 회원에게 다시 묻지는 않습니다</b> —
                내용이 실제로 달라졌을 때만 올리세요
              </span>
            </span>
          </label>

          <label class="form-control max-w-xs">
            <div class="label"><span class="label-text">새 버전</span></div>
            <input type="text" name="newVersion" class="input input-bordered font-mono"
                   th:value="${form.newVersion}" id="new-version" placeholder="2026-09-21"
                   th:disabled="${!form.bumpVersion}"/>
            <div class="label">
              <span class="label-text-alt">
                날짜로 적습니다. 지금 버전(<span class="font-mono" th:text="${document.version}">-</span>)보다
                늦어야 합니다
              </span>
            </div>
          </label>
        </th:block>

        <!-- 처음 게시: 버전이 곧 게시 버전이다. 비교할 지금 버전이 없다. -->
        <th:block th:unless="${document != null}">
          <label class="form-control max-w-xs">
            <div class="label"><span class="label-text">게시 버전 <span class="text-error">*</span></span></div>
            <input type="text" name="newVersion" class="input input-bordered font-mono"
                   th:value="${form.newVersion}" placeholder="2026-10-02" required/>
            <div class="label">
              <span class="label-text-alt">날짜로 적습니다. 이 언어의 이 약관이 처음 나가는 버전입니다</span>
            </div>
          </label>
        </th:block>
      </div>
    </div>

    <div class="flex justify-end gap-2">
      <a th:href="@{/admin/consents(locale=${localeCode})}" class="btn btn-ghost">취소</a>
      <button type="submit" class="btn btn-primary"
              th:text="${document == null} ? '게시' : '저장'">저장</button>
    </div>
  </form>

  <!-- 레이아웃이 떠 가는 것은 이 <main> 하나뿐이다. 바깥에 두면 렌더링 결과에
       실리지 않아 스크립트가 통째로 사라진다 (실제로 그랬다). -->
  <script>
    // 버전 칸은 올리기로 했을 때만 연다. 늘 열어 두면 올릴 생각이 없을 때도
    // 값이 채워져 있어 "올라간 건가?"를 매번 헷갈리게 한다. (최초 게시 화면에는 이 칸이 없다.)
    (function () {
      var bump = document.getElementById('bump-version');
      var version = document.getElementById('new-version');
      if (!bump || !version) return;
      bump.addEventListener('change', function () {
        version.disabled = !bump.checked;
      });
    })();
  </script>
</main>
```

`consent-history.html` 7~66행(`<main>` 전체)을 아래로 바꾼다.

```html
<main th:fragment="content" class="flex-1 p-4 lg:p-8 space-y-6">
  <div class="flex flex-wrap items-center gap-2">
    <a th:href="@{/admin/consents(locale=${localeCode})}" class="btn btn-ghost btn-sm">← 목록</a>
    <h1 class="text-2xl font-bold">
      <span th:text="${document != null} ? ${document.label} : ${key.koLabel}">항목</span> 변경 이력
    </h1>
    <span class="badge badge-outline" th:text="${localeLabel}">한국어</span>
    <a th:href="@{/admin/consents/{key}(key=${key},locale=${localeCode})}"
       class="btn btn-primary btn-sm ml-auto"
       th:text="${document != null} ? '고치기' : '게시하기'">고치기</a>
  </div>

  <!-- 언어마다 이력이 따로다. 분쟁 때는 동의한 사람의 언어(member.consent_locale)로 이 탭을 연다. -->
  <div role="tablist" class="tabs tabs-boxed w-fit max-w-full flex-wrap" aria-label="약관 언어">
    <a th:each="st : ${localeStatuses}" role="tab" class="tab gap-1"
       th:classappend="${st.code == localeCode} ? 'tab-active'"
       th:href="@{/admin/consents/{key}/history(key=${key},locale=${st.code})}">
      <span th:text="${st.label}">한국어</span>
      <span class="font-mono text-xs" th:text="${st.open} ? '✓' : '−'">✓</span>
    </a>
  </div>

  <div th:if="${document != null}" class="card bg-base-100 shadow">
    <div class="card-body">
      <h2 class="card-title text-base">
        지금 적용 중
        <span class="badge badge-primary font-mono" th:text="${document.version}">버전</span>
      </h2>
      <p class="text-sm text-base-content/60" th:text="${document.summary}">요약</p>
      <pre class="mt-2 max-h-64 overflow-auto rounded bg-base-200 p-3 text-sm leading-relaxed whitespace-pre-wrap font-sans"
           th:text="${document.body}">본문</pre>
    </div>
  </div>

  <div th:unless="${document != null}" class="alert alert-warning text-sm">
    이 언어의 이 약관은 아직 게시되지 않았습니다.
  </div>

  <div>
    <h2 class="mb-2 text-lg font-semibold">지난 내용</h2>
    <p class="mb-4 text-sm text-base-content/60">
      고치기 <b>직전</b>의 내용이 새것부터 쌓입니다. 분쟁이 생겼을 때
      "그 사람이 동의한 시점의 문구"를 여기서 찾습니다. 처음 게시한 기록은 <b>[최초 게시]</b> 로 시작하고
      게시한 본문 그대로가 남습니다.
    </p>

    <!-- th:replace 가 th:if 보다 먼저 실행된다. 한 태그에 두면 조건이 무시되고
         이력이 있어도 "아직 고친 적이 없어요"가 함께 그려진다. -->
    <th:block th:if="${histories.isEmpty()}">
      <div th:replace="~{admin/fragments/admin-ui :: emptyState('아직 고친 적이 없어요')}"></div>
    </th:block>

    <div class="space-y-3">
      <details th:each="h : ${histories}" class="collapse collapse-arrow bg-base-200">
        <summary class="collapse-title">
          <div class="flex flex-wrap items-center gap-2">
            <span class="badge badge-outline font-mono" th:text="${h.version}">버전</span>
            <span class="text-sm font-semibold" th:text="${h.label}">이름</span>
            <span th:if="${h.required}" class="badge badge-sm">필수</span>
            <span th:unless="${h.required}" class="badge badge-ghost badge-sm">선택</span>
            <span class="ml-auto text-xs text-base-content/60 whitespace-nowrap"
                  th:text="${#temporals.format(h.createdAt, 'yyyy-MM-dd HH:mm')}">시각</span>
          </div>
          <div class="mt-1 text-xs text-base-content/70">
            <span th:text="${h.changedBy}">누가</span> ·
            <span th:text="${h.reason}">왜</span>
          </div>
        </summary>
        <div class="collapse-content">
          <p class="mb-2 text-xs text-base-content/60" th:text="${h.summary}">요약</p>
          <pre class="max-h-96 overflow-auto rounded bg-base-100 p-3 text-sm leading-relaxed whitespace-pre-wrap font-sans"
               th:text="${h.body}">본문</pre>
        </div>
      </details>
    </div>
  </div>
</main>
```

- [ ] **Step 9: 통과를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.admin.*'`
Expected: PASS — `AdminConsentTemplateTest` 8건, `AdminConsentControllerTest` 10건, `AdminTemplateTagBalanceTest`(새 템플릿 여닫기), 기존 관리자 시험 전부.

- [ ] **Step 10: 커밋 (`/pro-commit`)**

```bash
git add server/src/main/java/com/chuseok22/elumserver/admin/application/dto/response/AdminLocaleOption.java \
  server/src/main/java/com/chuseok22/elumserver/admin/application/dto/response/AdminLocaleStatus.java \
  server/src/main/java/com/chuseok22/elumserver/admin/application/dto/response/AdminConsentRow.java \
  server/src/main/java/com/chuseok22/elumserver/admin/application/dto/request/ConsentEditForm.java \
  server/src/main/java/com/chuseok22/elumserver/admin/application/controller/AdminConsentController.java \
  server/src/main/resources/templates/admin/consents.html \
  server/src/main/resources/templates/admin/consent-edit.html \
  server/src/main/resources/templates/admin/consent-history.html \
  server/src/test/java/com/chuseok22/elumserver/admin/application/controller/AdminConsentControllerTest.java \
  server/src/test/java/com/chuseok22/elumserver/admin/application/controller/AdminConsentTemplateTest.java
```

---

## Task 8: 관리자 공지 화면 — `notices` · `notice-edit` (서버 쪽과 템플릿)

**Files:**
- Create: `server/src/main/java/com/chuseok22/elumserver/admin/application/dto/request/NoticeTextsForm.java`
- Modify: `server/src/main/java/com/chuseok22/elumserver/admin/application/dto/request/NoticeEditForm.java:15-83` (`targetCountries` 컴포넌트, `blank`·`of`, `koFilled`, `toInput`, `toInput(NoticeTextsForm)`)
- Modify: `server/src/main/java/com/chuseok22/elumserver/admin/application/controller/AdminNoticeController.java:66-129, 172-229, 232-253`
- Modify: `server/src/main/resources/templates/admin/notices.html:19-61, 103-114`
- Modify: `server/src/main/resources/templates/admin/notice-edit.html:27-108, 177-193`
- Modify: `server/src/test/java/com/chuseok22/elumserver/admin/application/controller/AdminNoticeControllerTest.java:80, 95, 107, 118, 134, 151` (호출 6곳) + 신규 시험
- Modify: `server/src/test/java/com/chuseok22/elumserver/admin/application/controller/AdminNoticeTemplateTest.java:77-103` (`renderList`·`renderEdit`) + 신규 시험
- Test: `server/src/test/java/com/chuseok22/elumserver/admin/application/dto/request/NoticeTextsFormTest.java` (새)

**Interfaces:**
- Consumes: Task 6 의 `NoticeInput(…, Map<String, NoticeTextInput>)`, `NoticeLocaleException`, `AppNotice#translations`, Task 7 의 `AdminLocaleOption`
- Produces:
  - `NoticeTextsForm` — JavaBean. `getTranslations(): Map<String, NoticeTextsForm.Text>`(폼 이름 `translations[en].title` 으로 묶인다), `textOf(String code): Text`, `filled(String code): boolean`, `toInputs(): Map<String, NoticeTextInput>`, `static of(AppNotice): NoticeTextsForm`
  - `NoticeEditForm#koFilled(): boolean`, `NoticeEditForm#toInput(NoticeTextsForm): NoticeInput`
  - 대상 국가: `NoticeEditForm` 의 마지막 컴포넌트 `String targetCountries`(쉼표 구분 문자열 그대로, 없으면 `""`), 입력 이름 `targetCountries`·아이디 `notice-target-countries`. 목록·편집 화면은 `AppNotice#targetCountryList()` 를 읽는다. 검증은 Task 6 의 `NoticeService` 한 곳이고 이 화면은 에러 문구(`E-NTC-018`·`E-NTC-019`)만 안내한다
  - `AdminNoticeController#create(NoticeEditForm form, NoticeTextsForm texts, MultipartFile image, Principal, Model, HttpServletResponse, RedirectAttributes)`, `#update(String id, NoticeEditForm form, NoticeTextsForm texts, MultipartFile image, …)`
  - 모델 속성 `locales: List<AdminLocaleOption>`(모든 공지 화면), `texts: NoticeTextsForm`(편집 화면), 미리보기 JSON 슬라이드의 `texts: {언어: {title, body, buttonLabel}}`

> **왜 언어별 폼을 별도 JavaBean 으로 두나.** 한국어 칸(`title`·`body`·`buttonLabel`)은 지금 그대로 `NoticeEditForm`(record)의 최상위 필드다 — "한국어 필수·나머지 선택"이 모양에 드러나고 기존 폼·시험이 거의 안 바뀐다. 나머지 언어는 `translations[en].title` 같은 이름으로 들어오는데, record 생성자 바인딩은 `Map<String, record>` 를 믿을 수 없으므로 setter 방식 JavaBean 이 안전하다. 바인딩이 되는지는 `NoticeTextsFormTest` 가 직접 본다.

- [ ] **Step 1: 실패하는 폼 시험을 쓴다**

`server/src/test/java/com/chuseok22/elumserver/admin/application/dto/request/NoticeTextsFormTest.java`:

```java
package com.chuseok22.elumserver.admin.application.dto.request;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.notice.application.dto.request.NoticeTextInput;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.MutablePropertyValues;
import org.springframework.web.bind.WebDataBinder;

/**
 * 공지 편집 폼의 다른 언어 칸 (이슈 #521).
 *
 * <p>브라우저가 {@code translations[en].title} 로 보낸 값이 실제로 묶이는지를 스프링 바인더로 직접 본다.
 * 묶이지 않으면 관리자가 쓴 영어 글이 조용히 사라진다.
 */
class NoticeTextsFormTest {

  @Test
  @DisplayName("translations[en].title 같은 이름이 언어별로 묶인다")
  void bindsIndexedNames() {
    NoticeTextsForm form = new NoticeTextsForm();
    WebDataBinder binder = new WebDataBinder(form, "texts");

    binder.bind(new MutablePropertyValues(Map.of(
      "translations[en].title", "Hello",
      "translations[en].body", "Body",
      "translations[en].buttonLabel", "More",
      "translations[ja].title", "")));

    assertThat(form.getTranslations()).containsOnlyKeys("en", "ja");
    assertThat(form.textOf("en").getTitle()).isEqualTo("Hello");
    assertThat(form.textOf("en").getButtonLabel()).isEqualTo("More");
    // 보내지 않은 칸은 빈 문자열이다 — null 이 서비스까지 가지 않는다.
    assertThat(form.textOf("ja").getBody()).isEmpty();
  }

  @Test
  @DisplayName("없는 언어를 물어도 터지지 않는다 — 템플릿이 칸을 채울 때 쓴다")
  void textOf_missingIsBlank() {
    NoticeTextsForm form = new NoticeTextsForm();

    assertThat(form.textOf("es").getTitle()).isEmpty();
    assertThat(form.filled("es")).isFalse();
  }

  @Test
  @DisplayName("제목과 본문이 둘 다 있어야 채워진 언어다 — 탭의 ✓ 가 이 기준이다")
  void filled_needsTitleAndBody() {
    NoticeTextsForm form = new NoticeTextsForm();
    NoticeTextsForm.Text titleOnly = new NoticeTextsForm.Text();
    titleOnly.setTitle("Hello");
    NoticeTextsForm.Text both = new NoticeTextsForm.Text();
    both.setTitle("Hola");
    both.setBody("Cuerpo");
    form.getTranslations().put("en", titleOnly);
    form.getTranslations().put("es", both);

    assertThat(form.filled("en")).isFalse();
    assertThat(form.filled("es")).isTrue();
  }

  @Test
  @DisplayName("toInputs 는 칸을 그대로 서비스 입력으로 옮긴다 — 비운 언어도 넘겨 서비스가 지우게 한다")
  void toInputs_keepsBlankLanguages() {
    NoticeTextsForm form = new NoticeTextsForm();
    form.getTranslations().put("ja", new NoticeTextsForm.Text());

    Map<String, NoticeTextInput> inputs = form.toInputs();

    assertThat(inputs).containsOnlyKeys("ja");
    assertThat(inputs.get("ja").isBlank()).isTrue();
  }

  @Test
  @DisplayName("of(공지) 는 한국어를 뺀 번역을 칸에 채운다")
  void of_notice_excludesKo() {
    AppNotice notice = new AppNotice();
    notice.putTranslation(AppLocale.KO, "제목", "본문", null);
    notice.putTranslation(AppLocale.EN, "Hello", "Body", "More");

    NoticeTextsForm form = NoticeTextsForm.of(notice);

    assertThat(form.getTranslations()).containsOnlyKeys("en");
    assertThat(form.textOf("en").getTitle()).isEqualTo("Hello");
    assertThat(form.textOf("en").getButtonLabel()).isEqualTo("More");
    // 버튼 문구가 없는 언어는 null 이 아니라 빈 문자열이다 — 칸에 "null" 이 찍히지 않는다.
    notice.putTranslation(AppLocale.ES, "Hola", "Cuerpo", null);
    assertThat(NoticeTextsForm.of(notice).textOf("es").getButtonLabel()).isEmpty();
  }
}
```

- [ ] **Step 2: 실행해 실패를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.admin.application.dto.request.NoticeTextsFormTest'`
Expected: FAIL — 컴파일 오류(`NoticeTextsForm` 없음).

- [ ] **Step 3: 폼을 쓴다**

`NoticeTextsForm.java`:

```java
package com.chuseok22.elumserver.admin.application.dto.request;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.notice.application.dto.request.NoticeTextInput;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import java.util.LinkedHashMap;
import java.util.Map;
import lombok.Getter;
import lombok.Setter;

/**
 * 공지 편집 화면의 한국어 이외 언어 칸 (이슈 #521).
 *
 * <p>한국어는 {@link NoticeEditForm} 의 최상위 필드다. 여기는 나머지 언어이고, 브라우저가
 * {@code translations[en].title} 같은 이름으로 보낸다. 검증에 걸려 다시 그릴 때 입력값 그대로 칸을 채우려고
 * 문자열 그대로 들고 있다(약관·공지 편집 폼과 같은 이유 — 리다이렉트하면 쓰던 글이 사라진다).
 *
 * <p>record 가 아니라 setter 를 가진 JavaBean 인 것은 {@code Map<String, 값>} 바인딩이 setter 방식에서만
 * 확실하기 때문이다.
 */
@Getter
@Setter
public class NoticeTextsForm {

  /** 키는 언어 코드(en, ja, zh, es). */
  private Map<String, Text> translations = new LinkedHashMap<>();

  /** 한 언어의 세 칸. 보내지 않은 칸은 빈 문자열이다. */
  @Getter
  @Setter
  public static class Text {

    private String title = "";
    private String body = "";
    private String buttonLabel = "";
  }

  /** 템플릿이 칸을 채울 때 쓴다. 없는 언어는 빈 칸이다. */
  public Text textOf(String code) {
    Text text = translations.get(code);
    return text == null ? new Text() : text;
  }

  /** 제목과 본문이 둘 다 있으면 채워진 언어다. 탭의 ✓/− 가 이 기준이다(서비스의 "미완성" 기준과 같다). */
  public boolean filled(String code) {
    Text text = translations.get(code);
    return text != null && !isBlank(text.getTitle()) && !isBlank(text.getBody());
  }

  /** 서비스 입력으로 옮긴다. 비운 언어도 그대로 넘긴다 — 서비스가 그 언어 행을 지운다. */
  public Map<String, NoticeTextInput> toInputs() {
    Map<String, NoticeTextInput> inputs = new LinkedHashMap<>();
    translations.forEach((code, text) -> {
      if (text != null) {
        inputs.put(code, new NoticeTextInput(text.getTitle(), text.getBody(), text.getButtonLabel()));
      }
    });
    return inputs;
  }

  /** 저장된 공지의 한국어를 뺀 번역으로 칸을 채운다. */
  public static NoticeTextsForm of(AppNotice notice) {
    NoticeTextsForm form = new NoticeTextsForm();
    notice.getTranslations().stream()
      .filter(text -> !AppLocale.KO.code().equals(text.getLocale()))
      .forEach(text -> {
        Text copy = new Text();
        copy.setTitle(nullToEmpty(text.getTitle()));
        copy.setBody(nullToEmpty(text.getBody()));
        copy.setButtonLabel(nullToEmpty(text.getButtonLabel()));
        form.translations.put(text.getLocale(), copy);
      });
    return form;
  }

  private static boolean isBlank(String value) {
    return value == null || value.isBlank();
  }

  private static String nullToEmpty(String value) {
    return value == null ? "" : value;
  }
}
```

`NoticeEditForm.java` — 55~83행의 `isEnabled`… 사이에 두 메서드를 더한다.

```java
  /** 한국어 제목과 본문이 다 있는가. 편집 화면 언어 탭의 ✓/− 가 쓴다. */
  public boolean koFilled() {
    return title != null && !title.isBlank() && body != null && !body.isBlank();
  }
```
그리고 `toInput()` 아래에 한 메서드를 더한다.

```java
  /** 다른 언어 칸까지 담은 서비스 입력. */
  public NoticeInput toInput(NoticeTextsForm texts) {
    return new NoticeInput(title, body, buttonLabel, buttonUrl, platform, priority, startsAt, endsAt,
      isEnabled(), texts == null ? Map.of() : texts.toInputs(), targetCountries);
  }
```
import 에 `java.util.Map` 을 더한다.

대상 국가(스펙 4.3.1)를 폼 값으로 더한다. 문자열 그대로 담아 검증에 걸려 다시 그릴 때 쓰던 값이 남게 한다(약관·공지 편집 폼과 같은 이유). **생성자를 하나 더 만들지 않는다** — 스프링 폼 바인딩은 record 생성자가 하나일 때만 믿을 수 있어(컨트롤러를 직접 부르는 단위 시험은 이것을 못 잡는다), 컴포넌트를 더하고 호출부(`blank`·`of`·시험 세 곳)를 고친다.

```java
public record NoticeEditForm(
  // … 기존 컴포넌트 그대로 …
  Boolean removeImage,
  // 쉼표로 구분한 대상 국가(KR,JP). 비우면 전체 국가. 형식은 NoticeService 가 검사한다.
  String targetCountries
) {

  /** 칸이 오지 않으면 null 이 묶인다. 빈 값은 전체 국가라 같은 뜻이다. */
  public NoticeEditForm {
    targetCountries = targetCountries == null ? "" : targetCountries;
  }
  // …
}
```

`blank` 의 마지막 인자에 `""` 를 더하고(`false, false, false, ""`), `of` 는 `false,\n      false,\n      nullToEmpty(notice.getTargetCountries())` 로 끝낸다. 인자 없는 `toInput()` 은 `return toInput(null);` 로 바꿔 대상 국가가 빠지지 않게 한다.

- [ ] **Step 4: 폼 시험 통과를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.admin.application.dto.request.NoticeTextsFormTest'`
Expected: PASS (5건). 첫 시험(`bindsIndexedNames`)이 통과해야 Step 6 의 템플릿 이름이 실제로 묶인다는 근거가 된다.

- [ ] **Step 5: 컨트롤러·템플릿 시험을 쓴다**

`AdminNoticeControllerTest.java` — 호출 여섯 곳에 `new NoticeTextsForm()` 인자를 더한다(`create` 는 `form` 바로 뒤, `update` 는 `form` 바로 뒤).

| 줄 | 이전 | 이후 |
| --- | --- | --- |
| 80 | `controller.create(form, null, admin, model, response, redirect)` | `controller.create(form, new NoticeTextsForm(), null, admin, model, response, redirect)` |
| 95 | `controller.create(form("공지"), big, admin, …)` | `controller.create(form("공지"), new NoticeTextsForm(), big, admin, …)` |
| 107 | `controller.create(form("공지"), null, admin, …)` | `controller.create(form("공지"), new NoticeTextsForm(), null, admin, …)` |
| 118 | `controller.create(form("**하루 3개**까지"), null, admin, …)` | `controller.create(form("**하루 3개**까지"), new NoticeTextsForm(), null, admin, …)` |
| 134 | `controller.update("n1", form, null, admin, …)` | `controller.update("n1", form, new NoticeTextsForm(), null, admin, …)` |
| 151 | `controller.update("n1", form, null, admin, …)` | `controller.update("n1", form, new NoticeTextsForm(), null, admin, …)` |

`NoticeEditForm` 생성자 호출 세 곳에 마지막 인자 `""`(대상 국가)를 더한다 — `AdminNoticeControllerTest.java:59`(`form(String)` 도우미)·`:148`, `AdminNoticeTemplateTest.java:97`(`renderEdit`).

import 에 `com.chuseok22.elumserver.admin.application.dto.request.NoticeTextsForm`, `com.chuseok22.elumserver.common.infrastructure.exception.CustomException`, `com.chuseok22.elumserver.common.locale.AppLocale`, `com.chuseok22.elumserver.notice.core.NoticeLocaleException`, `org.mockito.ArgumentCaptor` 를 더하고(이미 있으면 건너뛴다), 클래스 끝(마지막 `}` 앞)에 시험 일곱 개를 더한다.

```java
  @Test
  @DisplayName("다른 언어 칸이 서비스 입력의 translations 로 넘어간다 — 한국어는 최상위 필드 그대로")
  void create_passesTranslations() {
    NoticeTextsForm texts = new NoticeTextsForm();
    NoticeTextsForm.Text en = new NoticeTextsForm.Text();
    en.setTitle("Hello");
    en.setBody("Body");
    texts.getTranslations().put("en", en);
    when(noticeService.create(any(NoticeInput.class), any(), any())).thenReturn(stored("n1"));

    controller.create(form("공지"), texts, null, admin, model, response, redirect);

    ArgumentCaptor<NoticeInput> captor = ArgumentCaptor.forClass(NoticeInput.class);
    verify(noticeService).create(captor.capture(), any(), eq("kimchi"));
    assertThat(captor.getValue().title()).isEqualTo("공지");
    assertThat(captor.getValue().translations()).containsOnlyKeys("en");
    assertThat(captor.getValue().translations().get("en").title()).isEqualTo("Hello");
  }

  @Test
  @DisplayName("다른 언어 칸이 걸리면 어느 언어인지 알리고, 쓰던 칸을 그대로 다시 그린다")
  void create_localeRejected_namesTheLanguage() {
    NoticeTextsForm texts = new NoticeTextsForm();
    when(noticeService.create(any(NoticeInput.class), any(), any()))
      .thenThrow(new NoticeLocaleException(ErrorCode.NOTICE_TITLE_TOO_LONG, AppLocale.ES));

    String view = controller.create(form("공지"), texts, null, admin, model, response, redirect);

    assertThat(view).isEqualTo("admin/notice-edit");
    assertThat(response.getStatus()).isEqualTo(400);
    assertThat((String) model.get("errorMessage")).contains("E-NTC-002").contains("스페인어");
    assertThat(model.get("texts")).isSameAs(texts);
  }

  @Test
  @DisplayName("미완성 번역은 E-NTC-016 으로 안내한다")
  void create_incompleteTranslation_code() {
    when(noticeService.create(any(NoticeInput.class), any(), any()))
      .thenThrow(new NoticeLocaleException(ErrorCode.NOTICE_TRANSLATION_INCOMPLETE, AppLocale.EN));

    controller.create(form("공지"), new NoticeTextsForm(), null, admin, model, response, redirect);

    assertThat((String) model.get("errorMessage")).contains("E-NTC-016").contains("영어");
  }

  @Test
  @DisplayName("미리보기 자료에 언어별 글이 실린다 — 화면이 고른 언어로 그린다")
  void list_previewJsonCarriesTexts() {
    AppNotice live = stored("n9");
    live.putTranslation(AppLocale.EN, "Hello", "Body", null);
    when(noticeService.liveInSlideOrder()).thenReturn(List.of(live));

    controller.list(model);

    String json = (String) model.get("previewJson");
    assertThat(json).contains("\"texts\"").contains("\"en\"").contains("Hello").contains("\"ko\"");
    // 옛 필드(한국어)도 그대로 남아 있다.
    assertThat(json).contains("\"title\":\"**하루 3개**까지\"");
    assertThat(model.get("locales")).isNotNull();
  }

  @Test
  @DisplayName("대상 국가 칸이 서비스 입력으로 그대로 넘어간다 — 다듬기는 서비스가 한다")
  void create_passesTargetCountries() {
    NoticeEditForm withTargets = new NoticeEditForm("공지", "본문", "", "", "ALL", "0", "2026-09-23T09:00", "",
      true, false, false, "KR, JP");
    when(noticeService.create(any(NoticeInput.class), any(), any())).thenReturn(stored("n1"));

    controller.create(withTargets, new NoticeTextsForm(), null, admin, model, response, redirect);

    ArgumentCaptor<NoticeInput> captor = ArgumentCaptor.forClass(NoticeInput.class);
    verify(noticeService).create(captor.capture(), any(), eq("kimchi"));
    assertThat(captor.getValue().targetCountries()).isEqualTo("KR, JP");
  }

  @Test
  @DisplayName("형식이 틀린 대상 국가는 E-NTC-018 로 안내하고 쓰던 값을 그대로 다시 그린다")
  void create_invalidTargetCountries_code() {
    NoticeEditForm bad = new NoticeEditForm("공지", "본문", "", "", "ALL", "0", "2026-09-23T09:00", "",
      true, false, false, "kr");
    when(noticeService.create(any(NoticeInput.class), any(), any()))
      .thenThrow(new CustomException(ErrorCode.NOTICE_TARGET_COUNTRIES_INVALID));

    String view = controller.create(bad, new NoticeTextsForm(), null, admin, model, response, redirect);

    assertThat(view).isEqualTo("admin/notice-edit");
    assertThat(response.getStatus()).isEqualTo(400);
    assertThat((String) model.get("errorMessage")).contains("E-NTC-018").contains("두 글자 대문자");
    // 틀린 값이 칸에 그대로 남는다 — 어디를 고칠지 보인다.
    assertThat(model.get("form")).isSameAs(bad);
  }

  @Test
  @DisplayName("대상 국가가 너무 길면 E-NTC-019 로 안내한다")
  void create_targetCountriesTooLong_code() {
    when(noticeService.create(any(NoticeInput.class), any(), any()))
      .thenThrow(new CustomException(ErrorCode.NOTICE_TARGET_COUNTRIES_TOO_LONG));

    controller.create(form("공지"), new NoticeTextsForm(), null, admin, model, response, redirect);

    assertThat((String) model.get("errorMessage")).contains("E-NTC-019").contains("255");
  }
```

`AdminNoticeTemplateTest.java` — import 에 `com.chuseok22.elumserver.admin.application.dto.request.NoticeTextsForm`, `com.chuseok22.elumserver.admin.application.dto.response.AdminLocaleOption`, `com.chuseok22.elumserver.common.locale.AppLocale` 를 더하고 도우미 둘을 고친다.

`renderList`(77~84행)에 한 줄을 더한다.
```java
    context.setVariable("locales", AdminLocaleOption.all());
```
`renderEdit`(86~98행)의 `variables.put("notice", notice);` 아래에 두 줄을 더한다.
```java
    variables.put("texts", notice == null ? new NoticeTextsForm() : NoticeTextsForm.of(notice));
    variables.put("locales", AdminLocaleOption.all());
```
클래스 끝(마지막 `}` 앞)에 시험을 더한다.

```java
  @Test
  @DisplayName("편집 화면은 다섯 언어 탭과 언어별 칸을 가진다 — 한국어만 필수다")
  void edit_languageTabsAndPanels() {
    String html = renderEdit(notice("n1", "공지", NoticePlatform.ALL), null);

    assertThat(html).contains("data-lang-tab=\"ko\"").contains("data-lang-tab=\"es\"")
      .contains("data-lang-panel=\"ko\"").contains("data-lang-panel=\"en\"")
      .contains("name=\"translations[en].title\"").contains("name=\"translations[ja].body\"")
      .contains("name=\"translations[zh].buttonLabel\"").contains("id=\"notice-title-es\"");
    // 한국어 칸만 required. 다른 언어는 비워도 저장된다.
    assertThat(field(html, "notice-title")).contains("required");
    assertThat(field(html, "notice-title-en")).doesNotContain("required");
    // 한국어 칸 이름·아이디는 그대로다 — 기존 스크립트와 시험이 쓴다.
    assertThat(html).contains("name=\"title\"").contains("name=\"buttonLabel\"");
  }

  @Test
  @DisplayName("탭의 ✓/− 는 제목과 본문이 다 있는 언어에만 ✓ 다")
  void edit_marks() {
    AppNotice notice = notice("n1", "공지", NoticePlatform.ALL);
    notice.putTranslation(AppLocale.EN, "Hello", "Body", null);

    String html = renderEdit(notice, null);

    assertThat(mark(html, "ko")).isEqualTo("✓");
    assertThat(mark(html, "en")).isEqualTo("✓");
    assertThat(mark(html, "ja")).isEqualTo("−");
    // 채운 영어 글이 칸에 들어 있다.
    assertThat(html).contains("value=\"Hello\"");
  }

  @Test
  @DisplayName("미리보기 옆에 언어 표시와 글꼴·고정 문구 안내가 있다 — 미리보기가 글자 모양까지 같지 않다는 말")
  void edit_previewNotes() {
    String html = renderEdit(null, null);

    assertThat(html).contains("data-preview-lang-label").contains("data-preview-fixed-note")
      .contains("data-preview-font-note").contains("글자 모양과 줄이 나뉘는 자리가 앱과 다를 수 있어요")
      // 미리보기는 국가와 무관하다 — 대상 국가를 정한 공지도 그대로 보이므로 그렇다고 알린다.
      .contains("data-preview-country-note").contains("대상 국가와 상관없이");
  }

  @Test
  @DisplayName("목록은 공지마다 언어별 채움 상태를 ✓/− 로 보인다")
  void list_languageMarks() {
    AppNotice notice = notice("n1", "공지", NoticePlatform.ALL);
    notice.putTranslation(AppLocale.EN, "Hello", "Body", null);

    String html = renderList(List.of(new AdminNoticeRow(notice, NoticeStatus.LIVE, true)));

    assertThat(html).contains("ko ✓").contains("en ✓").contains("ja −").contains("zh −").contains("es −");
    assertThat(html).contains("data-preview-lang=\"ja\"").contains("data-preview-font-note");
  }

  @Test
  @DisplayName("편집 화면에 대상 국가 칸이 있다 — 필수가 아니고, 저장된 값이 칸에 들어 있고, 비우면 전체 국가라고 알린다")
  void edit_targetCountriesField() {
    AppNotice notice = notice("n1", "공지", NoticePlatform.ALL);
    notice.setTargetCountries("KR,JP");

    String html = renderEdit(notice, null);

    assertThat(field(html, "notice-target-countries")).contains("name=\"targetCountries\"")
      .contains("value=\"KR,JP\"").doesNotContain("required");
    assertThat(html).contains("비우면 모든 국가");
    // 대상 국가가 없는 새 공지는 빈 칸이다.
    assertThat(field(renderEdit(null, null), "notice-target-countries")).contains("value=\"\"");
  }

  @Test
  @DisplayName("목록에 대상 국가 열이 있다 — 비면 전체 국가, 있으면 코드마다 배지, 켜기 확인 창이 쓸 값도 실린다")
  void list_targetCountriesColumn() {
    AppNotice all = notice("n1", "전체 공지", NoticePlatform.ALL);
    AppNotice targeted = notice("n2", "일본 공지", NoticePlatform.ALL);
    targeted.setTargetCountries("KR,JP");

    String html = renderList(List.of(
      new AdminNoticeRow(all, NoticeStatus.LIVE, true), new AdminNoticeRow(targeted, NoticeStatus.LIVE, true)));

    assertThat(html).contains("<th>대상 국가</th>").contains("전체 국가")
      .contains(">KR</span>").contains(">JP</span>").contains("data-target-countries=\"KR,JP\"");
    // 공지마다 한 칸이다.
    assertThat(html.split("data-target-countries-cell", -1)).hasSize(3);
  }

  /** 아이디가 [id] 인 입력 칸의 여는 태그. */
  private String field(String html, String id) {
    Matcher matcher = Pattern.compile("<(?:input|textarea)[^>]*id=\"" + Pattern.quote(id) + "\"[^>]*>").matcher(html);
    assertThat(matcher.find()).as(id + " 칸").isTrue();
    return matcher.group();
  }

  /** 언어 탭의 ✓/− 글자. */
  private String mark(String html, String code) {
    Matcher matcher = Pattern.compile("<span[^>]*data-lang-mark=\"" + code + "\"[^>]*>([^<]*)</span>").matcher(html);
    assertThat(matcher.find()).as(code + " 표시").isTrue();
    return matcher.group(1).strip();
  }
```
그리고 `renderedTagsBalanced` 의 `@ValueSource` 는 그대로 둔다(세 화면 모두 새 변수를 받는다).

- [ ] **Step 6: 실행해 실패를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.admin.application.controller.AdminNoticeControllerTest' --tests 'com.chuseok22.elumserver.admin.application.controller.AdminNoticeTemplateTest'`
Expected: FAIL — 컴파일 오류(`create` 시그니처).

- [ ] **Step 7: 컨트롤러를 고친다**

`AdminNoticeController.java`:

1. import 에 추가: `com.chuseok22.elumserver.admin.application.dto.request.NoticeTextsForm`, `com.chuseok22.elumserver.admin.application.dto.response.AdminLocaleOption`, `com.chuseok22.elumserver.notice.core.NoticeLocaleException`, `com.chuseok22.elumserver.notice.infrastructure.entity.AppNoticeTranslation`.

2. 66~129행(`newForm`·`edit`·`create`·`update`)을 바꾼다.

```java
  @GetMapping("/admin/notices/new")
  public String newForm(Model model) {
    model.addAttribute("form", NoticeEditForm.blank(noticeService.now()));
    model.addAttribute("texts", new NoticeTextsForm());
    model.addAttribute("notice", null);
    addPreview(model, null);
    return EDIT_VIEW;
  }

  @GetMapping("/admin/notices/{id}")
  public String edit(@PathVariable("id") String id, Model model) {
    AppNotice notice = noticeService.get(id);
    model.addAttribute("form", NoticeEditForm.of(notice));
    model.addAttribute("texts", NoticeTextsForm.of(notice));
    addNotice(model, notice);
    addPreview(model, id);
    return EDIT_VIEW;
  }

  /**
   * 새로 만든다. <b>검증에 걸리면 리다이렉트하지 않고 입력값 그대로 다시 그린다</b> — 리다이렉트하면
   * 쓰던 본문이 사라진다. 고른 이미지 파일만은 브라우저가 비우므로 다시 골라 달라고 말한다.
   *
   * <p>한국어는 {@code form}, 나머지 언어는 {@code texts} 로 들어온다 (이슈 #521).
   */
  @PostMapping("/admin/notices")
  public String create(
    @ModelAttribute("form") NoticeEditForm form,
    @ModelAttribute("texts") NoticeTextsForm texts,
    @RequestParam(value = "image", required = false) MultipartFile image,
    Principal principal,
    Model model,
    HttpServletResponse response,
    RedirectAttributes redirectAttributes
  ) {
    try {
      AppNotice saved = noticeService.create(form.toInput(texts), image, name(principal));
      redirectAttributes.addFlashAttribute("message", "'" + plainTitle(saved) + "' 공지를 만들었어요."
        + (saved.isEnabled() ? "" : " 꺼 둔 채라 앱에는 아직 나가지 않아요."));
      return LIST;
    } catch (CustomException e) {
      model.addAttribute("form", form);
      model.addAttribute("texts", texts);
      model.addAttribute("notice", null);
      return rejected(e, image, model, response, null);
    }
  }

  @PostMapping("/admin/notices/{id}")
  public String update(
    @PathVariable("id") String id,
    @ModelAttribute("form") NoticeEditForm form,
    @ModelAttribute("texts") NoticeTextsForm texts,
    @RequestParam(value = "image", required = false) MultipartFile image,
    Principal principal,
    Model model,
    HttpServletResponse response,
    RedirectAttributes redirectAttributes
  ) {
    try {
      AppNotice saved = noticeService.update(id, form.toInput(texts), form.isBumpRevision(), image,
        form.isRemoveImage(), name(principal));
      redirectAttributes.addFlashAttribute("message", "'" + plainTitle(saved) + "' 공지를 저장했어요."
        + (form.isBumpRevision() ? " 숨긴 보호자에게도 다시 보여요." : ""));
      return LIST;
    } catch (CustomException e) {
      model.addAttribute("form", form);
      model.addAttribute("texts", texts);
      addNotice(model, noticeService.get(id));
      return rejected(e, image, model, response, id);
    }
  }
```

3. `rejected`(172~184행)의 `errorMessage` 줄을 바꾼다.

```java
    boolean imageChosen = image != null && !image.isEmpty();
    // 칸이 언어 탭 뒤에 있다. 어느 언어 칸인지 알려 주면 그 탭을 바로 열 수 있다.
    String where = e instanceof NoticeLocaleException localeError
      ? " (" + AdminLocaleOption.labelOf(localeError.getLocale()) + " 칸)" : "";
    model.addAttribute("errorMessage", failureReason(e) + where
      + (imageChosen ? " 고른 이미지는 저장하지 않았어요. 파일을 다시 골라 주세요." : ""));
```

4. `addPreview`(191~205행) 안, `model.addAttribute("hideDays", hideDays);` 위에 한 줄을 더한다.

```java
    // 언어 탭·목록의 언어 열이 쓴다. 모든 공지 화면이 이 메서드를 지나므로 한 곳에서 단다.
    model.addAttribute("locales", AdminLocaleOption.all());
```

5. `previewSlide`(207~219행)에 언어별 글을 더한다. `slide.put("buttonLabel", …)` 아래에 이어 쓴다.

```java
    // 언어별 글. 화면이 고른 언어로 앱과 같은 대체 순서(요청 → en → ko)를 적용해 그린다.
    Map<String, Map<String, String>> texts = new LinkedHashMap<>();
    for (AppNoticeTranslation text : notice.getTranslations()) {
      Map<String, String> one = new LinkedHashMap<>();
      one.put("title", text.getTitle());
      one.put("body", text.getBody());
      one.put("buttonLabel", text.getButtonLabel());
      texts.put(text.getLocale(), one);
    }
    slide.put("texts", texts);
```

6. `failureReason`(232~253행)의 `NOTICE_NOT_FOUND` 줄 아래에 네 줄(`case` 넷)을 더한다.

```java
      case NOTICE_TRANSLATION_INCOMPLETE ->
        "다른 언어는 제목과 본문을 함께 적거나 세 칸을 모두 비워 주세요. 비우면 그 언어는 영어 → 한국어 순으로 대신 보여요. (E-NTC-016)";
      case NOTICE_LOCALE_INVALID -> "알 수 없는 언어 칸이에요. 화면을 새로 열어 다시 시도해 주세요. (E-NTC-017)";
      case NOTICE_TARGET_COUNTRIES_INVALID ->
        "대상 국가는 KR,JP 처럼 두 글자 대문자 코드를 쉼표로 적어 주세요. 소문자나 세 글자 코드는 받지 않아요. 비우면 전체 국가예요. (E-NTC-018)";
      case NOTICE_TARGET_COUNTRIES_TOO_LONG ->
        "대상 국가는 " + AppNotice.TARGET_COUNTRIES_MAX_LENGTH + "자까지예요. (E-NTC-019)";
```

- [ ] **Step 8: 템플릿을 고친다**

`notices.html`:

1. 19~28행(`<thead>`)에 언어 열과 대상 국가 열을 더한다 — `<th>제목</th>` 다음 줄에 `<th>언어</th>`, `<th>대상 · 순서</th>` 다음 줄에 `<th>대상 국가</th>` 를 더한다.
2. 33행의 빈 줄 안내를 `emptyRow(8, …)` 로 바꾼다(열이 여덟 개가 됐다).
3. 49행(`</td>` — 제목 칸 끝) 다음에 언어 칸을 더한다.

```html
            <!-- 언어별 채움 상태. 한국어는 필수라 늘 ✓ 여야 하고, 나머지는 적은 언어만 ✓ 다. 비운 언어는 영어 → 한국어로 대신 나간다. -->
            <td class="text-xs whitespace-nowrap">
              <span th:each="opt : ${locales}" class="mr-1 font-mono"
                    th:classappend="${n.hasTranslation(opt.code)} ? 'text-success' : 'text-base-content/40'"
                    th:title="${opt.label}"
                    th:text="${opt.code} + (${n.hasTranslation(opt.code)} ? ' ✓' : ' −')">ko ✓</span>
            </td>
```
4. 103~114행(`<aside>` 전체)을 바꾼다.

```html
    <aside class="card bg-base-200 np-aside">
      <div class="card-body space-y-3">
        <h2 class="card-title text-base">전체 미리보기</h2>
        <p class="text-xs text-base-content/60">지금 게시 중인 공지를 앱에 뜨는 순서대로 하나씩 봐요.</p>
        <div class="flex gap-1" role="group" aria-label="미리볼 플랫폼">
          <button type="button" class="btn btn-xs btn-primary" data-preview-platform="IOS">iOS</button>
          <button type="button" class="btn btn-xs btn-ghost" data-preview-platform="ANDROID">Android</button>
        </div>
        <!-- 그 언어 휴대폰에서 어떻게 보이는지. 그 언어 글이 없는 공지는 앱과 같게 영어 → 한국어로 대신 보여준다. -->
        <div class="flex flex-wrap gap-1" role="group" aria-label="미리볼 언어">
          <button th:each="opt : ${locales}" type="button" class="btn btn-xs"
                  th:classappend="${opt.code == 'ko'} ? 'btn-primary' : 'btn-ghost'"
                  th:data-preview-lang="${opt.code}" th:text="${opt.label}">한국어</button>
        </div>
        <div id="notice-preview-list" data-notice-preview-list></div>
        <p class="text-xs text-base-content/60" data-preview-note></p>
        <p class="text-xs text-base-content/60" data-preview-fixed-note hidden>
          '보지 않기'·'닫기' 같은 앱 고정 문구는 앱에서 휴대폰 언어로 나와요. 미리보기는 한국어로 보여요.
        </p>
        <!-- 미리보기는 대상 국가를 거르지 않는다. 앱 팝업의 모양을 보는 도구라 국가와 무관하다. -->
        <p class="text-xs text-base-content/60" data-preview-country-note>
          대상 국가와 상관없이 게시 중인 공지를 모두 보여줘요. 실제로는 대상 국가로 정한 나라의 휴대폰에만 나가요.
        </p>
        <p class="text-xs text-warning" data-preview-font-note hidden>
          미리보기 글꼴은 한글·라틴 글자만 담고 있어 일본어·중국어는 시스템 글꼴로 보여요.
          글자 모양과 줄이 나뉘는 자리가 앱과 다를 수 있어요.
        </p>
      </div>
    </aside>
```

5. 대상 국가 칸. 플랫폼·우선순위 칸(`<td class="text-xs">`) 바로 다음에 더한다. 비면 "전체 국가"라고 적어 빈 칸이 누락으로 보이지 않게 한다.

```html
            <!-- 대상 국가. 비면 전체 국가다. 지역을 알 수 없는 휴대폰에는 대상을 정한 공지가 나가지 않는다 (스펙 4.3.1). -->
            <td class="text-xs" data-target-countries-cell>
              <span th:if="${n.targetCountryList().isEmpty()}" class="text-base-content/60">전체 국가</span>
              <span th:each="code : ${n.targetCountryList()}" class="badge badge-sm badge-outline mr-1 font-mono"
                    th:text="${code}">KR</span>
            </td>
```
6. 켜기 확인 창이 "누구에게 나가는지"를 대상 국가까지 말하도록 켜기 폼에 값을 싣는다. `th:data-platform="${n.platform.name()}"` 바로 뒤에 한 속성을 더한다(없으면 속성이 빠져 전체 국가로 읽힌다).

```html
                      th:data-platform="${n.platform.name()}" th:data-target-countries="${n.targetCountries}"
                      th:data-title="${n.title}">
```

`notice-edit.html`:

1. 27~108행(첫 번째 `card`)을 아래로 바꾼다.

```html
      <div class="card bg-base-100 shadow-md">
        <div class="card-body space-y-4">
          <h2 class="card-title text-base">무엇을 알릴까요</h2>

          <!-- 언어 탭. 한국어는 꼭 적고 나머지는 선택이다. 탭을 누르면 미리보기도 그 언어로 바뀐다(notice-preview.js).
               ✓ 는 제목과 본문이 다 있다는 뜻이다. 비운 언어는 앱에서 영어 → 한국어 순으로 대신 나간다. -->
          <div class="space-y-1">
            <div role="tablist" class="tabs tabs-boxed w-fit max-w-full flex-wrap" aria-label="공지 언어">
              <button th:each="opt : ${locales}" type="button" role="tab" class="tab gap-1"
                      th:classappend="${opt.code == 'ko'} ? 'tab-active'"
                      th:data-lang-tab="${opt.code}" th:aria-selected="${opt.code == 'ko'}">
                <span th:text="${opt.label}">한국어</span>
                <span class="font-mono text-xs" th:data-lang-mark="${opt.code}"
                      th:text="${opt.code == 'ko' ? form.koFilled() : texts.filled(opt.code)} ? '✓' : '−'">✓</span>
              </button>
            </div>
            <p class="text-xs text-base-content/60">
              한국어는 꼭 적어요. 나머지는 적은 언어만 그 언어 휴대폰에 나가요. 이미지와 링크는 모든 언어가 같아요.
              (이미지에 글자가 들어 있으면 언어별로 다르게 낼 수 없어요)
            </p>
          </div>

          <!-- 한국어 -->
          <div data-lang-panel="ko" class="space-y-4">
            <label class="form-control">
              <div class="label">
                <span class="label-text">제목 <span class="text-error">*</span></span>
                <span class="label-text-alt font-mono" data-count-for="notice-title">0/40</span>
              </div>
              <input id="notice-title" type="text" name="title" class="input input-bordered" maxlength="40"
                     th:value="${form.title}" required/>
              <div class="label">
                <span class="label-text-alt">
                  강조할 글자를 <code class="font-mono">**이렇게**</code> 감싸면 앱에서 브랜드 색으로 보여요. ** 표기도 글자 수에 들어가요
                </span>
              </div>
            </label>

            <label class="form-control">
              <div class="label">
                <span class="label-text">본문 <span class="text-error">*</span></span>
                <span class="label-text-alt font-mono" data-count-for="notice-body">0/1000</span>
              </div>
              <textarea id="notice-body" name="body" class="textarea textarea-bordered h-40 text-sm leading-relaxed"
                        maxlength="1000" th:text="${form.body}" required></textarea>
              <div class="label">
                <span class="label-text-alt">줄바꿈은 그대로 보여요. 길면 앱에서 본문만 스크롤돼요</span>
              </div>
            </label>

            <label class="form-control">
              <div class="label">
                <span class="label-text">버튼 문구 (선택)</span>
                <span class="label-text-alt font-mono" data-count-for="notice-button-label">0/20</span>
              </div>
              <input id="notice-button-label" type="text" name="buttonLabel" class="input input-bordered" maxlength="20"
                     th:value="${form.buttonLabel}" placeholder="자세히 보기"/>
            </label>

            <!-- 문구 도움 (N20). 경고만 하고 저장은 막지 않는다 — 법적 문구가 필요할 때가 있다. 한국어 규칙이다. -->
            <div class="rounded-box bg-base-200 p-3 text-sm space-y-1">
              <p class="text-base-content/80">
                해요체로 써요. <span class="text-base-content/60">예: 저장되었습니다 → 저장했어요 · 사라집니다 → 이어서 만들 수 있어요</span>
              </p>
              <ul id="notice-wording" class="list-disc space-y-1 pl-5" aria-live="polite"></ul>
            </div>
          </div>

          <!-- 한국어 이외 언어. 비워 두면 그 언어는 없는 것이다. 칸 이름은 translations[언어].칸 이다. -->
          <div th:each="opt : ${locales}" th:if="${opt.code != 'ko'}" th:data-lang-panel="${opt.code}"
               class="space-y-4" hidden>
            <label class="form-control">
              <div class="label">
                <span class="label-text" th:text="${opt.label} + ' 제목'">영어 제목</span>
                <span class="label-text-alt font-mono" th:data-count-for="|notice-title-${opt.code}|">0/40</span>
              </div>
              <input th:id="|notice-title-${opt.code}|" type="text" th:name="|translations[${opt.code}].title|"
                     class="input input-bordered" maxlength="40" th:value="${texts.textOf(opt.code).title}"/>
            </label>

            <label class="form-control">
              <div class="label">
                <span class="label-text" th:text="${opt.label} + ' 본문'">영어 본문</span>
                <span class="label-text-alt font-mono" th:data-count-for="|notice-body-${opt.code}|">0/1000</span>
              </div>
              <textarea th:id="|notice-body-${opt.code}|" th:name="|translations[${opt.code}].body|"
                        class="textarea textarea-bordered h-40 text-sm leading-relaxed" maxlength="1000"
                        th:text="${texts.textOf(opt.code).body}"></textarea>
            </label>

            <label class="form-control">
              <div class="label">
                <span class="label-text" th:text="${opt.label} + ' 버튼 문구 (선택)'">영어 버튼 문구</span>
                <span class="label-text-alt font-mono" th:data-count-for="|notice-button-label-${opt.code}|">0/20</span>
              </div>
              <input th:id="|notice-button-label-${opt.code}|" type="text"
                     th:name="|translations[${opt.code}].buttonLabel|" class="input input-bordered" maxlength="20"
                     th:value="${texts.textOf(opt.code).buttonLabel}"/>
              <div class="label">
                <span class="label-text-alt">링크는 아래에서 한 번만 적어요. 문구를 비우면 이 언어에는 버튼이 없어요</span>
              </div>
            </label>

            <p class="text-xs text-base-content/60">
              제목과 본문을 함께 적거나 세 칸을 모두 비워요. 비우면 이 언어 휴대폰에는 영어 → 한국어 순으로 대신 나가요.
              용어는 용어집(<code class="font-mono">docs/i18n/glossary.md</code>)을 따라요.
            </p>
          </div>

          <div class="divider my-0"></div>

          <div class="space-y-2">
            <div class="label-text">이미지 (선택)</div>
            <th:block th:if="${notice != null and notice.imageKey != null}">
              <div class="flex items-center gap-3">
                <img th:src="@{/admin/notices/{id}/image(id=${notice.id})}" alt="지금 올라가 있는 이미지"
                     class="rounded-box border border-base-300" style="height:64px"/>
                <label class="label cursor-pointer justify-start gap-2">
                  <input id="notice-remove-image" type="checkbox" name="removeImage" value="true" class="checkbox checkbox-sm"
                         th:checked="${form.isRemoveImage()}"/>
                  <span class="label-text">이미지 지우기</span>
                </label>
              </div>
            </th:block>
            <input id="notice-image" type="file" name="image" accept="image/png,image/jpeg,image/webp"
                   class="block w-full text-sm"/>
            <p class="text-xs text-base-content/60">
              권장 16:10 (1280×800). png, jpg, webp · 2MB 까지. 비율이 다르면 가장자리가 잘려 보여요.
              새로 고르면 지금 이미지를 바꿔요. 모든 언어가 같은 이미지를 써요.
            </p>
            <p id="notice-image-note" class="text-xs font-semibold" aria-live="polite"></p>
          </div>

          <div class="divider my-0"></div>

          <div class="grid gap-4 md:grid-cols-2">
            <label class="form-control">
              <div class="label"><span class="label-text">버튼 링크 (선택) · 모든 언어 공통</span></div>
              <input id="notice-button-url" type="text" name="buttonUrl" class="input input-bordered font-mono text-sm"
                     maxlength="500" th:value="${form.buttonUrl}" placeholder="https://"/>
            </label>
          </div>
          <p class="text-xs text-base-content/60">
            한국어는 문구와 링크를 함께 적거나 둘 다 비워요. 다른 언어는 문구를 적은 언어에만 버튼이 생겨요.
            링크는 https:// 만 받아요. 누르면 휴대폰 브라우저가 열려요.
          </p>
        </div>
      </div>
```

2. 177~193행(`<aside>` 전체)을 바꾼다.

```html
    <aside class="card bg-base-200 np-aside">
      <div class="card-body space-y-3">
        <h2 class="card-title text-base">미리보기</h2>
        <p class="text-xs text-base-content/60">입력하는 대로 바뀌어요. 앱 팝업과 같은 치수·글꼴·줄바꿈이에요.</p>
        <p class="text-xs text-base-content/60">
          미리보기 언어: <b data-preview-lang-label>한국어</b> (위의 언어 탭을 누르면 바뀌어요)
        </p>
        <div class="flex flex-wrap gap-1" role="group" aria-label="미리보기 범위">
          <button type="button" class="btn btn-xs btn-primary" data-preview-mode="single">이 공지만</button>
          <button type="button" class="btn btn-xs btn-ghost" data-preview-mode="all">게시 중인 공지와 함께</button>
        </div>
        <div class="flex gap-1" role="group" aria-label="미리볼 플랫폼">
          <button type="button" class="btn btn-xs btn-primary" data-preview-platform="IOS">iOS</button>
          <button type="button" class="btn btn-xs btn-ghost" data-preview-platform="ANDROID">Android</button>
        </div>
        <div id="notice-preview"
             th:data-existing-image="${notice != null and notice.imageKey != null} ? @{/admin/notices/{id}/image(id=${notice.id})} : ''"></div>
        <p class="text-xs text-base-content/60" data-preview-note></p>
        <p class="text-xs text-base-content/60" data-preview-fixed-note hidden>
          '보지 않기'·'닫기' 같은 앱 고정 문구는 앱에서 휴대폰 언어로 나와요. 미리보기는 한국어로 보여요.
        </p>
        <!-- 미리보기는 대상 국가를 거르지 않는다. 앱 팝업의 모양을 보는 도구라 국가와 무관하다. -->
        <p class="text-xs text-base-content/60" data-preview-country-note>
          대상 국가와 상관없이 게시 중인 공지를 모두 보여줘요. 실제로는 대상 국가로 정한 나라의 휴대폰에만 나가요.
        </p>
        <p class="text-xs text-warning" data-preview-font-note hidden>
          미리보기 글꼴은 한글·라틴 글자만 담고 있어 일본어·중국어는 시스템 글꼴로 보여요.
          글자 모양과 줄이 나뉘는 자리가 앱과 다를 수 있어요.
        </p>
      </div>
    </aside>
```

3. 대상 국가 칸. "언제, 누구에게" 카드(`<h2 class="card-title text-base">언제, 누구에게</h2>`)의 `grid` 안, 우선순위 `</label>` 바로 다음에 더한다. 비우면 전체 국가이고 필수가 아니다. 형식 검사는 서버가 한다(틀리면 쓰던 값 그대로 다시 그리고 `E-NTC-018`).

```html
            <label class="form-control md:col-span-2">
              <div class="label"><span class="label-text">대상 국가 (선택)</span></div>
              <input id="notice-target-countries" type="text" name="targetCountries"
                     class="input input-bordered font-mono" maxlength="255" autocomplete="off" spellcheck="false"
                     th:value="${form.targetCountries}" placeholder="비우면 전체 국가 (예: KR,JP)"/>
              <div class="label">
                <span class="label-text-alt">
                  두 글자 대문자 국가 코드를 쉼표로 적어요(KR,JP). 비우면 모든 국가의 휴대폰에 나가요.
                  휴대폰의 지역 설정이 기준이고, 지역을 알 수 없는 휴대폰에는 대상 국가를 정한 공지가 나가지 않아요.
                  앱을 업데이트하지 않은 휴대폰은 KR 로 봐요.
                </span>
              </div>
            </label>
```

- [ ] **Step 9: 통과를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.admin.*'`
Expected: PASS — `NoticeTextsFormTest` 5건, `AdminNoticeControllerTest`(기존 + 신규 7건), `AdminNoticeTemplateTest`(기존 + 신규 6건; `renderedTagsBalanced`·`sourceTagsBalanced` 가 새 마크업의 여닫기를 본다), `AdminTemplateTagBalanceTest`.

- [ ] **Step 10: 커밋 (`/pro-commit`)**

```bash
git add server/src/main/java/com/chuseok22/elumserver/admin/application/dto/request/NoticeTextsForm.java \
  server/src/main/java/com/chuseok22/elumserver/admin/application/dto/request/NoticeEditForm.java \
  server/src/main/java/com/chuseok22/elumserver/admin/application/controller/AdminNoticeController.java \
  server/src/main/resources/templates/admin/notices.html \
  server/src/main/resources/templates/admin/notice-edit.html \
  server/src/test/java/com/chuseok22/elumserver/admin/application/dto/request/NoticeTextsFormTest.java \
  server/src/test/java/com/chuseok22/elumserver/admin/application/controller/AdminNoticeControllerTest.java \
  server/src/test/java/com/chuseok22/elumserver/admin/application/controller/AdminNoticeTemplateTest.java
```

---

## Task 9: 관리자 미리보기 스크립트 — `notice-preview.js` 언어 탭·줄바꿈 규칙·글꼴 안내

**Files:**
- Modify: `server/src/main/resources/static/admin/js/notice-preview.js:71` (상수), `:148-164` (`keepWordsParts`), `:166-179` (언어 도움 함수 추가), `:432-626` (`initListPreview`·`initEditor` 교체), `:656-762` (`audience`·`publishOutcome`·`initPublishNote`·`initEnableConfirm` — 대상 국가 문구), `:803-805` (노출)
- Test: `server/src/test/java/com/chuseok22/elumserver/admin/application/controller/NoticePreviewScriptTest.java` (새)

**Interfaces:**
- Consumes: Task 8 이 만든 템플릿 속성 `data-lang-tab` / `data-lang-panel` / `data-lang-mark` / `data-preview-lang` / `data-preview-lang-label` / `data-preview-fixed-note` / `data-preview-font-note`, 칸 아이디 `notice-title[-언어]` · `notice-body[-언어]` · `notice-button-label[-언어]`, 미리보기 JSON 의 `texts`, 대상 국가 칸 아이디 `notice-target-countries` 와 목록 켜기 폼의 `data-target-countries`
- Produces:
  - 상수 `NO_JOINER_LANGS = ['ja', 'zh']` — **앱 `keep_words.dart` 가 줄바꿈 표시를 넣지 않는 언어와 같은 집합**
  - `window.ElumNoticePreview.keepWordsFor(text, lang): string`, `window.ElumNoticePreview.resolveText(texts, lang): {lang, text}`
  - `publishOutcome(input)` 의 `input.targetCountries`(쉼표 구분 문자열, 없으면 전체) — 저장 안내·확인 창이 "누구에게"를 대상 국가까지 말한다. **미리보기 그리기(`renderPopup`·슬라이드 목록)는 대상 국가와 무관하다** — 앱 팝업의 모양을 보는 도구라서 국가로 거르지 않는다(Task 8 의 `data-preview-country-note` 안내가 그렇게 말한다)

> **같은 규칙이어야 하는 이유.** 이 스크립트 머리 주석이 말하듯 줄바꿈 표시(U+2060) 규칙은 앱과 **같아야** 한다. 앱은 `ja`·`zh` 에서 표시를 넣지 않는다(띄어쓰기가 없어 표시를 넣으면 줄을 바꿀 자리가 사라진다 — 계획 1). 미리보기가 표시를 넣으면 관리자가 본 줄과 보호자가 본 줄이 다시 달라진다.

- [ ] **Step 1: 앱의 규칙을 확인한다**

Run: `grep -n "ja\|zh\|joiner\|NoJoiner\|languageCode" client/lib/core/text/keep_words.dart`
Expected: `ja`·`zh` 에서 표시를 넣지 않는 분기가 보인다. **집합이 `{ja, zh}` 와 다르면**(예: 계획 1 이 `es` 도 뺐다면) 아래 `NO_JOINER_LANGS` 를 그 집합으로 바꾸고 시험의 기대값도 같이 바꾼다. 이 단계의 결과가 이 Task 의 정답이다.

- [ ] **Step 2: 실패하는 시험을 쓴다**

`server/src/test/java/com/chuseok22/elumserver/admin/application/controller/NoticePreviewScriptTest.java`:

```java
package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 관리자 미리보기 스크립트가 앱과 같은 줄바꿈 규칙·언어 대체 순서를 쓰는지 (이슈 #521).
 *
 * <p>글 계약 시험은 항상 돈다. 실제 동작 시험은 {@code node} 가 있을 때만 돈다(없으면 건너뛴다 —
 * CI 이미지에 node 가 없을 수 있다).
 */
class NoticePreviewScriptTest {

  private static final Path SCRIPT = Path.of("src/main/resources/static/admin/js/notice-preview.js");
  private static final String WORD_JOINER = "⁠";

  @Test
  @DisplayName("줄바꿈 표시를 넣지 않는 언어는 ja·zh 다 — 앱 keep_words.dart 와 같은 집합")
  void noJoinerLanguages_matchApp() throws IOException {
    String js = Files.readString(SCRIPT);
    assertThat(js).contains("var NO_JOINER_LANGS = ['ja', 'zh'];");
    // 앱과 같은 규칙이라는 것을 코드 곁에 적어 둔다 — 한쪽만 바꾸면 이 주석이 길을 알려 준다.
    assertThat(js).contains("keep_words.dart");
  }

  @Test
  @DisplayName("미리보기는 언어 탭·언어 버튼·글꼴 안내를 다룬다")
  void script_handlesLanguageControls() throws IOException {
    String js = Files.readString(SCRIPT);
    assertThat(js).contains("data-lang-tab").contains("data-lang-panel").contains("data-lang-mark")
      .contains("data-preview-lang").contains("data-preview-font-note").contains("FONT_LACKING_LANGS")
      // 저장 안내가 대상 국가를 읽는다(편집 칸·목록 켜기 폼).
      .contains("notice-target-countries").contains("data-target-countries");
  }

  @Test
  @DisplayName("ko·en·es 는 붙은 글자 사이에 끊지 말라는 표시를 넣고, ja·zh 는 넣지 않는다")
  void keepWords_perLanguage() throws Exception {
    assumeTrue(nodeAvailable(), "node 가 없어 건너뛴다");

    Map<String, String> out = runNode("""
      global.window = {};
      global.document = { readyState: 'loading', currentScript: null, addEventListener() {}, querySelector() { return null; } };
      require(process.argv[1]);
      const p = window.ElumNoticePreview;
      const result = {};
      for (const lang of ['ko', 'en', 'es', 'ja', 'zh']) result[lang] = p.keepWordsFor('방침에서 ab', lang);
      console.log(JSON.stringify(result));
      """);

    for (String lang : new String[] {"ko", "en", "es"}) {
      assertThat(out.get(lang)).as(lang).contains(WORD_JOINER);
    }
    // 띄어쓰기 옆에는 넣지 않는다 — 거기서 끊는다.
    assertThat(out.get("ko")).isEqualTo("방" + WORD_JOINER + "침" + WORD_JOINER + "에" + WORD_JOINER + "서 a" + WORD_JOINER + "b");
    for (String lang : new String[] {"ja", "zh"}) {
      assertThat(out.get(lang)).as(lang).isEqualTo("방침에서 ab");
    }
  }

  @Test
  @DisplayName("글 고르기는 요청 → en → ko 다 — 제목과 본문이 다 있는 첫 언어")
  void resolveText_requestThenEnThenKo() throws Exception {
    assumeTrue(nodeAvailable(), "node 가 없어 건너뛴다");

    Map<String, String> out = runNode("""
      global.window = {};
      global.document = { readyState: 'loading', currentScript: null, addEventListener() {}, querySelector() { return null; } };
      require(process.argv[1]);
      const p = window.ElumNoticePreview;
      const texts = {
        ko: { title: '제목', body: '본문' },
        en: { title: 'Hello', body: 'Body' },
        ja: { title: 'こんにちは', body: '' },   // 본문이 비어 미완성 — 건너뛴다
        es: { title: 'Hola', body: 'Cuerpo' }
      };
      const result = {};
      for (const lang of ['ko', 'en', 'ja', 'zh', 'es']) result[lang] = p.resolveText(texts, lang).lang;
      console.log(JSON.stringify(result));
      """);

    assertThat(out).containsEntry("ko", "ko").containsEntry("en", "en").containsEntry("es", "es")
      // 일본어는 미완성이라 영어로, 중국어는 글이 없어 영어로 내려간다.
      .containsEntry("ja", "en").containsEntry("zh", "en");
  }

  @Test
  @DisplayName("저장 안내는 대상 국가를 말한다 — 없으면 이전과 같은 '보호자 모두에게', 있으면 그 국가 보호자에게")
  void publishOutcome_namesTargetCountries() throws Exception {
    assumeTrue(nodeAvailable(), "node 가 없어 건너뛴다");

    Map<String, String> out = runNode("""
      global.window = {};
      global.document = { readyState: 'loading', currentScript: null, addEventListener() {}, querySelector() { return null; } };
      require(process.argv[1]);
      const p = window.ElumNoticePreview;
      const base = { enabled: true, startsAt: '2020-01-01T00:00', endsAt: '', platform: 'ALL', bumpRevision: false, wasLive: false };
      const result = {
        all: p.publishOutcome({ ...base, targetCountries: '' }).text,
        none: p.publishOutcome({ ...base }).text,
        some: p.publishOutcome({ ...base, platform: 'IOS', targetCountries: ' KR , JP ,' }).text
      };
      console.log(JSON.stringify(result));
      """);

    assertThat(out.get("all")).contains("보호자 모두에게");
    // 값이 아예 없는 입력(옛 호출부)도 같다.
    assertThat(out.get("none")).isEqualTo(out.get("all"));
    assertThat(out.get("some")).contains("iOS 보호자 중 대상 국가(KR, JP)의 보호자에게");
  }

  private static boolean nodeAvailable() {
    try {
      Process process = new ProcessBuilder("node", "--version").redirectErrorStream(true).start();
      return process.waitFor(10, TimeUnit.SECONDS) && process.exitValue() == 0;
    } catch (IOException | InterruptedException e) {
      return false;
    }
  }

  private static Map<String, String> runNode(String script) throws Exception {
    Process process = new ProcessBuilder("node", "-e", script, SCRIPT.toAbsolutePath().toString())
      .redirectErrorStream(true).start();
    String output = new String(process.getInputStream().readAllBytes());
    assertThat(process.waitFor(30, TimeUnit.SECONDS)).as("node 가 끝나야 한다").isTrue();
    assertThat(process.exitValue()).as("node 출력: " + output).isZero();
    return new ObjectMapper().readValue(output.strip(), new TypeReference<Map<String, String>>() {});
  }
}
```

- [ ] **Step 3: 실행해 실패를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.admin.application.controller.NoticePreviewScriptTest'`
Expected: FAIL — `NO_JOINER_LANGS` 가 없다(글 계약 시험 둘), node 시험은 `keepWordsFor is not a function`.

- [ ] **Step 4: 스크립트 머리·상수를 고친다**

`notice-preview.js` 머리 주석(1~29행) 끝 `하는 일` 목록 앞에 한 문단을 더한다.

```
 * 언어(#521): 공지는 언어마다 글이 있다. 편집 화면은 언어 탭을, 목록은 언어 버튼을 둔다. 고른 언어로 앱이
 * 그 언어 휴대폰에 줄 글을 그린다 — 그 언어 글이 없으면 앱과 같게 영어 → 한국어 순으로 대신 보여준다.
 * 줄바꿈 표시는 일본어·중국어에서 넣지 않는다(앱 keep_words.dart 와 같은 규칙). 글꼴은 한글·라틴만 담아서
 * 일본어·중국어 글자는 시스템 글꼴로 보인다 — 글자 모양과 줄 나뉨 자리가 앱과 다를 수 있다.
```

71행(`var JOINER = '⁠';`) 아래에 상수를 더한다.

```js

  // 끊지 말라는 표시를 넣지 않는 언어. 일본어·중국어는 띄어쓰기가 없어 표시를 넣으면 줄을 바꿀 자리가 사라진다.
  // 앱(client/lib/core/text/keep_words.dart)이 같은 언어에서 표시를 넣지 않는다 — 한쪽만 바꾸면
  // 미리보기와 앱의 줄이 다시 달라진다. 집합을 바꾸려면 두 곳을 함께 바꾼다.
  var NO_JOINER_LANGS = ['ja', 'zh'];

  // 미리보기 글꼴(Pretendard subset)이 글자를 담지 못하는 언어. 한글·라틴 글자와 스페인어 부호(áéíóúüñ¿¡)는
  // 담고 있다(fontTools 로 확인 — 계획 4 Task 13). 일본어·중국어는 시스템 글꼴로 보인다.
  var FONT_LACKING_LANGS = ['ja', 'zh'];

  // 언어 코드와 이름. 순서는 서버 AppLocale 과 같다.
  var LANGS = ['ko', 'en', 'ja', 'zh', 'es'];
  var LANG_NAMES = { ko: '한국어', en: '영어', ja: '일본어', zh: '중국어(간체)', es: '스페인어' };

  // 지금 미리보는 언어. keepWordsParts 가 이 값으로 표시 여부를 정한다 — 앱이 휴대폰 언어로 정하는 것과 같다.
  var previewLang = 'ko';
```

- [ ] **Step 5: `keepWordsParts` 와 언어 도움 함수를 고친다**

148~164행의 `keepWordsParts` 를 바꾼다(`keepWords` 는 그대로).

```js
  function keepWordsParts(parts) {
    // 일본어·중국어는 표시를 넣지 않는다(앱과 같은 규칙). 넣으면 어디서도 줄이 바뀌지 않는다.
    if (NO_JOINER_LANGS.indexOf(previewLang) >= 0) return parts.slice();
    var prev = null;
    return parts.map(function (part) {
      var out = '';
      graphemes(part).forEach(function (ch) {
        if (prev !== null && !isSpace(prev) && !isSpace(ch)) out += JOINER;
        out += ch;
        prev = ch;
      });
      return out;
    });
  }
```
(바꾸기 전 javadoc 은 그대로 둔다.)

`reaches` 함수(172~174행) 아래에 언어 도움 함수를 더한다.

```js

  // ── 언어 (#521) ─────────────────────────────────────────────

  /** 서버 AppLocale#fallbackChain 과 같다 — 요청 언어 → en → ko, 중복 없이. */
  function fallbackChain(lang) {
    var chain = [lang];
    if (chain.indexOf('en') < 0) chain.push('en');
    if (chain.indexOf('ko') < 0) chain.push('ko');
    return chain;
  }

  /** 공지 하나의 언어별 글. 서버가 texts 를 주면 그것, 없으면(구버전 자료) 한국어 필드다. */
  function textsOf(slide) {
    if (slide.texts) return slide.texts;
    return { ko: { title: slide.title, body: slide.body, buttonLabel: slide.buttonLabel } };
  }

  /** 제목과 본문이 다 있어야 채워진 글이다(서버의 "미완성" 기준과 같다). */
  function filled(text) {
    return !!(text && String(text.title || '').trim() && String(text.body || '').trim());
  }

  /**
   * 앱이 그 언어 휴대폰에 줄 글. 요청 → en → ko 순으로 제목과 본문이 다 있는 첫 언어다.
   * 아무것도 없으면 한국어(비어 있을 수 있다 — 편집 중에는 그럴 수 있다).
   */
  function resolveText(texts, lang) {
    var chain = fallbackChain(lang);
    for (var i = 0; i < chain.length; i++) {
      if (filled(texts[chain[i]])) return { lang: chain[i], text: texts[chain[i]] };
    }
    return { lang: 'ko', text: texts.ko || { title: '', body: '', buttonLabel: '' } };
  }

  /** 슬라이드를 그 언어로 고른 글로 바꾼 사본. shownLang 은 실제로 쓴 언어다. */
  function forLang(slide, lang) {
    var picked = resolveText(textsOf(slide), lang);
    var copy = {};
    Object.keys(slide).forEach(function (key) { copy[key] = slide[key]; });
    copy.title = picked.text.title;
    copy.body = picked.text.body;
    copy.buttonLabel = picked.text.buttonLabel || '';
    copy.shownLang = picked.lang;
    return copy;
  }

  /** 언어에 따라 안내 줄을 보이거나 감춘다. 앱 고정 문구는 한국어가 아니면, 글꼴 안내는 일본어·중국어에서. */
  function updateLangNotes() {
    var fixed = document.querySelector('[data-preview-fixed-note]');
    var font = document.querySelector('[data-preview-font-note]');
    var label = document.querySelector('[data-preview-lang-label]');
    if (fixed) fixed.hidden = previewLang === 'ko';
    if (font) font.hidden = FONT_LACKING_LANGS.indexOf(previewLang) < 0;
    if (label) label.textContent = LANG_NAMES[previewLang] || previewLang;
  }
```

- [ ] **Step 6: 목록·편집 미리보기를 교체한다**

`// ── 목록 화면: 전체 미리보기` 주석부터 `initEditor` 함수 끝(다음 `// ── 저장하면 어떻게 되는지` 주석 바로 앞)까지를 아래로 바꾼다(원본 기준 432~626행 — Step 4·5 에서 줄이 밀렸으므로 주석으로 찾는다). 이미지 처리·문구 도움·글자 수 세기는 기존과 같고, 언어 탭과 언어별 칸만 새로 들어간다.

```js
  // ── 목록 화면: 전체 미리보기 ─────────────────────────────────

  function initListPreview(container) {
    var data = readData();
    var note = document.querySelector('[data-preview-note]');
    var buttons = Array.prototype.slice.call(document.querySelectorAll('[data-preview-platform]'));
    var langButtons = Array.prototype.slice.call(document.querySelectorAll('[data-preview-lang]'));
    var platform = 'IOS';

    function render() {
      var slides = data.notices
        .filter(function (n) { return reaches(n.platform, platform); })
        .slice(0, APP.maxSlides)
        // 그 언어 휴대폰이 받을 글로 바꾼다. 그 언어 글이 없는 공지는 앱과 같게 영어 → 한국어다.
        .map(function (n) { return forLang(n, previewLang); });
      renderPopup(container, slides, data.hideDays, 0);
      var messages = [];
      var total = data.notices.filter(function (n) { return reaches(n.platform, platform); }).length;
      if (total > APP.maxSlides) {
        messages.push('게시 중 ' + total + '개 중 우선순위가 큰 ' + APP.maxSlides + '개만 팝업에 들어가요.');
      }
      var substituted = slides.filter(function (s) { return s.shownLang !== previewLang; }).length;
      if (substituted > 0) {
        messages.push(substituted + '개는 ' + LANG_NAMES[previewLang] + ' 글이 없어 영어·한국어로 대신 보여요. 앱도 똑같이 대신해요.');
      }
      if (note) note.textContent = messages.join(' ');
      updateLangNotes();
    }

    buttons.forEach(function (b) {
      b.addEventListener('click', function () {
        platform = b.getAttribute('data-preview-platform');
        setActive(buttons, 'data-preview-platform', platform);
        render();
      });
    });
    langButtons.forEach(function (b) {
      b.addEventListener('click', function () {
        previewLang = b.getAttribute('data-preview-lang');
        setActive(langButtons, 'data-preview-lang', previewLang);
        render();
      });
    });
    render();
  }

  // ── 편집 화면: 입력하는 대로 ────────────────────────────────

  function initEditor(form, container) {
    var data = readData();
    var $ = function (id) { return document.getElementById(id); };
    // 언어마다 제목·본문·버튼 문구 칸이 있다. 한국어는 예전 아이디 그대로, 나머지는 '-언어' 가 붙는다.
    var fields = {};
    LANGS.forEach(function (code) {
      var suffix = code === 'ko' ? '' : '-' + code;
      fields[code] = {
        title: $('notice-title' + suffix),
        body: $('notice-body' + suffix),
        buttonLabel: $('notice-button-label' + suffix)
      };
    });
    var buttonUrl = $('notice-button-url');
    var image = $('notice-image');
    var removeImage = $('notice-remove-image');
    var platformSelect = $('notice-platform');
    var priority = $('notice-priority');
    var startsAt = $('notice-starts-at');
    var wording = $('notice-wording');
    var imageNote = $('notice-image-note');
    var note = document.querySelector('[data-preview-note]');
    var modeButtons = Array.prototype.slice.call(document.querySelectorAll('[data-preview-mode]'));
    var platformButtons = Array.prototype.slice.call(document.querySelectorAll('[data-preview-platform]'));
    var tabs = Array.prototype.slice.call(document.querySelectorAll('[data-lang-tab]'));
    var panels = Array.prototype.slice.call(document.querySelectorAll('[data-lang-panel]'));
    var marks = {};
    Array.prototype.slice.call(document.querySelectorAll('[data-lang-mark]')).forEach(function (m) {
      marks[m.getAttribute('data-lang-mark')] = m;
    });

    var existingImage = container.getAttribute('data-existing-image') || '';
    var pickedImage = null; // 고른 파일을 읽은 data URL. 올리기 전에 미리 본다.
    var mode = 'single';
    var previewPlatform = platformSelect && platformSelect.value === 'ANDROID' ? 'ANDROID' : 'IOS';

    /** 칸에 적힌 언어별 글. 칸이 없는 언어(구버전 화면)는 건너뛴다. */
    function collectTexts() {
      var texts = {};
      LANGS.forEach(function (code) {
        var f = fields[code];
        if (!f.title || !f.body) return;
        texts[code] = {
          title: f.title.value,
          body: f.body.value,
          buttonLabel: f.buttonLabel ? f.buttonLabel.value.trim() : ''
        };
      });
      return texts;
    }

    function draft() {
      var imageUrl = pickedImage || (removeImage && removeImage.checked ? null : existingImage || null);
      var texts = collectTexts();
      return {
        draft: true,
        texts: texts,
        title: texts.ko ? texts.ko.title : '', body: texts.ko ? texts.ko.body : '',
        imageUrl: imageUrl,
        buttonLabel: texts.ko ? texts.ko.buttonLabel : '', buttonUrl: buttonUrl.value.trim(),
        platform: platformSelect.value, priority: parseInt(priority.value, 10) || 0,
        startsAt: startsAt.value
      };
    }

    function render() {
      var d = draft();
      var messages = [];
      var slides;
      var index = 0;
      if (mode === 'single') {
        slides = [forLang(d, previewLang)];
      } else {
        var others = data.notices.filter(function (n) { return reaches(n.platform, previewPlatform); });
        if (reaches(d.platform, previewPlatform)) {
          others = others.concat([d]);
        } else {
          messages.push('이 공지는 ' + (previewPlatform === 'IOS' ? 'iOS' : 'Android') + ' 앱에는 나가지 않아요.');
        }
        var ordered = others.slice().sort(slideOrder);
        var at = ordered.indexOf(d);
        if (at >= APP.maxSlides) {
          messages.push('우선순위가 낮아 ' + APP.maxSlides + '장 밖이라 앱에는 안 나가요. 우선순위를 올리면 들어가요.');
        } else if (at >= 0) {
          messages.push('이 공지는 ' + (at + 1) + '번째 장이에요.');
          index = at;
        }
        // 순서는 원본으로 정하고, 그린 뒤에 그 언어 글로 바꾼다(identity 로 이 공지를 찾아야 해서).
        slides = ordered.slice(0, APP.maxSlides).map(function (s) { return forLang(s, previewLang); });
      }
      var shown = resolveText(d.texts, previewLang);
      if (shown.lang !== previewLang) {
        messages.push(LANG_NAMES[previewLang] + ' 칸이 비어 있어 ' + LANG_NAMES[shown.lang]
          + ' 글로 보여요. 앱도 똑같이 대신해요.');
      }
      var drawn = renderPopup(container, slides, data.hideDays, index);
      // 버튼 문구는 두 줄까지가 보기 좋다(#390 R2). 넘어도 잘리지는 않지만 버튼이 커진다.
      if (drawn.linkLabel && drawn.linkLabel.offsetHeight > APP.buttonSize * 2 + 1) {
        messages.push('버튼 문구가 두 줄을 넘어요. 짧게 줄이면 버튼이 다른 팝업과 같은 크기로 떠요.');
      }
      if (note) note.textContent = messages.join(' ');
      checkWording();
      updateMarks();
      updateLangNotes();
    }

    function counter(input) {
      var target = document.querySelector('[data-count-for="' + input.id + '"]');
      if (!target) return;
      var max = input.getAttribute('maxlength');
      target.textContent = input.value.length + '/' + max;
    }

    // 탭의 ✓/− — 제목과 본문이 다 있으면 ✓. 서버의 "미완성" 기준과 같다.
    function updateMarks() {
      LANGS.forEach(function (code) {
        var f = fields[code];
        var mark = marks[code];
        if (!mark || !f.title || !f.body) return;
        mark.textContent = f.title.value.trim() && f.body.value.trim() ? '✓' : '−';
      });
    }

    // 문구 도움 (N20·N25). 경고만 한다. 금지어·해요체는 한국어 규칙이라 한국어 칸만 본다.
    // 강조 짝은 어느 언어든 서버가 막으므로 채운 모든 언어를 본다.
    function checkWording() {
      if (!wording) return;
      wording.textContent = '';
      var ko = fields.ko;
      var text = [ko.title.value, ko.body.value, ko.buttonLabel ? ko.buttonLabel.value : ''].join('\n');
      FORBIDDEN.forEach(function (f) {
        if (f.re.test(text)) {
          wording.appendChild(el('li', null, "'" + f.word + "' 대신 " + f.instead + ' 써요. 용어 규칙이에요'));
        }
      });
      if (FORMAL_ENDING.test(text)) {
        wording.appendChild(el('li', null, '해요체로 바꿔 볼까요? 예: 됩니다 → 돼요, 저장되었습니다 → 저장했어요'));
      }
      LANGS.forEach(function (code) {
        var f = fields[code];
        if (!f.title || !f.title.value || titleParts(f.title.value).paired) return;
        var where = code === 'ko' ? '' : '[' + LANG_NAMES[code] + '] ';
        wording.appendChild(el('li', 'text-error',
          where + '제목의 ** 짝이 맞지 않아요. 이대로는 저장되지 않아요. 강조할 글자를 **이렇게** 감싸요'));
      });
    }

    function onImagePicked() {
      pickedImage = null;
      if (imageNote) imageNote.textContent = '';
      var file = image.files && image.files[0];
      if (!file) { render(); return; }
      // 서버가 서명으로 다시 가린다. 여기서는 올리기 전에 빨리 알려 주기만 한다 (N16).
      if (IMAGE_TYPES.indexOf(file.type) < 0) {
        imageNote.textContent = 'png, jpg, webp 만 올릴 수 있어요. 이 파일은 저장할 때 거절돼요.';
        render();
        return;
      }
      if (file.size > IMAGE_MAX_BYTES) {
        imageNote.textContent = '2MB 를 넘어요(' + (file.size / 1024 / 1024).toFixed(1) + 'MB). 줄여서 다시 골라 주세요.';
        render();
        return;
      }
      var reader = new FileReader();
      reader.onload = function () {
        pickedImage = String(reader.result);
        var probe = new Image();
        probe.onload = function () {
          var ratio = probe.naturalWidth / probe.naturalHeight;
          if (Math.abs(ratio - APP.imageRatio) / APP.imageRatio > 0.03) {
            imageNote.textContent = '16:10 이 아니라서(' + probe.naturalWidth + '×' + probe.naturalHeight
              + ') 가장자리가 잘려 보여요. 미리보기로 확인해요.';
          }
        };
        probe.src = pickedImage;
        render();
      };
      reader.onerror = function () {
        imageNote.textContent = '이 파일을 읽지 못했어요. 다른 파일을 골라 주세요.';
        render();
      };
      reader.readAsDataURL(file);
    }

    /** 탭을 연다. 입력 칸과 미리보기가 같은 언어로 바뀐다. */
    function activate(code) {
      previewLang = LANGS.indexOf(code) >= 0 ? code : 'ko';
      tabs.forEach(function (t) {
        var on = t.getAttribute('data-lang-tab') === previewLang;
        t.classList.toggle('tab-active', on);
        t.setAttribute('aria-selected', on ? 'true' : 'false');
      });
      panels.forEach(function (p) {
        p.hidden = p.getAttribute('data-lang-panel') !== previewLang;
      });
      render();
    }

    // 모든 언어의 제목·본문·버튼 문구와 나머지 칸이 바뀔 때마다 글자 수를 세고 다시 그린다.
    var inputs = [buttonUrl, priority, startsAt];
    LANGS.forEach(function (code) {
      var f = fields[code];
      inputs.push(f.title, f.body, f.buttonLabel);
    });
    inputs.forEach(function (input) {
      if (!input) return;
      input.addEventListener('input', function () {
        counter(input);
        render();
      });
      counter(input);
    });
    [platformSelect, removeImage].forEach(function (input) {
      if (input) input.addEventListener('change', render);
    });
    if (image) image.addEventListener('change', onImagePicked);

    tabs.forEach(function (t) {
      t.addEventListener('click', function () { activate(t.getAttribute('data-lang-tab')); });
    });
    // 숨겨진 칸이 검증에 걸리면 브라우저가 "초점을 줄 수 없다"며 조용히 제출을 막는다 — 한국어가 비었는데
    // 영어 탭을 보고 있으면 저장이 아무 말 없이 안 된다. 걸린 칸의 탭을 먼저 연다.
    form.addEventListener('invalid', function (event) {
      var panel = event.target && event.target.closest ? event.target.closest('[data-lang-panel]') : null;
      if (panel) activate(panel.getAttribute('data-lang-panel'));
    }, true);

    modeButtons.forEach(function (b) {
      b.addEventListener('click', function () {
        mode = b.getAttribute('data-preview-mode');
        setActive(modeButtons, 'data-preview-mode', mode);
        render();
      });
    });
    platformButtons.forEach(function (b) {
      b.addEventListener('click', function () {
        previewPlatform = b.getAttribute('data-preview-platform');
        setActive(platformButtons, 'data-preview-platform', previewPlatform);
        render();
      });
    });
    setActive(platformButtons, 'data-preview-platform', previewPlatform);

    activate('ko');
  }
```

- [ ] **Step 7: 노출을 고친다**

803~805행(`window.ElumNoticePreview`)을 바꾼다.

```js
  // 테스트나 콘솔에서 쓸 수 있게 드러낸다.
  window.ElumNoticePreview = {
    renderPopup: renderPopup, titleParts: titleParts, publishOutcome: publishOutcome, APP: APP,
    // 줄바꿈 표시 규칙을 언어별로 본다(NoticePreviewScriptTest). 미리보는 언어를 잠깐 바꿔 부르고 되돌린다.
    keepWordsFor: function (text, lang) {
      var before = previewLang;
      previewLang = lang;
      try {
        return keepWords(text);
      } finally {
        previewLang = before;
      }
    },
    resolveText: resolveText
  };
```

- [ ] **Step 8: 저장 안내와 확인 창에 대상 국가를 넣는다**

공지에 대상 국가가 생겨서 "누구에게 나가는지" 문장이 "보호자 모두에게" 로만 나가면 거짓이 된다. 저장 안내(`#notice-publish-note`)와 두 확인 창(편집 저장·목록 켜기)이 대상 국가를 함께 말하게 한다. 대상 국가가 없을 때의 문장은 이전과 글자까지 같다. 함수 이름으로 찾는다(원본 656~762행).

1. `audience` 를 바꾸고 아래 도움 함수를 바로 아래에 더한다.

```js
  // 누구에게 가는지. 플랫폼을 좁혔으면 그 휴대폰 보호자만이고, 대상 국가를 정했으면 그 국가 보호자만이다 (#521).
  // 대상 국가가 없을 때의 문장은 이전과 같다("보호자 모두에게").
  function audience(platform, countries) {
    var who = platform === 'IOS' ? 'iOS 보호자' : (platform === 'ANDROID' ? 'Android 보호자' : '보호자');
    var list = parseCountries(countries);
    return list.length ? who + ' 중 대상 국가(' + list.join(', ') + ')의 보호자에게' : who + ' 모두에게';
  }

  // 쉼표로 구분한 국가 코드 칸 값을 목록으로. 형식 검사는 서버가 한다 — 여기는 안내 문구용이라 다듬기만 한다.
  function parseCountries(raw) {
    return (raw || '').split(',')
      .map(function (code) { return code.trim(); })
      .filter(function (code) { return code.length > 0; });
  }
```

2. `publishOutcome` 의 첫 줄을 바꾼다.

```js
    var who = audience(input.platform, input.targetCountries);
```

3. `initPublishNote` — 칸을 읽고, 바뀔 때 안내를 다시 쓰고, 확인 창에도 넣는다.

```js
    var countries = document.getElementById('notice-target-countries');
```
(`var platform = …` 줄 아래.) `current()` 의 `publishOutcome({ … })` 인자에 `targetCountries: countries ? countries.value : '',` 를 `platform:` 줄 아래에 더한다. 변경 감지 목록 `[enabled, startsAt, endsAt, platform, bump]` 에 `countries` 를 더한다. 제출 확인 창의 `audience(platform ? platform.value : 'ALL')` 는 아래로 바꾼다.

```js
        && !window.confirm('저장하면 바로 ' + audience(platform ? platform.value : 'ALL', countries ? countries.value : '')
```

4. `initEnableConfirm` — 목록 켜기 폼이 싣고 온 값(Task 8)을 읽는다.

```js
        if (!window.confirm("'" + title + "' 공지를 켜면 바로 "
          + audience(form.getAttribute('data-platform'), form.getAttribute('data-target-countries'))
```

5. 목록·편집 **미리보기**(`initListPreview`·`initEditor`·`renderPopup`)는 **바꾸지 않는다.** 게시 중인 공지를 국가로 거르지 않고 전부 보여주는 것이 맞다 — 이 화면은 팝업의 치수·글꼴·줄바꿈을 보는 도구이고 국가와 무관하다. 대신 Task 8 의 템플릿이 "대상 국가와 상관없이 게시 중인 공지를 모두 보여줘요" 안내를 둔다. `notice-preview.js` 머리 주석의 "하는 일" 목록에도 한 줄을 더한다.

```
 * 대상 국가(#521): 미리보기는 국가를 거르지 않는다(모양을 보는 도구). 저장 안내·확인 창만 대상 국가를 말한다.
```

- [ ] **Step 9: 통과를 확인한다**

Run: `cd server && ./gradlew test --tests 'com.chuseok22.elumserver.admin.*'`
Expected: PASS — `NoticePreviewScriptTest` 5건(node 가 있으면 모두, 없으면 앞의 둘만 돌고 나머지는 건너뜀).

- [ ] **Step 10: 브라우저로 눈으로 확인한다 (`/pro-launch`)**

서버를 로컬로 띄우고(`/pro-launch`, 로컬 DB 리허설은 `elum-local-db-rehearsal` 기록 참고) 관리자 로그인 후 `/admin/notices/new` 를 연다.

1. 언어 탭 5개가 보이고 한국어 탭만 활성이다. 영어 탭을 누르면 영어 칸이 열리고 미리보기 제목이 "영어 칸이 비어 있어 한국어 글로 보여요" 안내와 함께 한국어로 나온다.
2. 영어 제목·본문을 적으면 탭의 `−` 가 `✓` 로 바뀌고 미리보기가 영어 글로 바뀐다.
3. 일본어 탭에서는 "글꼴 안내"가 보이고, 한국어 탭에서는 보이지 않는다. 한국어가 아니면 "앱 고정 문구" 안내가 보인다.
4. 한국어 제목을 비운 채 영어 탭에서 저장을 누르면 **한국어 탭이 열리며** 브라우저 검증 말풍선이 뜬다(조용히 안 되지 않는다).
5. 제목에 `**` 짝을 깨뜨리면(영어 칸) 문구 도움에 `[영어] 제목의 ** 짝이…` 가 뜬다.
6. 대상 국가 칸에 `KR, JP` 를 적고 켜기를 켜면 저장 안내 줄이 "…iOS 보호자 중 대상 국가(KR, JP)의 보호자에게…" 처럼 바뀐다(플랫폼을 iOS 로 골랐을 때). 칸을 비우면 "보호자 모두에게" 로 돌아온다. 미리보기 옆에는 "대상 국가와 상관없이 …" 안내가 늘 보인다.

Expected: 위 여섯 가지가 모두 보인다. 안 되면 콘솔의 `E-NTC-JS` 로그를 먼저 본다.

- [ ] **Step 11: 커밋 (`/pro-commit`)**

```bash
git add server/src/main/resources/static/admin/js/notice-preview.js \
  server/src/test/java/com/chuseok22/elumserver/admin/application/controller/NoticePreviewScriptTest.java
```

---

## Task 10: 클라이언트 약관 번들·캐시·저장소의 언어

**Files:**
- Create: `client/lib/features/auth/domain/consent_language.dart`
- Modify: `client/lib/features/auth/domain/consent_bundle.dart:1-84`
- Modify: `client/lib/core/storage/local_storage.dart:123-124, 193, 392-400, 536, 664-671`
- Modify: `client/lib/features/auth/data/consent_document_repository.dart:1-122` (전체 교체)
- Test: `client/test/consent_document_language_test.dart` (새)

**Interfaces:**
- Consumes: 계획 1 의 `AcceptLanguageInterceptor`(앱 전체 요청에 `Accept-Language` 를 붙인다 — 이 Task 는 약관 요청에 한 번 더 명시한다), 서버 Task 4 의 `Content-Language` 응답 헤더
- Produces:
  - `String consentLanguageOf(Locale locale)` — 화면 언어 → 약관 언어 코드(`ko` `en` `ja` `zh` `es`, 5개 밖이면 `en`)
  - `String consentWireLanguage(String language)` — `Accept-Language` 값(`zh` → `zh-Hans`)
  - `ConsentBundle.language: String`(기본 `'ko'`), `ConsentBundle.defaultLanguage = 'ko'`, `static ConsentBundle? ConsentBundle.bundledFor(String language)` — 번들이 있는 언어만 값이 있다(지금은 `ko` 뿐)
  - `LocalStorage#cachedConsentJsonFor(String language): String?`, `LocalStorage#setCachedConsentJsonFor(String language, String json): Future<void>` — `ko` 는 예전 키를 그대로 쓴다
  - `ConsentDocumentRepository#loadFor(String language): Future<ConsentBundle?>` — **null 이면 그 언어는 읽을 약관이 없다**(서버에서도 캐시에서도 번들에서도). 옛 `load()` 는 `ko` 로 위임하며 여전히 null 을 주지 않는다
  - `ConsentDocumentRepository#fetchAndCache({String language})`
  - `consentBundleForProvider: FutureProvider.family<ConsentBundle?, String>` — `ko` 는 기존 `consentBundleProvider` 를 그대로 거친다

> **`ko` 가 기존 경로를 그대로 지나는 이유.** 앱의 위젯 시험 여덟 파일이 `consentBundleProvider.overrideWith(...)` 로 네트워크를 막고 있다. `ko` 를 새 경로로 옮기면 그 시험들이 전부 다시 쓰여야 한다. `consentBundleForProvider('ko')` 가 `consentBundleProvider` 에 위임하면 한국어 동작은 **구성상** 바뀌지 않는다.
>
> **`en` 번들을 지금 두지 않는 이유.** 스펙은 번들 기본값을 `ko`+`en` 두 벌로 정했지만 영어 약관 본문은 법무 확인(계획 7)을 거친 뒤에야 있다. 확인되지 않은 번역을 번들에 박으면 앱 배포로 법적 문구가 나가 버린다. 구조는 `en` 이 한 줄(`_bundledByLanguage` 항목)로 들어오게 만들어 두었고, 그 한 줄을 넣는 변경이 Step 1 의 `bundledFor_onlyKoUntilLegalReview` 시험을 고치는 변경이 되도록 시험이 문을 지킨다.

- [ ] **Step 1: 선행 확인**

Run:
```bash
grep -rn "supportedAppLocales" client/lib/core/l10n
grep -rn "class AcceptLanguageInterceptor" client/lib
grep -n "localeTestValue\|localesTestValue" client/test/flutter_test_config.dart
```
Expected: 각각 1건 이상. 하나라도 없으면 계획 1 이 끝나지 않았다 — 이 Task 를 시작하지 않는다.

- [ ] **Step 2: 실패하는 시험을 쓴다**

`client/test/consent_document_language_test.dart`:

```dart
import 'dart:convert';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/auth/data/consent_document_repository.dart';
import 'package:elum/features/auth/domain/consent_bundle.dart';
import 'package:elum/features/auth/domain/consent_documents.dart';
import 'package:elum/features/auth/domain/consent_language.dart';
import 'package:flutter_test/flutter_test.dart';

/// 약관이 언어별로 나뉘어 읽히는지 (이슈 #521).
///
/// **읽을 수 없는 언어의 약관으로 동의받지 않는다.** 그래서 서버도 캐시도 번들도 없는 언어는
/// 한국어로 대체하지 않고 "없다"(null)고 돌려준다 — 화면이 "약관을 불러오지 못했어요"와 재시도를 띄운다.
void main() {
  Map<String, dynamic> payload({String version = '2026-10-02', String body = '서버 본문'}) => {
    'version': version,
    'documents': [
      {
        'key': 'termsAgreed',
        'label': '이용약관',
        'required': true,
        'summary': '요약',
        'body': body,
        'version': version,
      },
    ],
  };

  /// 요청을 가로채 응답을 만든다. 네트워크에 나가지 않는다. [seen] 에 요청을 쌓는다.
  Dio dioWith(
    Response<Map<String, dynamic>> Function(RequestOptions options) handler, {
    List<RequestOptions>? seen,
  }) {
    final dio = Dio();
    dio.httpClientAdapter = _NoNetwork();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, h) {
          seen?.add(options);
          try {
            h.resolve(handler(options));
          } catch (e) {
            h.reject(DioException(requestOptions: options, error: e));
          }
        },
      ),
    );
    return dio;
  }

  Response<Map<String, dynamic>> served(
    RequestOptions options,
    Map<String, dynamic> data, {
    String? language,
  }) => Response(
    requestOptions: options,
    data: data,
    headers: Headers.fromMap({
      if (language != null) 'content-language': [language],
    }),
  );

  Dio failingDio() => dioWith((o) => throw Exception('서버를 못 봤다'));

  group('언어별 캐시', () {
    test('ko 는 예전 캐시 키를 그대로 쓴다 — 이미 받아 둔 캐시를 버리지 않는다', () async {
      final storage = InMemoryStorage();
      await storage.setCachedConsentJson(jsonEncode(payload(version: '2026-09-30')));
      final repo = ConsentDocumentRepository(dio: failingDio(), storage: storage);

      final bundle = await repo.loadFor('ko');

      expect(bundle?.source, ConsentSource.cache);
      expect(bundle?.version, '2026-09-30');
      expect(bundle?.language, 'ko');
    });

    test('다른 언어는 그 언어의 캐시에만 담고 한국어 캐시는 건드리지 않는다', () async {
      final storage = InMemoryStorage();
      final repo = ConsentDocumentRepository(
        dio: dioWith((o) => served(o, payload(), language: 'ja')),
        storage: storage,
      );

      final bundle = await repo.loadFor('ja');

      expect(bundle?.source, ConsentSource.server);
      expect(bundle?.language, 'ja');
      expect(storage.cachedConsentJsonFor('ja'), isNotNull);
      expect(storage.cachedConsentJson, isNull, reason: '일본어 약관이 한국어 캐시에 섞이면 안 된다');
      expect(storage.cachedConsentJsonFor('es'), isNull);
    });

    test('캐시가 있으면 서버를 기다리지 않고 그 언어 캐시를 준다', () async {
      final storage = InMemoryStorage();
      await storage.setCachedConsentJsonFor('ja', jsonEncode(payload(version: '2026-10-01')));
      final repo = ConsentDocumentRepository(dio: failingDio(), storage: storage);

      final bundle = await repo.loadFor('ja');

      expect(bundle?.source, ConsentSource.cache);
      expect(bundle?.language, 'ja');
    });
  });

  group('요청과 응답의 언어', () {
    test('요청에 언어 헤더를 싣는다 — zh 는 zh-Hans(C1)', () async {
      final seen = <RequestOptions>[];
      final repo = ConsentDocumentRepository(
        dio: dioWith((o) => served(o, payload(), language: 'zh'), seen: seen),
        storage: InMemoryStorage(),
      );

      await repo.loadFor('zh');

      expect(seen.single.headers['Accept-Language'], 'zh-Hans');
      expect(seen.single.path, '/api/consents/documents');
    });

    test('다른 언어로 온 응답은 받지 않는다 — 읽지 못하는 약관을 그 언어 캐시에 넣지 않는다', () async {
      final storage = InMemoryStorage();
      final repo = ConsentDocumentRepository(
        // 일본어를 요청했는데 서버가 한국어로 답했다(옛 서버·중간 캐시).
        dio: dioWith((o) => served(o, payload(), language: 'ko')),
        storage: storage,
      );

      expect(await repo.loadFor('ja'), isNull);
      expect(storage.cachedConsentJsonFor('ja'), isNull);
    });

    test('Content-Language 가 없으면 ko 로 본다 — 헤더 없는 옛 서버', () async {
      final repo = ConsentDocumentRepository(
        dio: dioWith((o) => served(o, payload())),
        storage: InMemoryStorage(),
      );

      expect(await repo.loadFor('ja'), isNull);
      expect((await repo.loadFor('ko'))?.source, ConsentSource.server);
    });

    test('서버가 문서를 비워 주면(그 언어가 아직 열리지 않았다) null 이다 — 캐시에도 넣지 않는다', () async {
      final storage = InMemoryStorage();
      final repo = ConsentDocumentRepository(
        dio: dioWith((o) => served(o, {'version': '', 'documents': <Object>[]}, language: 'ja')),
        storage: storage,
      );

      expect(await repo.loadFor('ja'), isNull);
      expect(storage.cachedConsentJsonFor('ja'), isNull);
    });
  });

  group('읽을 약관이 없는 언어', () {
    test('loadFor_noBundle_unavailable — 서버도 캐시도 번들도 없으면 null 이다. 한국어로 대체하지 않는다', () async {
      final repo = ConsentDocumentRepository(dio: failingDio(), storage: InMemoryStorage());

      expect(await repo.loadFor('ja'), isNull);
      expect(await repo.loadFor('zh'), isNull);
      expect(await repo.loadFor('es'), isNull);
      // 영어 번들도 법무 확인 본문이 들어오기 전에는 없다.
      expect(await repo.loadFor('en'), isNull);
    });

    test('한국어는 어떤 실패에도 번들이 남는다 — 이 화면이 비는 경우는 없다', () async {
      final repo = ConsentDocumentRepository(dio: failingDio(), storage: InMemoryStorage());

      final bundle = await repo.loadFor('ko');

      expect(bundle?.source, ConsentSource.bundled);
      expect(bundle?.version, consentVersion);
      // 옛 load() 도 그대로 non-null 이다.
      expect((await repo.load()).source, ConsentSource.bundled);
    });

    test('bundledFor_onlyKoUntilLegalReview — 번들은 ko 뿐이다. 새 언어 번들은 법무 확인 본문과 함께 들어와야 한다', () {
      expect(ConsentBundle.bundledFor('ko'), isNotNull);
      for (final language in ['en', 'ja', 'zh', 'es']) {
        expect(
          ConsentBundle.bundledFor(language),
          isNull,
          reason: '$language 번들을 넣는다면 법무 확인(계획 7)을 거친 본문이어야 하고, 이 시험을 같이 고친다',
        );
      }
    });
  });

  group('언어 코드', () {
    test('화면 언어를 약관 언어로 바꾼다 — 5개 밖은 en(C1)', () {
      expect(consentLanguageOf(const Locale('ko')), 'ko');
      expect(consentLanguageOf(const Locale('es', 'MX')), 'es');
      expect(consentLanguageOf(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans')), 'zh');
      // 번체도 서버에서는 zh 로 읽는다 — 앱이 en 으로 가르면 서버와 어긋난다.
      expect(consentLanguageOf(const Locale('zh', 'TW')), 'zh');
      expect(consentLanguageOf(const Locale('fr')), 'en');
      expect(consentLanguageOf(const Locale('ar')), 'en');
    });

    test('전송 값은 zh 만 zh-Hans 다', () {
      expect(consentWireLanguage('zh'), 'zh-Hans');
      expect(consentWireLanguage('ko'), 'ko');
      expect(consentWireLanguage('es'), 'es');
    });
  });
}

class _NoNetwork implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fail('실제 네트워크로 나갔다');
  }
}
```

- [ ] **Step 3: 실행해 실패를 확인한다**

Run: `cd client && flutter test test/consent_document_language_test.dart`
Expected: FAIL — 컴파일 오류(`consent_language.dart` 없음, `loadFor`·`cachedConsentJsonFor` 없음).

- [ ] **Step 4: 언어 도우미를 쓴다**

`client/lib/features/auth/domain/consent_language.dart`:

```dart
import 'dart:ui';

/// 약관 언어로 쓰는 코드. 서버 `AppLocale` 과 같다 (계획 4 · C1).
const _supported = {'ko', 'en', 'ja', 'zh', 'es'};

/// 화면 언어를 약관 언어 코드로 바꾼다. 5개 밖이면 `en` 이다 — 서버의 `Accept-Language` 규칙과 같다.
///
/// 번체 중국어(`zh_TW`)도 `zh` 다. 서버가 `zh*` 를 모두 `zh` 로 읽으므로 앱이 따로 가르면 어긋난다.
String consentLanguageOf(Locale locale) =>
    _supported.contains(locale.languageCode) ? locale.languageCode : 'en';

/// 서버로 보내는 `Accept-Language` 값. `zh` 만 스크립트가 붙는다 (C1).
String consentWireLanguage(String language) => language == 'zh' ? 'zh-Hans' : language;
```

- [ ] **Step 5: 번들에 언어를 단다**

`consent_bundle.dart` 를 고친다.

1. 생성자와 필드(9~35행)를 바꾼다.

```dart
class ConsentBundle {
  const ConsentBundle({
    required this.version,
    required this.items,
    required this.source,
    this.language = defaultLanguage,
  });

  /// 번들 기본값이 있고, 옛 앱이 늘 쓰던 언어. 다른 언어는 서버에서 받은 캐시가 없으면 읽을 약관이 없다.
  static const defaultLanguage = 'ko';

  /// 동의를 기록할 때 서버로 보낼 버전. 필수 항목 중 가장 최근 것이다.
  final String version;

  final List<ConsentItem> items;

  final ConsentSource source;

  /// 이 약관의 언어 코드. **사용자가 본 약관의 언어**이므로 동의를 기록할 때 함께 보낸다 —
  /// 어떤 사용자가 어떤 언어의 어떤 버전에 동의했는지 증명한다.
  final String language;

  /// 앱에 박혀 있는 한국어 기본값. 서버도 캐시도 읽지 못했을 때 쓴다.
  static const bundled = ConsentBundle(
    version: consentVersion,
    items: consentItems,
    source: ConsentSource.bundled,
  );

  /// 언어별 앱 번들 기본값. **법무 확인을 거친 본문만** 담는다 — 확인 전 번역이 앱 배포로 나가면 안 된다.
  /// 영어를 넣을 때는 이 항목을 더하고 `consent_document_language_test.dart` 의 번들 시험을 같이 고친다.
  static const _bundledByLanguage = <String, ConsentBundle>{defaultLanguage: bundled};

  /// 그 언어의 번들 기본값. 없으면 null — 읽을 약관이 없는 언어다.
  static ConsentBundle? bundledFor(String language) => _bundledByLanguage[language];
```

2. `tryParse`·`tryParseJson`(40~71행)에 언어를 받는다.

```dart
  static ConsentBundle? tryParse(
    Object? raw, {
    required ConsentSource source,
    String language = defaultLanguage,
  }) {
    if (raw is! Map) return null;
    final documents = raw['documents'];
    if (documents is! List || documents.isEmpty) return null;

    final items = <ConsentItem>[];
    for (final entry in documents) {
      final item = ConsentItem.tryParse(entry);
      // 한 항목이라도 깨졌으면 통째로 버린다. 일부만 빠지면 사용자가 동의해야 할
      // 항목이 화면에서 사라지는데, 그건 조용히 일어나 아무도 알아채지 못한다.
      if (item == null) return null;
      items.add(item);
    }

    final version = raw['version'];
    if (version is! String || version.isEmpty) return null;

    return ConsentBundle(version: version, items: items, source: source, language: language);
  }

  static ConsentBundle? tryParseJson(
    String json, {
    required ConsentSource source,
    String language = defaultLanguage,
  }) {
    try {
      return tryParse(jsonDecode(json), source: source, language: language);
    } on FormatException {
      // 캐시가 깨졌다. 지우지 않고 그냥 무시한다 — 다음 갱신이 덮어쓴다.
      return null;
    }
  }
```
(`toJson`·`requiredItems`·`optionalItems`·`ConsentSource` 는 그대로다.)

- [ ] **Step 6: 저장소에 언어별 캐시를 단다**

`local_storage.dart`:

1. 인터페이스 123~124행(`cachedConsentJson`·`setCachedConsentJson`) 아래에 더한다.

```dart
  /// 언어별 약관 캐시 (이슈 #521). **한국어는 예전 키([cachedConsentJson])를 그대로 쓴다** — 이미 받아 둔
  /// 캐시를 버리지 않는다. 다른 언어는 언어마다 키가 따로라 한 언어의 약관이 다른 언어 화면에 섞이지 않는다.
  String? cachedConsentJsonFor(String language);
  Future<void> setCachedConsentJsonFor(String language, String json);
```

2. 193행(`_kCachedConsent`) 아래에 키 접두어를 더한다.

```dart
  static const _kCachedConsentPrefix = 'cache.consentDocuments.';
  static const _kLegacyConsentLanguage = 'ko';
```

3. `SharedPrefsStorage` — 400행(`setCachedConsentJson` 끝 `}`) 아래에 더한다.

```dart

  @override
  String? cachedConsentJsonFor(String language) => language == _kLegacyConsentLanguage
      ? cachedConsentJson
      : _prefs.getString('$_kCachedConsentPrefix$language');

  @override
  Future<void> setCachedConsentJsonFor(String language, String json) {
    if (language == _kLegacyConsentLanguage) return setCachedConsentJson(json);
    final key = '$_kCachedConsentPrefix$language';
    // 약관 전문은 길다. 크기만 남긴다.
    AppLogger.storageWrite(key, '${json.length}B');
    return _prefs.setString(key, json);
  }
```

4. `InMemoryStorage` — 536행(`String? _cachedConsent;`) 아래에 필드를, 671행(`setCachedConsentJson` 한 줄) 아래에 메서드를 더한다.

```dart
  final Map<String, String> _cachedConsentByLanguage = {};
```
```dart

  // 한국어는 예전 필드를 그대로 쓴다. [cachedConsentJson] 을 거쳐야 시험의 저장소 대역
  // (`_BlockedStorage` 처럼 그 getter 만 막는 것)이 한국어 경로에서도 그대로 막힌다.
  @override
  String? cachedConsentJsonFor(String language) =>
      language == 'ko' ? cachedConsentJson : _cachedConsentByLanguage[language];

  @override
  Future<void> setCachedConsentJsonFor(String language, String json) async {
    if (language == 'ko') {
      await setCachedConsentJson(json);
    } else {
      _cachedConsentByLanguage[language] = json;
    }
  }
```

- [ ] **Step 7: 저장소(Repository)를 교체한다**

`consent_document_repository.dart` 전체를 아래로 바꾼다.

```dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/local_storage.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../domain/consent_bundle.dart';
import '../domain/consent_language.dart';

/// 약관 전문을 어디서 읽을지 고른다 (이슈 #278). 언어마다 따로다 (이슈 #521).
///
/// ## 왜 세 층인가
///
/// 서버로만 옮기면 **네트워크가 없을 때 가입이 막힌다.** 동의는 "읽을 수 있는
/// 상태에서 받아야" 성립하므로, 읽을 것이 없으면 동의를 받을 수 없다.
///
/// | 층 | 언제 쓰나 |
/// |---|---|
/// | 서버 | 평소. 관리자가 고친 최신본 |
/// | 캐시 | 서버를 못 봤을 때. 지난번에 받아 둔 것 (언어별) |
/// | 앱 번들 | 첫 실행에 네트워크까지 없을 때. **번들이 있는 언어만** (지금은 한국어) |
///
/// ## 언어
///
/// **읽을 수 없는 언어의 약관으로 동의받지 않는다.** 번들이 없는 언어는 서버에서도 캐시에서도 못 받으면
/// 한국어로 대체하지 않고 `null` 을 돌려준다 — 화면이 "약관을 불러오지 못했어요"와 재시도를 띄운다.
/// 한국어는 어떤 실패에도 번들이 남는다.
///
/// **어떤 실패도 예외로 새어 나가지 않는다.** 약관을 못 받았다고 앱이 죽거나
/// 가입이 막히면, 서버가 잠깐 흔들릴 때 신규 가입이 통째로 멈춘다.
class ConsentDocumentRepository {
  ConsentDocumentRepository({required Dio dio, required LocalStorage storage})
      : _dio = dio,
        _storage = storage;

  final Dio _dio;
  final LocalStorage _storage;

  /// 서버를 기다리는 상한. [AppConfig.consentFetchTimeout] 을 따른다.
  ///
  /// 동의 화면은 로그인 직후에 선다. 여기서 오래 붙들면 **로그인이 실패한 것처럼**
  /// 보인다. 짧게 끊고 캐시로 넘어가는 편이 낫다 — 캐시가 조금 낡는 것보다
  /// 화면이 멈춘 것이 나쁘다.
  ///
  /// ⚠️ **연결 단계에도 준다.** 전에는 응답·전송에만 걸어 연결은 전역값(10초)을
  /// 따랐고, 응답 없는 망에서 실제로 10초를 기다렸다 (#278 QA 실측 10,034ms).
  ///
  /// 언어 헤더도 여기서 명시한다. 앱 전체에는 `AcceptLanguageInterceptor` 가 붙이지만, 약관은 어느 언어를
  /// 받는지가 증빙이라 호출부가 헤더를 직접 정한다(같은 값이다).
  static Options _options(String language) {
    final limit = AppConfig.consentFetchTimeout;
    return Options(
      connectTimeout: limit,
      receiveTimeout: limit,
      sendTimeout: limit,
      headers: {'Accept-Language': consentWireLanguage(language)},
    );
  }

  /// 한국어 약관. 옛 호출부용 — 언제나 값이 있다(서버 → 캐시 → 번들).
  Future<ConsentBundle> load() async =>
      await loadFor(ConsentBundle.defaultLanguage) ?? ConsentBundle.bundled;

  /// 그 언어로 화면에 띄울 약관을 고른다. **읽을 약관이 없으면 null 이다.**
  ///
  /// 캐시가 있으면 **기다리지 않는다.** 즉시 캐시를 주고 갱신은 뒤에서 돈다 —
  /// 재동의로 다시 들어온 사람을 매번 3초씩 세울 이유가 없다.
  /// 캐시가 없을 때(=첫 실행)만 서버를 기다린다. 그때 기다리지 않으면 관리자가
  /// 고친 문구가 **정작 신규 가입자에게 안 간다.**
  Future<ConsentBundle?> loadFor(String language) async {
    final cached = _readCache(language);
    if (cached != null) {
      // 실패해도 무시한다 — 결과는 다음에 열 때 쓰인다.
      unawaited(fetchAndCache(language: language));
      return cached;
    }
    return await fetchAndCache(language: language) ?? ConsentBundle.bundledFor(language);
  }

  /// 서버에서 받아 그 언어 캐시에 넣는다. 실패하면 null이고 **예외를 던지지 않는다.**
  Future<ConsentBundle?> fetchAndCache({String language = ConsentBundle.defaultLanguage}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/consents/documents',
        // 인증 없이 열린 경로다. 토큰이 있으면 붙지만 서버가 보지 않는다.
        options: _options(language),
      );
      // 서버가 준 언어가 요청한 언어와 같을 때만 받는다. 한국어 약관을 일본어 캐시에 넣으면 읽지 못하는
      // 약관에 동의받게 된다. 헤더가 없는 옛 서버는 한국어만 줬으므로 ko 로 본다.
      final served = (response.headers.value('content-language') ?? ConsentBundle.defaultLanguage)
          .toLowerCase();
      if (served != language) {
        AppLogger.error('약관 조회', '요청 언어($language)와 응답 언어($served)가 달라 무시합니다');
        return null;
      }
      final bundle = ConsentBundle.tryParse(
        response.data,
        source: ConsentSource.server,
        language: language,
      );
      if (bundle == null) {
        // 문서가 비어 있으면 그 언어는 서버에 아직 열리지 않았다(게시 전). 형식이 깨진 경우와 같이 무시한다.
        AppLogger.error('약관 조회', '응답이 비었거나 형식이 달라 무시합니다 (language=$language)');
        return null;
      }
      await _writeCache(language, bundle);
      return bundle;
    } catch (e) {
      // 서버를 못 봤다. 화면은 캐시나 번들 기본값으로 그대로 뜬다(없는 언어는 불러오지 못했다는 화면).
      AppLogger.error('약관 조회', e);
      return null;
    }
  }

  ConsentBundle? _readCache(String language) {
    try {
      final json = _storage.cachedConsentJsonFor(language);
      if (json == null || json.isEmpty) return null;
      return ConsentBundle.tryParseJson(json, source: ConsentSource.cache, language: language);
    } catch (e) {
      // 사생활 보호 모드 등에서 저장소 접근 자체가 막힐 수 있다.
      AppLogger.error('약관 캐시 읽기', e);
      return null;
    }
  }

  Future<void> _writeCache(String language, ConsentBundle bundle) async {
    try {
      await _storage.setCachedConsentJsonFor(language, bundle.toJson());
    } catch (e) {
      // 캐시에 못 넣어도 이번 화면은 멀쩡히 뜬다. 다음에 또 받으면 된다.
      AppLogger.error('약관 캐시 쓰기', e);
    }
  }
}

final consentDocumentRepositoryProvider = Provider<ConsentDocumentRepository>((ref) {
  return ConsentDocumentRepository(
    dio: ref.watch(dioProvider),
    storage: ref.watch(localStorageProvider),
  );
});

/// 한국어 약관. 실패하지 않는다 — 최악의 경우 앱 번들 기본값이 온다.
///
/// 한국어 경로는 이 provider 하나를 그대로 지난다(위젯 시험이 이것을 갈아 끼운다).
final consentBundleProvider = FutureProvider<ConsentBundle>((ref) {
  return ref.watch(consentDocumentRepositoryProvider).load();
});

/// 그 언어의 약관. **null 이면 읽을 약관이 없다** — 화면이 "약관을 불러오지 못했어요"와 재시도를 띄운다.
///
/// 한국어는 [consentBundleProvider] 에 위임한다 — 한국어 동작이 구성상 그대로다.
final consentBundleForProvider = FutureProvider.family<ConsentBundle?, String>((ref, language) {
  if (language == ConsentBundle.defaultLanguage) {
    return ref.watch(consentBundleProvider.future);
  }
  return ref.watch(consentDocumentRepositoryProvider).loadFor(language);
});
```

- [ ] **Step 8: 통과를 확인한다**

Run:
```bash
cd client && flutter test test/consent_document_language_test.dart test/consent_document_repository_test.dart test/consent_body_test.dart
flutter analyze lib/features/auth lib/core/storage
```
Expected: 신규 13건 PASS + 기존 저장소 시험 전부 PASS(옛 `load()`·`_BlockedStorage` 경로가 그대로 돈다), analyze 0건.

- [ ] **Step 9: 커밋 (`/pro-commit`)**

```bash
git add client/lib/features/auth/domain/consent_language.dart \
  client/lib/features/auth/domain/consent_bundle.dart \
  client/lib/features/auth/data/consent_document_repository.dart \
  client/lib/core/storage/local_storage.dart \
  client/test/consent_document_language_test.dart
```

---

## Task 11: 클라이언트 동의 화면과 약관 목록의 "약관을 불러오지 못했어요"

**Files:**
- Create: `client/lib/features/auth/presentation/widgets/consent_unavailable_view.dart`
- Modify: `client/lib/features/auth/presentation/consent_screen.dart` (`_submit` 의 `agree(` 호출, `build`, `_waiting` 다음에 `_unavailable` 추가)
- Modify: `client/lib/features/auth/presentation/consent_document_list_screen.dart:24-60`
- Modify: `client/lib/features/auth/data/consent_repository.dart:36-55` (`language` 인자, `consentLocale` 본문)
- Modify: `client/lib/l10n/app_ko.arb`, `client/lib/l10n/app_en.arb` (키 네 쌍)
- Modify: `client/test/consent_payload_test.dart:78-85` (기대 본문에 `consentLocale`)
- Test: `client/test/consent_language_screen_test.dart` (새)

**Interfaces:**
- Consumes: Task 10 의 `consentBundleForProvider`, `consentLanguageOf`, `ConsentBundle.language`/`bundledFor`, 계획 1 의 `context.l10n`(`L10nContext`)
- Produces:
  - `ConsentUnavailableView({required VoidCallback onRetry})` — 설명·안내·재시도 버튼(`Key('consent-unavailable-retry')`)
  - `ConsentRepository#agree({required Set<String> agreedKeys, required String version, String language = 'ko'})` — 본문에 `consentLocale: language`
  - ARB 키 `consentUnavailableTitle` · `consentUnavailableDescription` · `consentUnavailableHint` · `consentUnavailableRetry`

> **계획 1 이 끝난 뒤에만 한다.** 이 화면의 다른 문구(`'다음'`, `'약관에 동의해주세요'` …)는 계획 1 이 ARB 로 옮긴다. 이 Task 는 **새 문구 네 개만** 더하고 기존 문구에는 손대지 않는다. 라인이 밀려 있을 수 있으므로 아래 수정은 **심볼(함수 이름) 기준**으로 찾는다.
>
> **시안이 없는 화면이다.** "약관을 불러오지 못했어요" 상태는 Figma 에 없다. 기존 `_waiting` 과 같은 골격(헤더 + 하단 버튼)으로 만들되, 디자이너 확인이 필요하다 — Task 13 에서 `/pro-design-brief` 로 디자인 요청을 올린다.
>
> **ja·zh·es ARB 에는 이 Task 에서 넣지 않는다.** 번역은 계획 5 의 작업이다. 키가 없는 언어는 계획 1 의 규칙대로 `en` → `ko` 로 대체된다. 계획 5 의 키 일치 검사가 이 네 키를 누락으로 잡으면 계획 5 의 번역 작업에 이 네 키를 포함시킨다.

- [ ] **Step 1: 선행 확인과 기존 시험 기준선**

Run:
```bash
grep -n "consentBundleProvider\|ConsentBundle.bundled" client/lib/features/auth/presentation/consent_screen.dart client/lib/features/auth/presentation/consent_document_list_screen.dart
cd client && flutter test test/consent_screen_test.dart test/consent_payload_test.dart test/guardian_settings_test.dart test/settings_conformance_test.dart
```
Expected: 앞 명령은 두 화면의 `ref.watch(consentBundleProvider)` 와 `ConsentBundle.bundled` 를 보인다(바꿀 자리). 뒤 명령은 PASS 다(바꾸기 전 기준선). **여기서 실패하면 계획 1 의 테스트 기본 locale 이 빠진 것이다 — 이 Task 를 멈춘다.**

- [ ] **Step 2: 실패하는 화면 시험을 쓴다**

`client/test/consent_language_screen_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/app_pressable.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/auth/data/consent_document_repository.dart';
import 'package:elum/features/auth/data/consent_repository.dart';
import 'package:elum/features/auth/domain/consent_bundle.dart';
import 'package:elum/features/auth/domain/consent_documents.dart';
import 'package:elum/features/auth/presentation/consent_screen.dart';
import 'package:elum/features/auth/presentation/widgets/consent_row.dart';
import 'package:elum/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';

/// 약관이 게시되지 않은 언어에서 가입이 막히고 재시도가 나오는지 (이슈 #521).
///
/// **빈 화면도 무한 로딩도 안 된다.** 읽을 수 없는 언어의 약관으로 동의를 받지 않되, 사용자가 막다른 길에
/// 서지 않게 이유와 재시도를 보여준다. 한국어는 어떤 실패에도 번들이 남아 이 화면이 비지 않는다.
void main() {
  useFigmaViewport();

  Map<String, dynamic>? sent;

  Dio capturingDio() => Dio()
    ..interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      sent = Map<String, dynamic>.from(o.data as Map);
      h.resolve(Response(requestOptions: o, statusCode: 200, data: <String, dynamic>{}));
    }));

  Widget wrap({
    required String language,
    required List<Override> overrides,
    Dio? dio,
  }) {
    final router = GoRouter(initialLocation: Routes.consent, routes: [
      GoRoute(path: Routes.consent, builder: (_, _) => const ConsentScreen()),
      GoRoute(path: Routes.roleSelect, builder: (_, _) => const Scaffold(body: Text('역할 선택'))),
      GoRoute(path: Routes.login, builder: (_, _) => const Scaffold(body: Text('로그인'))),
    ]);
    return ProviderScope(
      overrides: [
        consentRepositoryProvider.overrideWithValue(ConsentRepository(dio: dio ?? capturingDio())),
        ...overrides,
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, _) => MaterialApp.router(
          theme: AppTheme.light,
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
  }

  final retryButton = find.byKey(const Key('consent-unavailable-retry'));

  setUp(() => sent = null);

  testWidgets('unavailable_showsRetry_notBlank — 읽을 약관이 없는 언어는 빈 화면이 아니라 재시도를 보여준다', (tester) async {
    await tester.pumpWidget(wrap(
      language: 'ja',
      overrides: [consentBundleForProvider('ja').overrideWith((ref) async => null)],
    ));
    await tester.pumpAndSettle();

    expect(retryButton, findsOneWidget);
    // 동의할 항목도, 끝나지 않는 로딩도 없다.
    expect(find.byType(ConsentRow), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('retry_reloads — 재시도를 누르면 다시 불러오고, 약관이 열렸으면 동의 화면이 선다', (tester) async {
    var calls = 0;
    final bundle = ConsentBundle(
      version: '2026-10-02',
      items: consentItems,
      source: ConsentSource.server,
      language: 'ja',
    );
    await tester.pumpWidget(wrap(
      language: 'ja',
      overrides: [
        consentBundleForProvider('ja').overrideWith((ref) async {
          calls++;
          return calls < 2 ? null : bundle;
        }),
      ],
    ));
    await tester.pumpAndSettle();
    expect(retryButton, findsOneWidget);

    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byType(ConsentRow), findsWidgets);
    expect(retryButton, findsNothing);
  });

  testWidgets('error_nonKo_unavailable — 한국어가 아닌 언어에서 오류가 나도 한국어 약관으로 대체하지 않는다', (tester) async {
    await tester.pumpWidget(wrap(
      language: 'ja',
      overrides: [
        consentBundleForProvider('ja').overrideWith((ref) async => throw Exception('예상 못 한 예외')),
      ],
    ));
    await tester.pumpAndSettle();

    expect(retryButton, findsOneWidget);
    expect(find.text(consentItems.first.label), findsNothing, reason: '읽지 못하는 한국어 약관이 일본어 화면에 뜨면 안 된다');
  });

  testWidgets('en 은 번들이 없어 서버·캐시가 없으면 불러오지 못했다고 한다', (tester) async {
    final failing = Dio()
      ..interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
        h.reject(DioException(requestOptions: o, error: Exception('서버를 못 봤다')));
      }));
    await tester.pumpWidget(wrap(
      language: 'en',
      overrides: [
        consentDocumentRepositoryProvider.overrideWithValue(
          ConsentDocumentRepository(dio: failing, storage: InMemoryStorage()),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(retryButton, findsOneWidget);
  });

  testWidgets('error_ko_stillShowsBundled — 한국어는 오류가 나도 번들로 동의 화면이 선다', (tester) async {
    await tester.pumpWidget(wrap(
      language: 'ko',
      overrides: [
        consentBundleProvider.overrideWith((ref) async => throw Exception('예상 못 한 예외')),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(ConsentRow), findsWidgets);
    expect(retryButton, findsNothing);
  });

  testWidgets('동의를 보낼 때 사용자가 본 약관의 언어를 함께 보낸다', (tester) async {
    final bundle = ConsentBundle(
      version: '2026-10-02',
      items: consentItems,
      source: ConsentSource.server,
      language: 'ja',
    );
    await tester.pumpWidget(wrap(
      language: 'ja',
      overrides: [consentBundleForProvider('ja').overrideWith((ref) async => bundle)],
    ));
    await tester.pumpAndSettle();

    for (final item in consentItems.where((i) => i.required)) {
      final row = find.ancestor(of: find.text(item.label), matching: find.byType(ConsentRow)).first;
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: row, matching: find.byType(AppPressable)).first);
      await tester.pumpAndSettle();
    }
    // 하단 버튼은 이 화면에 하나뿐이다. 문구는 언어마다 달라 글자로 찾지 않는다.
    await tester.tap(find.byType(ElumButton));
    await tester.pumpAndSettle();

    expect(sent?['consentLocale'], 'ja');
    expect(sent?['consentVersion'], '2026-10-02');
  });
}
```

- [ ] **Step 3: 실행해 실패를 확인한다**

Run: `cd client && flutter test test/consent_language_screen_test.dart`
Expected: FAIL — 컴파일 오류(`Key('consent-unavailable-retry')` 대상 위젯 없음은 런타임이고, `ConsentRepository.agree` 의 `language`·ARB 키가 없어 컴파일/런타임 모두 실패).

- [ ] **Step 4: ARB 에 새 문구 네 개를 더한다**

`client/lib/l10n/app_ko.arb` — 마지막 항목 뒤에 쉼표를 붙이고 아래를 더한다.

```json
  "consentUnavailableTitle": "약관에 동의해주세요",
  "@consentUnavailableTitle": {
    "description": "약관을 불러오지 못한 동의 화면의 제목. 이 언어의 약관이 아직 열리지 않았거나 네트워크 문제일 때 쓴다"
  },
  "consentUnavailableDescription": "약관을 불러오지 못했어요",
  "@consentUnavailableDescription": {
    "description": "약관을 불러오지 못한 동의 화면의 부제"
  },
  "consentUnavailableHint": "인터넷 연결을 확인하고 다시 시도해 주세요. 계속 안 되면 이 언어의 약관이 아직 준비 중일 수 있어요. 휴대폰 언어를 바꾸면 이용할 수 있어요.",
  "@consentUnavailableHint": {
    "description": "약관을 불러오지 못했을 때의 안내. 가입은 약관이 게시된 언어에서만 되므로 휴대폰 언어를 바꾸라고 알린다"
  },
  "consentUnavailableRetry": "다시 시도",
  "@consentUnavailableRetry": {
    "description": "약관을 다시 불러오는 버튼"
  }
```

`client/lib/l10n/app_en.arb` — 같은 자리에 더한다(`@키` 설명은 템플릿 ARB 에만 둔다).

```json
  "consentUnavailableTitle": "Please agree to the terms",
  "consentUnavailableDescription": "We couldn't load the terms",
  "consentUnavailableHint": "Check your internet connection and try again. If it keeps failing, the terms may not be available in this language yet. You can use the app after changing your phone's language.",
  "consentUnavailableRetry": "Try again"
```

Run: `cd client && flutter gen-l10n`
Expected: 오류 없이 `AppLocalizations.consentUnavailableRetry` 등이 생성된다(`ja`·`zh`·`es` 에는 키가 없다는 경고는 정상이다 — 계획 5 가 채운다).

- [ ] **Step 5: 위젯과 동의 요청을 쓴다**

`client/lib/features/auth/presentation/widgets/consent_unavailable_view.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_button.dart';

/// 약관을 불러오지 못했을 때의 안내와 재시도 (이슈 #521).
///
/// **읽을 수 없는 언어의 약관으로 동의받지 않는다.** 그래서 약관이 아직 열리지 않은 언어이거나
/// 네트워크 문제로 못 받았을 때, 빈 화면이나 끝나지 않는 로딩이 아니라 이유와 다시 시도할 길을 준다.
/// 약관 목록(설정)에서 쓴다. 동의 화면은 같은 문구를 헤더·하단 버튼 골격에 직접 배치한다.
class ConsentUnavailableView extends StatelessWidget {
  const ConsentUnavailableView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return Padding(
      padding: EdgeInsets.only(top: space.xl),
      child: Column(
        children: [
          Text(
            context.l10n.consentUnavailableDescription,
            textAlign: TextAlign.center,
            style: context.typo.body.copyWith(color: context.colors.textPrimary),
          ),
          SizedBox(height: space.sm),
          Text(
            context.l10n.consentUnavailableHint,
            textAlign: TextAlign.center,
            style: context.typo.body.copyWith(color: context.colors.textSecondary),
          ),
          SizedBox(height: space.xl),
          ElumButton(
            key: const Key('consent-unavailable-retry'),
            label: context.l10n.consentUnavailableRetry,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
```

`consent_repository.dart` 36~55행(`agree`)을 바꾼다.

```dart
  /// [language] 는 사용자가 **본** 약관의 언어다 (이슈 #521). 어떤 사용자가 어떤 언어의 어떤 버전에
  /// 동의했는지 증명하려는 것이다. 서버는 그 언어의 약관이 게시되지 않았으면 400 으로 막는다.
  Future<AppFailure?> agree({
    required Set<String> agreedKeys,
    required String version,
    String language = 'ko',
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/member/consents',
        data: {
          for (final field in consentFields) field: agreedKeys.contains(field),
          'consentVersion': version,
          'consentLocale': language,
        },
      );
      return null;
    } catch (e) {
      AppLogger.error('약관 동의 저장', e);
      return AppFailure.of(e);
    }
  }
```
(바로 위 `///` 설명 블록의 `[version]`·`null 이면 성공` 문단은 그대로 둔다.)

- [ ] **Step 6: 동의 화면을 고친다**

`consent_screen.dart` — import 에 더한다.

```dart
import '../../../core/l10n/l10n_context.dart';
import '../domain/consent_language.dart';
```

1. `_submit` 안의 `agree(` 호출에 인자를 더한다(`version: bundle.version,` 아래).

```dart
          // **사용자가 본 약관의 언어**다. 어떤 언어의 어떤 버전에 동의했는지가 증빙이다.
          language: bundle.language,
```

2. `build` 에서 `final bundle = ref.watch(consentBundleProvider);` 와 `child: bundle.maybeWhen(...)` 블록을 바꾼다.

```dart
    // 사용자가 보는 화면 언어로 약관을 고른다. 그 언어의 약관이 없으면 한국어로 대체하지 않는다.
    final language = consentLanguageOf(Localizations.localeOf(context));
    final bundle = ref.watch(consentBundleForProvider(language));
```
```dart
      child: bundle.maybeWhen(
        // null 이면 읽을 약관이 없는 언어다 — 동의를 받지 않고 이유와 재시도를 보여준다.
        data: (data) => data == null ? _unavailable(language) : _content(data),
        orElse: () {
          if (!bundle.hasError) return _waiting();
          // 예상 못 한 오류. 번들이 있는 언어(한국어)는 번들로, 없는 언어는 불러오지 못했다는 화면으로 간다.
          final fallback = ConsentBundle.bundledFor(language);
          return fallback == null ? _unavailable(language) : _content(fallback);
        },
      ),
```

3. `_waiting()` 다음에 새 메서드를 더한다.

```dart
  /// 읽을 약관이 없는 언어. 골격은 [_waiting] 과 같고, 하단 버튼이 재시도다.
  ///
  /// 시안이 없는 상태다(디자인 요청 중). 동의할 항목을 내지 않으므로 이 화면에서는 가입이 진행되지 않는다.
  Widget _unavailable(String language) {
    return ElumScaffold(
      bottomButton: ElumButton(
        key: const Key('consent-unavailable-retry'),
        label: context.l10n.consentUnavailableRetry,
        onPressed: () => ref.invalidate(consentBundleForProvider(language)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElumHeader(
              title: context.l10n.consentUnavailableTitle,
              description: context.l10n.consentUnavailableDescription,
            ),
            SizedBox(height: _headerToAllAgree.h),
            Text(
              context.l10n.consentUnavailableHint,
              style: context.typo.body.copyWith(color: context.colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 7: 약관 목록 화면을 고친다**

`consent_document_list_screen.dart` — import 에 더한다.

```dart
import '../domain/consent_language.dart';
import 'widgets/consent_unavailable_view.dart';
```
`build`(24~60행)의 `final bundle = ref.watch(consentBundleProvider);` 와 `child: bundle.maybeWhen(...)` 를 바꾼다.

```dart
    final language = consentLanguageOf(Localizations.localeOf(context));
    final bundle = ref.watch(consentBundleForProvider(language));
```
```dart
      child: bundle.maybeWhen(
        // null 이면 읽을 약관이 없는 언어다. 한국어로 대체하지 않고 재시도를 보여준다.
        data: (data) =>
            data == null ? _unavailable(ref, language) : _list(context, data),
        orElse: () {
          if (!bundle.hasError) return _list(context, null); // 받아 오는 동안
          final fallback = ConsentBundle.bundledFor(language);
          return fallback == null
              ? _unavailable(ref, language)
              : _list(context, fallback);
        },
      ),
```
클래스에 메서드를 더한다.

```dart
  Widget _unavailable(WidgetRef ref, String language) {
    return SingleChildScrollView(
      child: ConsentUnavailableView(
        onRetry: () => ref.invalidate(consentBundleForProvider(language)),
      ),
    );
  }
```
(`ConsentBundle.bundled` 를 직접 쓰던 줄은 위 `bundledFor` 로 대체됐다. 한국어에서는 같은 값이다.)

- [ ] **Step 8: 옛 시험의 기대 본문을 맞춘다**

`consent_payload_test.dart` 78~85행의 기대 맵에 한 줄을 더한다.

```dart
    expect(sent, {
      'termsAgreed': true,
      'privacyAgreed': true,
      'overseasTransferAgreed': true,
      'guardianConfirmed': true,
      'marketingAgreed': false,
      'consentVersion': ConsentBundle.bundled.version,
      // 사용자가 본 약관의 언어. 한국어 번들이므로 ko 다.
      'consentLocale': 'ko',
    });
```

- [ ] **Step 9: 통과를 확인한다**

Run:
```bash
cd client && flutter test test/consent_language_screen_test.dart test/consent_screen_test.dart test/consent_payload_test.dart test/consent_document_golden_test.dart test/consent_screen_golden_test.dart test/guardian_settings_test.dart test/child_elumi_settings_test.dart test/settings_conformance_test.dart test/multi_guardian_entry_test.dart test/image_style_settings_test.dart
flutter analyze
```
Expected: 신규 6건 PASS, 기존 시험 전부 PASS(한국어 경로는 `consentBundleProvider` 를 그대로 지나므로 골든·대조가 바뀌지 않는다), analyze 0건. 골든이 어긋나면 `ko` 동작이 바뀐 것이다 — 골든을 갱신하지 말고 원인을 고친다.

- [ ] **Step 10: 커밋 (`/pro-commit`)**

```bash
git add client/lib/features/auth/presentation/widgets/consent_unavailable_view.dart \
  client/lib/features/auth/presentation/consent_screen.dart \
  client/lib/features/auth/presentation/consent_document_list_screen.dart \
  client/lib/features/auth/data/consent_repository.dart \
  client/lib/l10n/app_ko.arb client/lib/l10n/app_en.arb \
  client/test/consent_language_screen_test.dart client/test/consent_payload_test.dart
```
(`flutter gen-l10n` 이 만든 파일이 추적 대상이면 그 경로도 `git status` 로 확인해 명시해서 더한다.)

---

## Task 12: 외부 게시 페이지 검사의 언어별 확장

**Files:**
- Modify: `tool/check_public_pages.py:1-163` (전체 교체)
- Create: `tool/test_check_public_pages.py`
- Modify: `.github/workflows/PROJECT-ELUM-PUBLIC-PAGES-CHECK.yaml:1-62` (경로·단계)

**Interfaces:**
- Consumes: 서버 `consent/<언어>/*.txt` 폴더 구조(Task 2)
- Produces:
  - `check_public_pages.run_checks(local: Path | None, consent_root: Path) -> tuple[int, list[str]]` — (검사한 페이지 수, 문제 목록)
  - `check_public_pages.open_locales(consent_root: Path) -> list[str]` — `consent/<언어>/` 폴더가 있는 언어(`ko` 먼저)
  - `check_public_pages.page_name(locale: str, name: str) -> str` — `ko` 는 `index.html`, 그 밖은 `en/index.html`
  - CLI 는 그대로(`--dir <경로>`), 종료 코드 0/1

**현재 검사 방식 (읽은 대로).** 스크립트는 게시 주소 `https://twin-fang.github.io/elum/{index,privacy,delete}.html` 세 장을 받아(또는 `--dir` 로컬 작업본) 태그를 걷어낸 글에서 ① 사실과 다른 고지(원문을 보관하지 않는다는 문장) ② 앱에 없는 수집 항목(아이디·비밀번호) ③ 서버 `consent/overseas.txt`·`privacy.txt` 가 말하는 낱말(국외, 보호책임자)이 게시본에도 있는지 ④ 위탁 제공자(Google, OpenAI) 양쪽 ⑤ 삭제 안내 필수 요소를 본다. 모두 **한국어 낱말과 한 벌의 게시본** 을 전제한다.

**어떻게 확장하나.**
- 열린 언어 = 서버 `consent/<언어>/` 폴더가 있는 언어. `ko` 는 항상 열려 있다(없으면 문제).
- `ko` 게시본은 **지금 주소 그대로**(`/privacy.html`)다. 스토어 심사에 제출된 주소를 바꾸지 않는다. 다른 언어는 `/{언어}/privacy.html` 등이다.
- 열린 언어마다 세 장이 모두 있어야 한다. 없으면 문제다 — 약관을 열었는데 게시본이 없는 상태다.
- **언어와 무관하게 볼 수 있는 검사**(위탁 제공자 이름 Google·OpenAI, 삭제 페이지의 메일 주소 `@`)는 모든 열린 언어에 건다.
- **한국어 낱말에 기대는 검사**(사실과 다른 고지, 아이디·비밀번호, `국외`·`보호책임자`·`회원탈퇴`·`남는`)는 `ko` 에만 건다. 다른 언어는 번역이 납품될 때 그 언어의 낱말을 `NEEDLES`·`DELETE_NEEDLES` 표에 더한다(번역 작업의 일부 — 계획 5·7). 표가 비어 있어도 위의 언어 무관 검사와 존재 검사는 돈다.

- [ ] **Step 1: 실패하는 시험을 쓴다**

`tool/test_check_public_pages.py`:

```python
#!/usr/bin/env python3
"""check_public_pages 의 언어별 검사 시험 (이슈 #521).

    cd tool && python3 -m unittest test_check_public_pages -v

게시본은 임시 폴더에 만든다(--dir 모드). 네트워크에 나가지 않는다.
"""

from __future__ import annotations

import pathlib
import tempfile
import unittest

import check_public_pages as chk

KO_PRIVACY = "개인정보 보호책임자 국외 이전 Google OpenAI"
KO_INDEX = "이룸 소개"
KO_DELETE = "앱에서 회원탈퇴 하거나 help@example.com 로 요청해요. 남는 데이터는 이렇게 처리해요"


class PublicPagesCheck(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        root = pathlib.Path(self._tmp.name)
        self.consent = root / "consent"
        self.pages = root / "pages"
        self.consent.mkdir()
        self.pages.mkdir()

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def write(self, path: pathlib.Path, text: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def make_ko(self) -> None:
        self.write(self.consent / "ko" / "privacy.txt", KO_PRIVACY)
        self.write(self.consent / "ko" / "overseas.txt", "국외 이전")
        self.write(self.pages / "index.html", f"<p>{KO_INDEX}</p>")
        self.write(self.pages / "privacy.html", f"<p>{KO_PRIVACY}</p>")
        self.write(self.pages / "delete.html", f"<p>{KO_DELETE}</p>")

    def make_en(self, privacy: str = "Privacy policy. Providers: Google, OpenAI",
                delete: str = "Delete in the app or write to help@example.com") -> None:
        self.write(self.consent / "en" / "privacy.txt", "Privacy policy. Google OpenAI")
        self.write(self.pages / "en" / "index.html", "<p>Elum</p>")
        self.write(self.pages / "en" / "privacy.html", f"<p>{privacy}</p>")
        self.write(self.pages / "en" / "delete.html", f"<p>{delete}</p>")

    def run_checks(self) -> list[str]:
        _, problems = chk.run_checks(self.pages, self.consent)
        return problems

    def test_ko_only_passes(self) -> None:
        self.make_ko()
        self.assertEqual(self.run_checks(), [])

    def test_missing_ko_consent_folder_is_a_problem(self) -> None:
        self.write(self.pages / "index.html", "x")
        self.assertTrue(any("consent/ko" in p for p in self.run_checks()))

    def test_ko_missing_page_is_reported(self) -> None:
        self.make_ko()
        (self.pages / "privacy.html").unlink()
        self.assertTrue(any("privacy.html" in p for p in self.run_checks()))

    def test_ko_untrue_claim_still_caught(self) -> None:
        self.make_ko()
        self.write(self.pages / "index.html", "<p>원문은 따로 보관하지 않아요</p>")
        self.assertTrue(any("원문은 따로 보관하지 않" in p for p in self.run_checks()))

    def test_ko_page_address_stays_at_root(self) -> None:
        # 스토어에 제출된 주소(/privacy.html)를 바꾸지 않는다.
        self.assertEqual(chk.page_name("ko", "privacy.html"), "privacy.html")
        self.assertEqual(chk.page_name("en", "privacy.html"), "en/privacy.html")
        self.assertEqual(chk.page_name("zh", "delete.html"), "zh/delete.html")

    def test_open_locales_follow_consent_folders(self) -> None:
        self.make_ko()
        self.make_en()
        self.assertEqual(chk.open_locales(self.consent), ["ko", "en"])

    def test_opened_language_without_pages_is_reported_per_page(self) -> None:
        # 약관 폴더가 생겼는데 게시본이 없다 — 약관을 열었는데 보여줄 방침이 없는 상태.
        self.make_ko()
        self.write(self.consent / "en" / "privacy.txt", "x")
        problems = self.run_checks()
        for name in ("en/index.html", "en/privacy.html", "en/delete.html"):
            self.assertTrue(any(name in p for p in problems), name)

    def test_language_independent_checks_apply_to_every_open_language(self) -> None:
        self.make_ko()
        self.make_en(privacy="Privacy policy. Providers: Google")  # OpenAI 가 빠졌다
        problems = self.run_checks()
        self.assertTrue(any("[en]" in p and "OpenAI" in p for p in problems), problems)

    def test_delete_page_needs_a_contact_in_every_language(self) -> None:
        self.make_ko()
        self.make_en(delete="Delete in the app")  # 메일 주소가 없다
        self.assertTrue(any("[en]" in p and "메일" in p for p in self.run_checks()))

    def test_korean_needles_are_not_demanded_of_other_languages(self) -> None:
        # 영어 게시본에 '보호책임자' 같은 한국어 낱말이 없어도 문제가 아니다.
        self.make_ko()
        self.make_en()
        self.assertEqual(self.run_checks(), [])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실행해 실패를 확인한다**

Run: `cd tool && python3 -m unittest test_check_public_pages -v`
Expected: FAIL — `AttributeError: module 'check_public_pages' has no attribute 'run_checks'`(또는 `page_name`).

- [ ] **Step 3: 검사기를 교체한다**

`tool/check_public_pages.py` 전체를 아래로 바꾼다.

```python
#!/usr/bin/env python3
"""게시된 공개 페이지와 서버 동의 문서가 어긋나지 않는지 본다.

**왜 필요한가.** 방침이 두 곳에 산다 — 게시 페이지(`gh-pages`)와 서버가 들고 있는
동의 문서(`server/src/main/resources/consent/`). 한쪽만 고치면 조용히 어긋난다.
실제로 그렇게 어긋났다: 지원 페이지는 "원문은 따로 보관하지 않아요"라고 적어 두었는데
서버는 원문을 저장하고 방침에도 보관한다고 적혀 있었다. **같은 사이트의 두 페이지가
개인정보 처리에 대해 서로 다른 말을 했고 그중 하나가 사실과 달랐다** (#288).

사람이 두 곳을 눈으로 맞추는 일은 반드시 빠진다. 그래서 값으로 묻는다.

    python3 tool/check_public_pages.py              # 게시된 주소를 받아 본다
    python3 tool/check_public_pages.py --dir <경로>  # 로컬 gh-pages 작업본을 본다

어긋나면 종료 코드 1이다.

## 언어 (이슈 #521)

**열린 언어** = 서버 `consent/<언어>/` 폴더가 있는 언어다. 한국어(`ko`)는 늘 열려 있다.
다른 언어를 열 때는 법무가 확인한 본문을 이 폴더에 같이 커밋하고, 게시본을 올린다 —
폴더가 생기는 순간 이 검사가 게시본의 존재를 요구한다.

- 한국어 게시본은 **지금 주소 그대로**(`/privacy.html`)다. 스토어에 제출된 주소를 바꾸지 않는다.
  다른 언어는 `/{언어}/privacy.html` 처럼 언어 폴더 아래다.
- 열린 언어마다 세 장(`index` · `privacy` · `delete`)이 모두 있어야 한다.
- 언어와 무관하게 볼 수 있는 검사(위탁 제공자 이름, 삭제 페이지의 메일 주소)는 모든 열린 언어에 건다.
- 한국어 낱말에 기대는 검사는 `ko` 에만 건다. 다른 언어는 번역이 납품될 때 그 언어의 낱말을
  `NEEDLES`·`DELETE_NEEDLES` 에 더한다(번역 작업의 일부). 표가 비어 있어도 존재·언어 무관 검사는 돈다.
"""

from __future__ import annotations

import argparse
import html
import pathlib
import re
import sys
import urllib.request

BASE = "https://twin-fang.github.io/elum"
CONSENT = pathlib.Path(__file__).resolve().parent.parent / "server/src/main/resources/consent"

PAGES = ("index.html", "privacy.html", "delete.html")

DEFAULT_LOCALE = "ko"
LOCALES = ("ko", "en", "ja", "zh", "es")

# (서버 문서, 게시 페이지, 서버 문서에 있으면 게시본에도 있어야 하는 낱말, 사람이 읽는 이름)
# 한국어 낱말이다. 다른 언어는 번역이 납품될 때 그 언어의 낱말을 더한다.
NEEDLES: dict[str, list[tuple[str, str, str, str]]] = {
    "ko": [
        ("overseas.txt", "privacy.html", "국외", "국외 이전 고지"),
        ("privacy.txt", "privacy.html", "보호책임자", "개인정보 보호책임자"),
    ],
}

# (delete.html 에 있어야 하는 낱말, 사람이 읽는 이름). 한국어 낱말이다.
DELETE_NEEDLES: dict[str, list[tuple[str, str]]] = {
    "ko": [
        ("회원탈퇴", "앱 안에서 지우는 경로"),
        ("남는", "남는 데이터 설명"),
    ],
}

# 위탁 제공자 이름은 어느 언어에서나 같은 글자다.
PROVIDERS = ("Google", "OpenAI")


def page_name(locale: str, name: str) -> str:
    """게시본의 상대 경로. 한국어는 루트(스토어에 제출된 주소), 나머지는 언어 폴더 아래다."""
    return name if locale == DEFAULT_LOCALE else f"{locale}/{name}"


def open_locales(consent_root: pathlib.Path) -> list[str]:
    """서버 `consent/<언어>/` 폴더가 있는 언어. 한국어는 늘 첫 번째다(폴더가 없어도 검사 대상)."""
    found = [loc for loc in LOCALES if (consent_root / loc).is_dir()]
    return [DEFAULT_LOCALE] + [loc for loc in found if loc != DEFAULT_LOCALE]


def strip_tags(raw: str) -> str:
    raw = re.sub(r"<(script|style).*?</\1>", " ", raw, flags=re.S)
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", raw)))


def load(name: str, local: pathlib.Path | None) -> str | None:
    """페이지 한 장을 읽는다. 없으면 None — 그 자체가 결함일 수 있다."""
    if local:
        f = local / name
        return f.read_text(encoding="utf-8") if f.exists() else None
    try:
        with urllib.request.urlopen(f"{BASE}/{name}", timeout=15) as r:
            return r.read().decode("utf-8")
    except Exception:
        return None


def check_locale(
    locale: str, pages: dict[str, str], consent_dir: pathlib.Path
) -> list[str]:
    """한 언어의 게시본을 서버 문서와 맞대 본다. [pages] 의 키는 `index.html` 같은 짧은 이름이다."""
    tag = "" if locale == DEFAULT_LOCALE else f"[{locale}] "
    problems: list[str] = []

    if locale == DEFAULT_LOCALE:
        # 1) 사실과 다른 고지가 남아 있지 않은가.
        #    서버 `Routine.rawInputText` 는 nullable=false 라 원문은 저장된다.
        if "index.html" in pages and "원문은 따로 보관하지 않" in pages["index.html"]:
            problems.append(
                "index.html 이 '원문은 따로 보관하지 않아요'라고 적고 있다 — "
                "서버는 원문을 저장한다. 사실과 다른 고지다"
            )

        # 2) 앱에 없는 것을 수집한다고 적지 않았는가. 소셜 로그인만 지원한다.
        if "privacy.html" in pages and re.search(r"아이디[,·]\s*비밀번호", pages["privacy.html"]):
            problems.append("privacy.html 에 '아이디, 비밀번호' 가 있다 — 자체 로그인이 없다")

    # 3) 서버 동의 문서가 말하는 것을 게시본도 말하는가. (낱말은 언어별 표)
    for src, page, needle, label in NEEDLES.get(locale, []):
        doc = consent_dir / src
        if not doc.exists() or page not in pages:
            continue
        if needle in doc.read_text(encoding="utf-8") and needle not in pages[page]:
            problems.append(f"{tag}서버 문서에는 {label}가 있는데 {page} 에는 없다")

    # 4) 위탁 제공자가 양쪽에 같이 적혀 있는가. 어느 언어에서나 같은 글자라 모든 언어에 건다.
    #    실제로 보내는 곳과 알린 곳이 다르면 그 자체가 지적 사유다.
    doc = consent_dir / "privacy.txt"
    if doc.exists() and "privacy.html" in pages:
        text = doc.read_text(encoding="utf-8")
        for provider in PROVIDERS:
            if provider in text and provider not in pages["privacy.html"]:
                problems.append(f"{tag}서버 문서에는 {provider} 가 있는데 privacy.html 에는 없다")

    # 5) 삭제 안내가 Play 가 요구하는 것을 담고 있는가.
    if "delete.html" in pages:
        page = pages["delete.html"]
        # 메일로 요청하는 방법 — 어느 언어에서나 메일 주소가 있다.
        if "@" not in page:
            problems.append(f"{tag}delete.html 에 메일로 요청하는 방법 가 없다")
        for needle, label in DELETE_NEEDLES.get(locale, []):
            if needle not in page:
                problems.append(f"{tag}delete.html 에 {label} 가 없다")

    return problems


def run_checks(
    local: pathlib.Path | None, consent_root: pathlib.Path
) -> tuple[int, list[str]]:
    """열린 언어마다 게시본을 읽어 맞대 본다. (읽은 페이지 수, 문제 목록)."""
    problems: list[str] = []
    seen = 0

    if not (consent_root / DEFAULT_LOCALE).is_dir():
        problems.append(
            f"서버 동의 문서 폴더 consent/{DEFAULT_LOCALE} 가 없다 — 한국어 본문의 원본 자리다"
        )

    for locale in open_locales(consent_root):
        pages: dict[str, str] = {}
        for name in PAGES:
            full = page_name(locale, name)
            raw = load(full, local)
            if raw is None:
                problems.append(
                    f"{full} 가 없다 — "
                    + ("스토어 선언이 이 주소를 가리킨다" if locale == DEFAULT_LOCALE
                       else f"{locale} 약관을 열었는데 게시본이 없다")
                )
                continue
            pages[name] = strip_tags(raw)
            seen += 1
        problems.extend(check_locale(locale, pages, consent_root / locale))

    return seen, problems


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", type=pathlib.Path, help="로컬 gh-pages 작업본 경로")
    args = ap.parse_args()

    seen, problems = run_checks(args.dir, CONSENT)

    if problems:
        print("공개 페이지가 어긋난다\n")
        for p in problems:
            print(f"  ⚠️  {p}")
        return 1

    locales = ", ".join(open_locales(CONSENT))
    print(f"공개 페이지 {seen}장 ({locales}) — 어긋난 곳 없음")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

> **알려진 한계.** 한국어 검사는 `ko` 폴더 안의 파일 이름을 `NEEDLES` 가 직접 부른다(`overseas.txt`·`privacy.txt`). 다른 언어는 같은 이름의 파일을 자기 폴더에 둔다는 전제다(Task 2 의 `ConsentKey#bodyFile` 이 모든 언어에서 같은 이름이라 같은 규칙이다).

- [ ] **Step 4: 통과를 확인한다**

Run: `cd tool && python3 -m unittest test_check_public_pages -v`
Expected: PASS (10건).

그리고 실제 게시본에 한국어 검사가 그대로 도는지 본다.

Run: `python3 tool/check_public_pages.py`
Expected: `공개 페이지 3장 (ko) — 어긋난 곳 없음`(종료 코드 0). 네트워크가 없으면 `index.html 가 없다` 가 나온다 — 그것도 기존과 같은 동작이다.

- [ ] **Step 5: 워크플로를 고친다**

`.github/workflows/PROJECT-ELUM-PUBLIC-PAGES-CHECK.yaml`:

1. 머리 주석(1~24행) 끝(`# ====` 줄 위)에 문단을 더한다.

```yaml
#
# 언어 (이슈 #521)
# - 서버 consent/<언어>/ 폴더가 있는 언어는 열린 언어다. 열린 언어마다 게시본 세 장이 있어야 한다.
#   한국어는 /privacy.html 그대로, 다른 언어는 /{언어}/privacy.html 등이다.
# - 다른 언어를 열 때: 법무가 확인한 본문을 consent/<언어>/ 에 커밋하고 게시본을 올린다.
#   그 전에 폴더를 만들면 이 검사가 게시본 없음으로 실패한다(의도된 순서 강제다).
```

2. 두 곳의 `paths`(28~35행)에 시험 파일을 더한다.

```yaml
    paths:
      - 'server/src/main/resources/consent/**'
      - 'tool/check_public_pages.py'
      - 'tool/test_check_public_pages.py'
```
(`push` 와 `pull_request` 둘 다. `consent/**` 는 언어 하위 폴더까지 잡는다.)

3. 단계(55~62행)의 마지막 단계 앞에 시험 단계를 더한다.

```yaml
      - name: 검사기 자체를 시험한다
        run: python3 -m unittest discover -s tool -p 'test_check_public_pages.py' -v

      - name: 게시본과 서버 문서를 맞대본다
        run: python3 tool/check_public_pages.py
```

- [ ] **Step 6: 워크플로 문법을 확인한다**

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/PROJECT-ELUM-PUBLIC-PAGES-CHECK.yaml')); print('ok')"`
Expected: `ok`. (PyYAML 이 없으면 `pip3 install pyyaml` 후 다시.)

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add tool/check_public_pages.py tool/test_check_public_pages.py \
  .github/workflows/PROJECT-ELUM-PUBLIC-PAGES-CHECK.yaml
```

---

## Task 13: 통합 검증과 정리

**Files:**
- 소스는 고치지 않는다. 문제가 나오면 해당 Task 로 돌아가 고친다.
- 기록: 이슈 #521 댓글(`/pro-github`), 디자인 요청 이슈(`/pro-design-brief`)

**Interfaces:**
- Consumes: Task 1~12 전부
- Produces: 검증 근거(명령 출력)

- [ ] **Step 1: 서버 전체 시험**

Run: `cd server && ./gradlew test`
Expected: PASS. 이 계획이 더한 시험 클래스가 모두 돈다 — `ConsentLocaleMigrationTest`, `ConsentDocumentInitializerTest`, `ConsentDocumentServiceLocaleTest`, `ConsentControllerTest`, `MemberServiceTest`(신규 5건), `NoticeTranslationMigrationTest`, `AppNoticeTranslationTest`, `AppNoticeTargetCountriesTest`, `NoticeLocaleTest`, `NoticeCountryTest`, `NoticeControllerTest`, `NoticeTextsFormTest`, `AdminConsent*Test`, `AdminNotice*Test`, `NoticePreviewScriptTest`, 그리고 기존 `MigrationRollbackContractTest`·`AdminTemplateTagBalanceTest`.

- [ ] **Step 2: 클라이언트 전체 시험과 분석**

Run: `cd client && flutter analyze && flutter test`
Expected: analyze 0건, 테스트 전부 PASS(골든·시안 대조 포함). 이 계획은 한국어 화면을 바꾸지 않으므로 **골든을 갱신하지 않는다.** 어긋나면 원인을 고친다.

- [ ] **Step 3: 게시 페이지 검사기 시험**

Run: `cd tool && python3 -m unittest test_check_public_pages -v`
Expected: PASS (10건).

- [ ] **Step 4: 미리보기 글꼴이 스페인어 부호를 담고 있는지 확인한다 (Task 9 의 `FONT_LACKING_LANGS` 근거)**

Run:
```bash
python3 - <<'PY'
from fontTools.ttLib import TTFont
f = TTFont("server/src/main/resources/static/admin/vendor/fonts/Pretendard-Regular.subset.woff")
cmap = f.getBestCmap()
need = "áéíóúüñÁÉÍÓÚÜÑ¿¡«»—’“”…"
print("missing:", [c for c in need if ord(c) not in cmap])
print("hiragana:", 0x3042 in cmap, "han:", 0x4E2D in cmap)
PY
```
Expected: `missing: []`, `hiragana: False han: False`. `missing` 이 비어 있지 않으면 스페인어도 글꼴 안내 대상이다 — `notice-preview.js` 의 `FONT_LACKING_LANGS` 에 `'es'` 를 더한다. (`pip3 install fonttools` 가 필요할 수 있다. 2026-10-02 작성 시점의 결과는 위와 같았다.)

- [ ] **Step 5: `ko` 불변을 응답으로 확인한다 (로컬 서버, `/pro-launch`)**

로컬 서버를 띄워(로컬 DB 리허설 순서: develop 기동 → V 적용 → 새 코드 기동, AI 키는 가짜) 아래를 확인한다. `<host>` 는 로컬 주소다.

```bash
# 헤더 없는 옛 앱 — 이전과 같은 본문, 언어 헤더만 더해진다
curl -s -D - "http://<host>/api/consents/documents" -o /tmp/consent-ko.json | grep -i "content-language\|vary"
python3 -c "import json; d=json.load(open('/tmp/consent-ko.json')); print(d['version'], [x['key'] for x in d['documents']])"
# 게시되지 않은 언어 — 200, 빈 목록, 대체 없음
curl -s -D - -H "Accept-Language: ja" "http://<host>/api/consents/documents" | head -20
# 공지 — Vary 가 붙는다
curl -s -D - -H "Accept-Language: en" "http://<host>/api/app/notices?platform=IOS" | grep -i "vary\|cache-control"
# 대상 국가 — 관리자 /admin/notices/new 에서 대상 국가를 JP 로, 켠 채 저장한 공지가 하나 있다고 하자(로컬 DB)
curl -s "http://<host>/api/app/notices?platform=IOS" | python3 -c "import sys,json; print([n['title'] for n in json.load(sys.stdin)['notices']])"
curl -s -H "X-Elum-Region: JP" "http://<host>/api/app/notices?platform=IOS" | python3 -c "import sys,json; print([n['title'] for n in json.load(sys.stdin)['notices']])"
curl -s -H "X-Elum-Region: japan" "http://<host>/api/app/notices?platform=IOS" | python3 -c "import sys,json; print([n['title'] for n in json.load(sys.stdin)['notices']])"
curl -s -D - -H "X-Elum-Region: JP" "http://<host>/api/app/notices?platform=IOS" -o /dev/null | grep -i "vary"
```
Expected: 첫째 — `Content-Language: ko`, `Vary: Accept-Language`, 버전·키 다섯 개가 이전과 같다. 둘째 — `{"version":"","documents":[]}` 와 `Content-Language: ja`. 셋째 — `Vary: Accept-Language, X-Elum-Region` 와 `Cache-Control: max-age=60`. 넷째 — 헤더 없음(= `KR`)에는 그 공지가 **없고**(기존 공지는 그대로), `JP` 에는 **있고**, 형식이 틀린 `japan`(국가 미상)에는 **없다**. 마지막 줄은 `Vary` 에 `X-Elum-Region` 이 있다.

- [ ] **Step 6: 게시 → 가입 흐름을 한 번 밟는다 (`/pro-agent-test`)**

1. 관리자 `/admin/consents?locale=en` 에서 필수 4종을 "게시하기"로 올린다(시험용 문구라도 좋다 — 로컬 DB 다). 네 번째에서 "이 언어가 열렸습니다" 안내가 뜬다.
2. `curl -H "Accept-Language: en" .../api/consents/documents` 가 영어 문서 4건을 준다.
3. 영어 휴대폰(에뮬레이터 언어 en) 앱의 동의 화면이 **약관을 불러오지 못했어요**(번들 `en` 이 없으므로 서버 응답이 오기 전까지) → 서버에서 받으면 동의 화면이 서고, 동의 후 `member.consent_locale = 'en'` 이다(`select consent_locale, consent_version from member where id = ...`).
4. 일본어로 바꾼 휴대폰은 게시 전이므로 "불러오지 못했어요 + 다시 시도"이고, 재시도해도 같다. **빈 화면·끝나지 않는 로딩이 없다.**
5. `curl -X POST .../api/member/consents -H "Accept-Language: ja" ...`(로그인 토큰 필요) 가 400 `CONSENT_LOCALE_NOT_PUBLISHED` 다.

Expected: 다섯 가지 모두 그대로. 앱 상호작용은 `/pro-launch` 의 시뮬레이터·에뮬레이터 도구로 하고 raw 좌표 조작은 하지 않는다. 로컬에서 쓴 시험 문서는 로컬 DB 에만 있다(운영 DB 는 배포로 덮이지 않으며 운영 약관 갱신은 관리자 화면에서만 한다).

- [ ] **Step 7: 디자인 요청을 올린다 (`/pro-design-brief`)**

"약관을 불러오지 못했어요" 상태(동의 화면·설정의 약관 목록)는 시안이 없다. 두 화면의 이 상태를 캡처해 디자인 이슈로 올린다(디자이너 예람). 문구 후보는 Task 11 의 ARB 네 문구를 쓴다.

Expected: 디자인 이슈 URL. 이 이슈에 시안이 나오면 Task 11 의 `ConsentUnavailableView`·`_unavailable` 을 시안에 맞춘다.

- [ ] **Step 8: 배포 순서와 운영 반영 메모를 이슈에 남긴다 (`/pro-github`)**

이슈 #521 에 댓글로 남긴다(`/pro-report` 로 완료 보고서는 별도).

- **서버를 먼저 배포한다.** 헤더 없는 옛 앱은 `ko` 로 응답받고 본문 모양이 같다. V34·V35 는 추가 위주다(다른 언어 약관을 게시하기 전까지는 옛 이미지로 되돌려도 돈다).
- 공지 V35 는 옛 열을 남긴다. 되돌려도 옛 서버는 마이그레이션 시점의 한국어 글을 본다.
- **대상 국가**: `X-Elum-Region` 헤더는 클라이언트(계획 1)가 보낸다. 앱을 업데이트하지 않은 사용자는 헤더가 없어 `KR` 로 판정된다 — 일본 대상 공지는 업데이트 전의 휴대폰에는 나가지 않는다(한국 사용자와 같은 취급). `target_countries` 는 NULL 허용 추가라 옛 서버 이미지로 되돌려도 돌지만, 되돌려 있는 동안에는 대상 국가를 정한 공지가 모든 국가에 보인다. 서버를 먼저 배포하고, 대상 국가를 쓰는 첫 공지는 클라이언트 릴리스가 퍼진 뒤에 올린다.
- **운영 DB 의 약관은 배포로 갱신되지 않는다.** 언어를 열 때: ① 법무 확인 본문을 `consent/<언어>/` 에 커밋(게시 페이지 검사가 요구) ② 게시본을 `/{언어}/` 에 올림 ③ 관리자 화면에서 필수 4종 "최초 게시" ④ 앱의 해당 언어 번역·프롬프트 행이 준비됐는지 확인 후 일과 생성 가능 언어를 켠다(계획 2·3·5).
- `en` 앱 번들 기본값은 법무 확인 전이라 넣지 않았다. 영어 사용자는 첫 실행에 네트워크가 있어야 약관을 읽는다.

- [ ] **Step 9: 커밋할 것이 있으면 (`/pro-commit`)**

이 Task 는 소스를 고치지 않는다. 검증 중 고친 것이 있다면 그 Task 의 파일 경로를 명시해 한 번 더 커밋한다. 푸시는 사용자가 요청할 때만 한다.
