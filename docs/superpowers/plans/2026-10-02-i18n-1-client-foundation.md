# 하위 계획 1: 클라이언트 i18n 기반

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> 이 문서는 마스터 계획(`2026-10-02-i18n-0-master.md`)의 **공통 계약 C1~C5**를 그대로 쓴다. 이름·타입·경로를 바꿀 일이 생기면 마스터를 먼저 고친다. 이 계획은 서버·AI·약관·네이티브를 건드리지 않는다.

**Goal:** 한국어 전용 Flutter 앱을 `ko` `en` `ja` `zh` `es` 다섯 언어를 받을 수 있는 구조로 바꾼다. 사용자에게 보이는 문구를 ARB로 옮기되 **`ko` 화면은 지금과 글자 하나·픽셀 하나 다르지 않다.** 번역 문구 자체는 이 계획에 없다(하위 계획 5).

**Architecture:** 화면 문구의 원본은 `client/lib/l10n/app_ko.arb`(템플릿)이고 `flutter gen-l10n` 이 `AppLocalizations` 를 만든다. 화면 언어는 OS 언어를 따르며(`resolveAppLocale`, 5개 밖이면 `en`), 앱 안 선택 화면은 없다. 위젯은 `context.l10n`, `context` 가 없는 층(도메인 getter·저장소 대체 문구·`AppFailure.hint`)은 `appL10n` 으로 문구를 얻는다. 한국어 조사·숫자 단위·날짜 조립은 ARB 안의 ICU(`select`·`plural`)와 전용 헬퍼로 옮긴다. `AcceptLanguageInterceptor` 가 모든 요청에 앱 언어를 싣는다. 이룸이 화면의 카드 글·음성이 일과 언어(`Routine.language`)를 따를 자리를 마련한다.

**Tech Stack:** Flutter 3.38 (`flutter_localizations`, `intl ^0.20.2`, `flutter gen-l10n`), Riverpod 3 (`NotifierProvider`), Dio, go_router, Freezed.

**Spec:** `docs/superpowers/specs/2026-10-02-multi-language-design.md`

## Global Constraints

- 지원 언어는 `ko` `en` `ja` `zh`(간체) `es` 다섯이다. RTL과 번체 중국어는 범위 밖이다.
- **앱 안에는 언어 선택 화면을 만들지 않는다.** 언어 강제 스위치는 개발자 도구(`core/dev`)에만 둔다.
- 대체 순서는 어디서든 **요청 언어 → `en` → `ko`** 이다.
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

마스터의 Review Focus 중 **이 계획이 소유한 줄**이다. 각 줄은 아래 Task 의 테스트로 고정한다.

- 번역이 하나도 없는 키가 화면을 깨지지 않는다. (계획 1, 2) → Task 1 `missing_key_fallback_test.dart`, Task 3 `l10n_context_test.dart`. 단, 대체 순서는 `en` 이 아니라 곧바로 `ko` 다 — 아래 "마스터·스펙과 실제 코드가 부딪힌 곳" 2번.
- 이룸이 휴대폰과 보호자 휴대폰의 언어가 다를 때 카드 글과 음성이 일과 언어를 따른다. (계획 1, 3) → Task 24 `content_locale_test.dart`, `speech_language_test.dart`.
- 번역 문자열이 길어도(스페인어) 고정 폭 위젯에서 넘치지 않는다. (계획 1, 5) → Task 8 `overflow_pilot_test.dart`(하네스 검증용 파일럿. 전수 검사는 계획 5).

마스터의 네 번째 줄(번역 파일 간 키·자리표시자 불일치를 CI 가 잡는다)은 계획 5 소유다. 이 계획은 그 검사의 **골격**(`test/l10n/arb_parity_test.dart`)만 만들고 CI 연결은 하지 않는다.

## 실측으로 확인한 것

이 계획은 `origin/develop`(`0164a36a`) 코드를 읽고, 가정이 틀릴 수 있는 곳은 임시 Flutter 프로젝트에서 실제로 돌려 확인한 뒤 썼다.

| 항목 | 실측 결과 |
| --- | --- |
| 사용자 노출 한글 리터럴 | 기준 커밋에서 **549줄 / 99개 파일**(Task 9 의 검사 도구 기준, 주석·로그·예외·정규식 제외). 이 중 개발자용 4줄(Task 9 에서 표식)과 `KoreanParticle` 4줄(Task 13)을 빼면 실제로 옮길 문구는 **541줄 / 95개 파일**이고, `app.dart` 1줄은 Task 6 에서 끝나 **Task 12~23 이 옮기는 것은 540줄 / 94개 파일**이다. 스펙의 "약 836줄 / 221개 파일"과 다르다 — 스펙은 줄 단위 정규식 집계(±10%)였고 로그·개발자 도구(111줄)·약관 번들(245줄)을 포함했다. |
| 제외한 한글 | 개발자 도구 `core/dev`(111줄), 로거(30줄), 약관 번들 `consent_documents.dart`(242줄)·약관 파서 `consent_body.dart`(하위 계획 4), 로그·예외 메시지, 정규식, `@Deprecated` 안내문 |
| 조사 | 사용 5곳(`invite_code_screen:217`, `invite_enter_screen:214`, `child_home_screen:118`, `routine.dart:92`, `reward_character.dart:35,61`) + `today_routine_section.dart:389` 의 고정 `을(를)` 1곳. 스펙의 "9곳"은 `korean_particle.dart` 정의 4줄과 사용 5곳을 합친 값으로 보인다. |
| 숫자 단위 | 15곳(`개`·`장`·`분`·`일간`·`%`·`번째`). 스펙의 "34곳"은 로그 줄을 포함한 값이다. |
| 날짜·요일 직접 조립 | 3곳: `credit_summary.dart:121-127`, `routine.dart:150`, `link_status.dart:11`. `app_notice.dart:195` 는 날짜가 아니라 `N일간` 단위다(스펙은 "5곳 이상"). |
| `fontFamily` | `app_typography.dart` 81곳 + `app_theme.dart` 1곳. 개별 `TextStyle(fontFamily:)` 는 `secured_by_dlp_badge.dart`·개발자 도구뿐이다. |
| 폰트 글리프(fontTools 로 `cmap` 조회) | **TmoneyRoundWind: 스페인어 악센트 문자(á é í ó ú ñ ü) 없음**(`¿ ¡` 는 있음), 가나 있음, 한자 0자. **Pretendard: 라틴 확장·스페인어·가나 있음, 한자 0자.** 스펙의 "한글·라틴 위주로 추정"을 확인했다 — 스페인어는 `Pretendard` 대체가 필요하고, 일본어·중국어 한자는 번들 폰트에 아예 없다. |
| 글자 수 제한 | `LengthLimitingTextInputFormatter` 가 이미 grapheme 기준이다(이모지 가족 `👨‍👩‍👧` 4개를 3글자 제한에 넣으면 3개만 남는 것을 실행해 확인). 코드 변경 없이 고정 테스트만 둔다(Task 11). |
| gen-l10n | 빠진 키는 **템플릿(`ko`) 문구로 채워진다**(생성된 `AppLocalizationsEs` 가 `ko` 문구를 그대로 가짐). `@@locale` 만 있는 빈 ARB 도 생성된다(경고만). 번역에서 쓰지 않는 템플릿 자리표시자도 허용된다. `flutter test` 는 생성 파일을 다시 만들지 **않고**(옛 파일로 돈다), `flutter pub get`·`flutter gen-l10n` 만 만든다. |
| 번역 delegate 없는 `MaterialApp` | `Localizations.of<AppLocalizations>(context, AppLocalizations)` 가 `null` 이다. `??` 로 `ko` 번들에 떨어뜨리면 기존 테스트가 그대로 돈다. |
| `ThemeData(fontFamilyFallback:)` | 위젯이 `TextStyle(fontFamily: …)` 를 직접 넘겨도 대체 글꼴이 상속된다(렌더된 `TextSpan.style.fontFamilyFallback` 으로 확인). `app_typography.dart` 81곳을 고칠 필요가 없다. |
| 테스트의 플랫폼 언어 | 테스트 기본은 `[en_US, zh_CN]` 이다. `PlatformDispatcher.instance.locales` 는 `localesTestValue` 로 바꿀 수 없고 `WidgetsBinding.instance.platformDispatcher.locales` 는 바뀐다 → 앱 코드는 후자를 쓴다. |
| 기존 테스트 | 테스트 케이스 약 2,067개(`test(`·`testWidgets(` 줄 수), 기준 커밋 메시지는 "앱 테스트 2180 통과". 골든·시안 PNG 123장. **공용 `pumpApp` 헬퍼가 없다** — 116개 파일이 `MaterialApp` 을 제각각 만든다(198곳). |
| CI | `PROJECT-FLUTTER-CI.yaml` 은 `flutter analyze` 와 빌드만 돌리고 `flutter test` 는 돌리지 않는다. |

## 마스터·스펙과 실제 코드가 부딪힌 곳

1. **"기존 테스트 헬퍼가 `ko` 로 앱을 띄우게 한다"는 성립하지 않는다.** 공용 헬퍼가 없고 116개 테스트 파일이 각자 `MaterialApp` 을 만든다. 해법: `context.l10n` 이 번역 delegate 가 없을 때 `ko` 번들로 떨어지게 한다(Task 3). 기존 테스트는 한 줄도 고치지 않고 `ko` 로 돈다. `pumpWithLocale` 은 **새 테스트용**이다(Task 8).
2. **스펙 4.1 의 "빠진 키는 `en` → `ko` 순으로 대체"를 gen-l10n 이 지원하지 않는다.** 대체는 템플릿(`ko`)으로 **곧바로** 간다. 즉 아직 번역이 없는 `es` 화면은 영어가 아니라 한국어가 나온다. 이 계획은 gen-l10n 의 동작을 그대로 쓴다(결정 D1). 언어를 여는 조건(스펙 5장 ①: 번역 파일이 모든 키를 채움)과 계획 5 의 키 일치 CI 가 이 간극을 막는다.
3. **마스터 C4 의 `devLocaleOverrideProvider`(`StateProvider<Locale?>`)** — Riverpod 3 에서 `StateProvider` 는 `flutter_riverpod/legacy.dart` 로 옮겨졌고 이 코드베이스는 `NotifierProvider` 만 쓴다. **이름은 그대로, 타입은 `NotifierProvider<DevLocaleOverrideNotifier, Locale?>`** 로 만든다(Task 4). 마스터 C4 표의 타입 표기를 이에 맞춰 고친다.
4. **마스터 C4 "조사는 언어별 문구 안에서 해결한다(코드에서 조사를 붙이지 않는다)"** — 한국어 조사는 이름 끝 글자의 받침으로 갈리는데 이름은 사용자 입력이라 ARB 만으로는 판정할 수 없다. 해법: 코드는 **판정값**(`batchimOf(name)` → `yes`/`no`)만 넘기고 조사 글자는 ARB(`{batchim, select, yes{이} other{가}}`)가 정한다. 다른 언어 ARB 는 `batchim` 을 쓰지 않아도 된다(`arb_parity_test` 의 `optionalPlaceholders`). 코드가 조사 글자를 붙이는 곳은 0곳이 된다.
5. **`SpeechService.speak` 시그니처를 바꾸면 테스트 대역 7곳이 컴파일되지 않는다**(`implements SpeechService` + `Future<bool> speak(String text)`). 3곳은 `noSuchMethod` 대역이라 영향이 없다. Task 24 가 7곳을 같이 고친다.
6. **iOS `CFBundleLocalizations`·Android 언어 선언은 계획 6 소관**인데, 이것이 없으면 실기기에서 `ko` 외 언어가 Dart 까지 오지 않을 수 있다. 이 계획의 검증은 개발자 도구 언어 강제 스위치로 한다. 계획 6 이 끝나기 전에는 **실기기에서 언어 전환을 확인하지 못했다.**
7. **글자 수 제한은 이미 grapheme 기준**이라 스펙의 "필요하면 grapheme 기준으로" 는 변경이 아니라 고정 테스트다. 서버 쪽 길이 제한은 계획 2 소관이다.
8. **미사용 코드**: `dlp_screen.dart`(라우터·다른 파일 어디서도 안 씀), `demo_cards.dart`(`CardRepositoryImpl` 이 쓰지만 `lib` 에서 `CardRepository` 를 쓰는 곳이 없고 테스트만 참조), `OAuthProvider.label`(로그에만 쓰임)은 번역 대상에서 뺐다(검사 도구의 건너뛰기 목록, 이유 기록). **삭제는 하지 않는다** — 사용자 허락이 필요하다(결정 D6).

## 결정이 필요한 항목

| # | 질문 | 이 계획의 기본 | 영향 |
| --- | --- | --- | --- |
| D1 | 번역이 빠진 언어에서 `en` 을 거치게 할 것인가 | gen-l10n 기본(`ko` 로 직행). 대안: (b) 템플릿을 `app_en.arb` 로 바꿈(마스터 C4 수정, `ko` 가 번역본이 됨), (c) 생성 전에 `en` 값을 빈 키에 채우는 스크립트 | 미번역 언어 화면이 한국어로 나옴(개발·QA 중에만 해당) |
| D2 | `context` 가 없는 층의 문구 접근 | `appL10n` 전역 통로(호출부·테스트 변경 최소). 대안: 모든 도메인 getter 가 `AppLocalizations` 를 인자로 받음 | 대안은 테스트 약 40개 파일과 호출부 수십 곳 수정 |
| D3 | 일본어·중국어 폰트 번들 | 시스템 글꼴 대체만(번들 없음). 대안: Noto Sans JP/SC 부분집합 번들 | 번들 시 앱 용량 증가(부분집합 크기는 측정 전엔 모른다), 시스템 글꼴 이름이 기기마다 달라 **실기기 확인 필요** |
| D4 | 번체 중국어가 1순위인 휴대폰 | 목록의 다음 지원 언어로(예: `[zh-TW, ko]` → `ko`), 하나도 없으면 `en` | `[zh-TW]` 단독은 스펙대로 `en` |
| D5 | 해외 사용자 로그인 수단(카카오·네이버) 노출 | 현행 유지(모든 언어에서 4종 노출) | 스펙 8장 열린 질문 |
| D6 | 미사용 코드 삭제(`dlp_screen.dart`, `demo_cards.dart`, `KoreanParticle` 확장) | 삭제하지 않고 검사 대상에서만 제외 | 삭제 시 파일 삭제 허락 필요 |
| D7 | 개발자 언어 강제 값을 저장할지 | 메모리만(앱을 다시 켜면 휴대폰 언어로 돌아감) | 저장하면 QA 가 편하지만 "강제가 남아 있다"를 잊기 쉽다 |

## `ko` 불변을 지키는 장치

문구를 옮기다 한국어가 달라지는 것이 이 계획의 가장 큰 위험이다(스펙 9장). 다섯 겹으로 막는다.

1. **기존 테스트**: `find.text('…')` 한글 의존이 1,391건(94파일)이다. 문구가 달라지면 바로 깨진다.
2. **골든·시안 PNG 123장**: 글자 모양·줄바꿈이 달라지면 깨진다. `--update-goldens` 는 쓰지 않는다. 각 Task 끝에 PNG 변경이 0건인지 확인한다.
3. **`tool/l10n_ko_audit.dart`**: `app_ko.arb` 의 모든 문구 조각이 기준 커밋(`99b65ac0`)의 소스에 **그대로** 있는지 `git grep -F` 로 확인한다. 테스트가 안 덮는 문구의 오타를 잡는다.
4. **`tool/check_hangul_literals.dart`**: 폴더별로 사용자 노출 한글 리터럴이 0줄인지 센다. 남은 곳이 곧 아직 안 옮긴 곳이다.
5. **새 ICU 문구 테스트**: 조사·단위·날짜처럼 코드가 하던 일을 ARB 가 넘겨받는 곳은 `ko` 결과가 옛 문자열과 같은지 값으로 고정한다.

기준 커밋 `99b65ac0` 은 설계 문서 커밋이고 코드는 `origin/develop`(`0164a36a`)와 같다. 구현 중에 `origin/develop` 이 앞서가도 감사 기준은 이 커밋으로 둔다.

## 공통 사항

**ARB 키 이름**(마스터 C4): camelCase, 화면 접두어. 접두어는 폴더별로 정한다.

| 영역 | 접두어 | 예 |
| --- | --- | --- |
| 공용 | `common` `failure` `date` `weekday` | `commonConfirm`, `failureHintOffline` |
| 인증 | `login` `consent` `role` | `loginKakaoButton`, `roleGuardianWord` |
| 온보딩 | `onboarding` `character` `imageStyle` `goal` | `onboardingNameTitle`, `goalStepByStep` |
| 연결 | `link` | `linkEnterTitle` |
| 프로필 | `guardians` `invite` `profile` | `guardiansTitle`, `inviteCodeTitle` |
| 크레딧 | `credit` `adReward` | `creditBlockedTitle` |
| 공지 | `notice` | `noticeHideDays` |
| 보호자 | `guardianHome` `guardianSettings` `routine` `card` `reward` `question` `pin` | `routineInputTitle`, `cardReviewMade` |
| 이룸이 | `child` `reward` | `childHomeGreeting` |

**ARB 작성 규칙**: 모든 메시지는 `app_ko.arb` 에만 추가한다(나머지 4개는 비워 둔다). 자리표시자가 있으면 `@키` 메타에 `placeholders` 와 타입을 적는다(`int` · `String`). 작은따옴표는 ICU 에서 `''` 로 쓴다. 줄바꿈은 JSON 의 `\n` 이다.

**커밋**: 각 Task 끝의 커밋은 `/pro-commit` 으로 한다(브랜치명에서 이슈 번호 `#521` 이 연결된다). `git add` 는 아래에 적힌 경로만 명시한다 — `git add -A` 금지, `Co-Authored-By` 를 쓰지 않는다. 푸시는 사용자가 요청할 때만 한다.

**worktree 에 `.env` 가 없으면** 테스트가 자산 `.env` 를 못 찾는다: `cp client/.env.example client/.env`(커밋하지 않는다, `.gitignore` 대상).

## 파일 구조

이 계획이 만드는 것. 경로는 모두 저장소 루트 기준이다.

| 경로 | 역할 |
| --- | --- |
| `client/l10n.yaml` | gen-l10n 설정(마스터 C4) |
| `client/lib/l10n/app_{ko,en,ja,zh,es}.arb` | 번역 원본. `ko` 가 템플릿, 나머지는 골격(`@@locale` 만) |
| `client/lib/l10n/app_localizations*.dart` | **생성물**. 커밋한다(`flutter gen-l10n`) |
| `client/lib/core/l10n/app_locales.dart` | `supportedAppLocales` |
| `client/lib/core/l10n/locale_policy.dart` | `resolveAppLocale` |
| `client/lib/core/l10n/l10n_context.dart` | `context.l10n`, `context.appLocale` |
| `client/lib/core/l10n/current_l10n.dart` | `appL10n`, `syncAppL10n` |
| `client/lib/core/l10n/effective_locale.dart` | `effectiveAppLocale` |
| `client/lib/core/l10n/app_l10n.dart` | `MaterialApp` 에 꽂는 상수 묶음 |
| `client/lib/core/l10n/batchim.dart` | `batchimOf` |
| `client/lib/core/l10n/date_labels.dart` | 날짜·요일 라벨 확장 |
| `client/lib/core/l10n/content_locale.dart` | `ContentLocale`, `contentLocaleOf` |
| `client/lib/core/dev/dev_locale_override.dart` | `devLocaleOverrideProvider` |
| `client/lib/core/network/accept_language_interceptor.dart` | `AcceptLanguageInterceptor` |
| `client/tool/check_hangul_literals.dart`, `client/tool/l10n_ko_audit.dart` | 검증 도구 |
| `client/test/l10n/*`, `client/test/helpers/pump_with_locale.dart` | 테스트 기반 |

---

# 1단계 — 기반 (Task 1~11)

사용자에게 변화가 없는 배선이다. 이 단계가 끝나도 `ko` 화면은 그대로이고 `en` 등은 아직 한국어로 나온다(번역이 비어 있어 템플릿으로 떨어진다).

## Task 1: 의존성·l10n 설정·ARB 골격·지원 언어 목록

**Files:**
- Modify: `client/pubspec.yaml:30-32`(dependencies 에 `flutter_localizations`·`intl` 추가), `client/pubspec.yaml:113-118`(`flutter:` 아래 `generate: true`)
- Modify: `client/pubspec.lock` (자동 갱신)
- Create: `client/l10n.yaml`
- Create: `client/lib/l10n/app_ko.arb` (템플릿 + 공용 문구 6개 시드)
- Create: `client/lib/l10n/app_en.arb`, `app_ja.arb`, `app_zh.arb`, `app_es.arb` (골격)
- Create (생성물, 커밋): `client/lib/l10n/app_localizations.dart`, `app_localizations_ko.dart`, `app_localizations_en.dart`, `app_localizations_ja.dart`, `app_localizations_zh.dart`, `app_localizations_es.dart`
- Create: `client/lib/core/l10n/app_locales.dart`
- Test: `client/test/l10n/app_locales_test.dart`, `client/test/l10n/arb_parity_test.dart`, `client/test/l10n/missing_key_fallback_test.dart`

**Interfaces:**
- Consumes: (없음)
- Produces:
  - `const supportedAppLocales = <Locale>[Locale('ko'), Locale('en'), Locale('ja'), Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'), Locale('es')]` — `package:elum/core/l10n/app_locales.dart`
  - 생성 클래스 `AppLocalizations`(`package:elum/l10n/app_localizations.dart`): `AppLocalizations.delegate`, `.localizationsDelegates`, `.supportedLocales`, `lookupAppLocalizations(Locale)`, getter `appTitle` `commonConfirm` `commonCancel` `commonClose` `commonNext` `commonRetry`

- [ ] **Step 1: 기준선을 기록한다 — 기존 테스트 개수**

```bash
cp -n client/.env.example client/.env   # .env 가 없을 때만. 커밋하지 않는다
cd client && flutter test 2>&1 | tail -3
```

Expected: `All tests passed!` 와 `+N` 개수. **N 을 이 계획 끝(Task 26)의 비교 기준으로 적어 둔다**(기준 커밋 메시지는 2180). 골든 PNG 가 `git status` 에 안 잡히는지도 본다: `git status --short client/test | grep -c png` → `0`.

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`client/test/l10n/app_locales_test.dart`

```dart
import 'package:elum/core/l10n/app_locales.dart';
import 'package:elum/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('지원 언어는 다섯이고 중국어는 간체 표기다', () {
    expect(
      supportedAppLocales.map((l) => l.toLanguageTag()).toList(),
      ['ko', 'en', 'ja', 'zh-Hans', 'es'],
    );
  });

  test('생성된 AppLocalizations 가 지원 언어 다섯을 모두 안다', () {
    expect(
      {for (final l in AppLocalizations.supportedLocales) l.languageCode},
      {for (final l in supportedAppLocales) l.languageCode},
    );
  });
}
```

`client/test/l10n/missing_key_fallback_test.dart`

```dart
import 'dart:convert';
import 'dart:io';

import 'package:elum/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 번역이 빠진 키가 화면을 깨지 않는다 (Review Focus).
///
/// gen-l10n 은 빠진 키를 템플릿(`ko`) 문구로 채운다. 스펙의 `en → ko` 순서와 달리 `ko` 로
/// 곧바로 간다(이 계획 결정 D1). 번역이 채워진 언어는 자기 문구를 주므로, **ARB 파일에 그 키가
/// 없는 언어만** 검사한다 — 번역이 들어와도 이 테스트가 깨지지 않는다.
void main() {
  test('ARB 에 키가 없는 언어는 ko 문구를 준다 — 예외도 빈 문자열도 아니다', () {
    final ko = lookupAppLocalizations(const Locale('ko'));
    for (final code in ['en', 'ja', 'zh', 'es']) {
      final arb = jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
          as Map<String, dynamic>;
      // 번역이 채워진 언어는 자기 문구를 주므로 건너뛴다 (골격 단계에서는 전부 검사된다)
      if (arb.containsKey('commonConfirm')) continue;

      final l10n = lookupAppLocalizations(Locale(code));
      expect(l10n.commonConfirm, ko.commonConfirm, reason: code);
      expect(l10n.commonConfirm, isNotEmpty, reason: code);
    }
  });
}
```

`client/test/l10n/arb_parity_test.dart` (계획 5 가 `openedLocales` 를 늘리고 CI 에 연결한다)

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ARB 언어 간 키·자리표시자 일치 검사 (골격).
///
/// **언어를 연다는 것 = 그 언어가 [openedLocales] 에 들어온다는 것**이다. 열린 언어는
/// ko 템플릿의 모든 키와 자리표시자를 빠짐없이 가져야 한다. 아직 안 연 언어는 비어 있어도
/// 된다 — 이때 gen-l10n 이 빠진 키를 ko 문구로 채우므로 화면은 깨지지 않는다.
/// 하위 계획 5 가 이 목록을 늘리고, 이 테스트를 CI 에 연결한다.
const openedLocales = <String>{'ko'};

/// ko 에만 있고 다른 언어는 쓰지 않아도 되는 자리표시자.
/// `batchim` 은 한국어 조사 선택용이다 (`core/l10n/batchim.dart`).
const optionalPlaceholders = <String>{'batchim'};

const arbDir = 'lib/l10n';
const allLocales = ['ko', 'en', 'ja', 'zh', 'es'];

Map<String, dynamic> _read(String locale) =>
    jsonDecode(File('$arbDir/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

/// 메시지 키만 (`@@locale`, `@key` 메타 제외).
Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

/// ko 메타(`@key.placeholders`)가 선언한 자리표시자 이름.
Set<String> _declared(Map<String, dynamic> ko, String key) {
  final meta = ko['@$key'];
  final ph = meta is Map ? meta['placeholders'] : null;
  return ph is Map ? ph.keys.cast<String>().toSet() : <String>{};
}

/// 문구가 자리표시자 [name] 을 쓰는가 (`{name}` 또는 ICU `{name, plural…}`).
bool _uses(String message, String name) =>
    message.contains('{$name}') || message.contains('{$name,');

void main() {
  test('5개 ARB 파일이 모두 있고 @@locale 이 파일 이름과 같다', () {
    for (final l in allLocales) {
      final f = File('$arbDir/app_$l.arb');
      expect(f.existsSync(), isTrue, reason: 'app_$l.arb 가 없다');
      expect(_read(l)['@@locale'], l, reason: 'app_$l.arb 의 @@locale 이 다르다');
    }
  });

  test('ko 문구의 자리표시자는 모두 @키 메타에 선언돼 있다', () {
    final ko = _read('ko');
    final bad = <String>[];
    final re = RegExp(r'\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?=[,}])');
    for (final k in _messageKeys(ko)) {
      final used = re.allMatches(ko[k] as String).map((m) => m.group(1)!).toSet();
      final undeclared = used.difference(_declared(ko, k));
      if (undeclared.isNotEmpty) bad.add('$k: $undeclared');
    }
    expect(bad, isEmpty, reason: '메타에 없는 자리표시자 — gen-l10n 이 거부한다');
  });

  for (final locale in allLocales.where(openedLocales.contains)) {
    if (locale == 'ko') continue;

    test('$locale — 열린 언어는 ko 의 모든 키를 가진다', () {
      final koKeys = _messageKeys(_read('ko'));
      final keys = _messageKeys(_read(locale));
      expect(koKeys.difference(keys), isEmpty, reason: '$locale 에 빠진 키');
      expect(keys.difference(koKeys), isEmpty, reason: '$locale 에만 있는 키');
    });

    test('$locale — 자리표시자를 ko 와 같이 쓴다', () {
      final ko = _read('ko');
      final other = _read(locale);
      final bad = <String>[];
      for (final k in _messageKeys(ko)) {
        final msg = other[k];
        if (msg is! String) continue; // 빠진 키는 위 테스트가 잡는다
        for (final p in _declared(ko, k).difference(optionalPlaceholders)) {
          if (!_uses(msg, p)) bad.add('$k 에서 {$p} 가 빠졌다');
        }
      }
      expect(bad, isEmpty);
    });
  }

  test('열리지 않은 언어는 비어 있거나 ko 의 부분집합이다', () {
    final koKeys = _messageKeys(_read('ko'));
    for (final l in allLocales.where((l) => !openedLocales.contains(l))) {
      expect(_messageKeys(_read(l)).difference(koKeys), isEmpty,
          reason: '$l 에 ko 에 없는 키가 있다');
    }
  });
}
```

- [ ] **Step 3: 실행해 실패를 확인한다**

Run: `cd client && flutter test test/l10n/`
Expected: **FAIL** — `app_locales.dart`·`app_localizations.dart` 를 찾을 수 없다(컴파일 오류), ARB 파일이 없다.

- [ ] **Step 4: 의존성을 추가한다**

```bash
cd client
flutter pub add flutter_localizations --sdk=flutter
flutter pub add intl:^0.20.2
```

`client/pubspec.yaml` 의 `flutter:` 섹션(113행 근처)에 생성 플래그를 켠다.

```yaml
flutter:

  # The following line ensures that the Material Icons font is
  # included with your application, so that you can use the icons in
  # the material Icons class.
  uses-material-design: true

  # gen-l10n 이 lib/l10n/*.arb 에서 AppLocalizations 를 만든다 (이슈 #521).
  generate: true
```

- [ ] **Step 5: 설정과 ARB 를 만든다**

`client/l10n.yaml` (마스터 C4 그대로)

```yaml
arb-dir: lib/l10n
template-arb-file: app_ko.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
```

`client/lib/l10n/app_ko.arb`

```json
{
  "@@locale": "ko",

  "appTitle": "이룸",
  "@appTitle": { "description": "앱 이름. 운영체제의 앱 전환 화면에 보인다." },

  "commonConfirm": "확인",
  "@commonConfirm": { "description": "팝업의 확인 버튼" },

  "commonCancel": "취소",
  "@commonCancel": { "description": "팝업·시트의 취소 버튼" },

  "commonClose": "닫기",
  "@commonClose": { "description": "팝업·시트의 닫기 버튼" },

  "commonNext": "다음",
  "@commonNext": { "description": "온보딩 등 단계 화면의 다음 버튼" },

  "commonRetry": "다시 시도",
  "@commonRetry": { "description": "실패 화면의 다시 시도 버튼" }
}
```

나머지 네 파일은 **골격**이다. 값은 영어 임시 문구가 아니라 **비워 둔다** — 번역은 하위 계획 5 가 채운다. 빠진 키는 gen-l10n 이 `ko` 문구로 채우므로 화면은 깨지지 않는다.

```json
{
  "@@locale": "en"
}
```

`app_ja.arb`·`app_zh.arb`·`app_es.arb` 도 `@@locale` 값만 `ja`·`zh`·`es` 로 바꿔 같은 모양으로 만든다.

`client/lib/core/l10n/app_locales.dart`

```dart
import 'dart:ui';

/// 앱이 화면 문구를 지원하는 언어 다섯 (스펙 4.1, 마스터 C4).
///
/// 중국어는 간체(`Hans`)만 지원한다. 번체는 범위 밖이라 [resolveAppLocale] 이 en 으로 돌린다.
const supportedAppLocales = <Locale>[
  Locale('ko'),
  Locale('en'),
  Locale('ja'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  Locale('es'),
];
```

- [ ] **Step 6: 생성하고 통과를 확인한다**

```bash
cd client && flutter gen-l10n && flutter test test/l10n/ && flutter analyze
```

Expected: gen-l10n 이 `"en": 5 untranslated message(s).` 같은 경고를 낸다(정상 — 골격이라서). 테스트 **PASS**, analyze `No issues found!`. `git status --short client/lib/l10n` 에 생성 파일 6개와 ARB 5개가 보인다.

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add client/pubspec.yaml client/pubspec.lock client/l10n.yaml client/lib/l10n client/lib/core/l10n/app_locales.dart client/test/l10n
```

## Task 2: `resolveAppLocale` — 휴대폰 언어를 앱 언어로 판정

**Files:**
- Create: `client/lib/core/l10n/locale_policy.dart`
- Test: `client/test/l10n/locale_policy_test.dart`

**Interfaces:**
- Consumes: `supportedAppLocales` (Task 1)
- Produces: `Locale resolveAppLocale(List<Locale>? preferred, Iterable<Locale> supported)` — 마스터 C4 시그니처 그대로. 반환값은 항상 `supported` 의 원소다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`client/test/l10n/locale_policy_test.dart`

```dart
import 'package:elum/core/l10n/app_locales.dart';
import 'package:elum/core/l10n/locale_policy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 휴대폰 언어 → 앱 언어 (스펙 4.1): 5개 안이면 그것, 밖이면 en. 번체 중국어는 밖이다.
void main() {
  const zhHans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
  Locale resolve(List<Locale>? phone) => resolveAppLocale(phone, supportedAppLocales);

  group('지원하는 언어', () {
    test('한국어·영어·일본어·스페인어는 지역과 무관하게 그 언어다', () {
      expect(resolve(const [Locale('ko', 'KR')]), const Locale('ko'));
      expect(resolve(const [Locale('en', 'US')]), const Locale('en'));
      expect(resolve(const [Locale('en', 'GB')]), const Locale('en'));
      expect(resolve(const [Locale('ja', 'JP')]), const Locale('ja'));
      expect(resolve(const [Locale('es', 'MX')]), const Locale('es'));
      expect(resolve(const [Locale('es', 'ES')]), const Locale('es'));
    });

    test('중국어 간체는 zh-Hans 로 돌려준다 — 스크립트가 있든 없든', () {
      expect(
        resolve(const [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans', countryCode: 'CN')]),
        zhHans,
      );
      expect(resolve(const [Locale('zh', 'CN')]), zhHans);
      expect(resolve(const [Locale('zh', 'SG')]), zhHans);
      expect(resolve(const [Locale('zh')]), zhHans);
    });
  });

  group('지원하지 않는 언어는 en', () {
    test('번체 중국어는 en 이다', () {
      expect(
        resolve(const [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW')]),
        const Locale('en'),
      );
      expect(resolve(const [Locale('zh', 'TW')]), const Locale('en'));
      expect(resolve(const [Locale('zh', 'HK')]), const Locale('en'));
      expect(resolve(const [Locale('zh', 'MO')]), const Locale('en'));
    });

    test('프랑스어·아랍어 같은 지원 밖 언어는 en 이다', () {
      expect(resolve(const [Locale('fr', 'FR')]), const Locale('en'));
      expect(resolve(const [Locale('ar', 'EG')]), const Locale('en'));
    });

    test('목록이 비었거나 null 이면 en 이다 — 앱이 죽지 않는다', () {
      expect(resolve(null), const Locale('en'));
      expect(resolve(const []), const Locale('en'));
    });
  });

  group('여러 언어를 쓰는 휴대폰', () {
    test('목록의 앞에서부터 지원하는 첫 언어를 쓴다', () {
      expect(resolve(const [Locale('pt', 'BR'), Locale('ko', 'KR')]), const Locale('ko'));
      expect(resolve(const [Locale('ja', 'JP'), Locale('ko', 'KR')]), const Locale('ja'));
    });

    test('번체 중국어가 1순위여도 다음 지원 언어가 있으면 그것을 쓴다 (결정 D4)', () {
      expect(resolve(const [Locale('zh', 'TW'), Locale('es', 'MX')]), const Locale('es'));
      // 번체만 있으면 스펙대로 en
      expect(resolve(const [Locale('zh', 'TW')]), const Locale('en'));
    });
  });
}
```

- [ ] **Step 2: 실행해 실패를 확인한다**

Run: `cd client && flutter test test/l10n/locale_policy_test.dart`
Expected: **FAIL** — `locale_policy.dart` 가 없다.

- [ ] **Step 3: 구현한다**

`client/lib/core/l10n/locale_policy.dart`

```dart
import 'dart:ui';

/// 번체 중국어 지역 — 간체만 지원하므로 이 지역의 `zh` 는 지원 밖이다.
const _traditionalChineseRegions = {'TW', 'HK', 'MO'};

/// 휴대폰 언어 목록에서 앱이 쓸 언어 하나를 고른다.
///
/// - 목록을 **앞에서부터** 보며 지원하는 첫 언어를 쓴다(OS 의 앱 언어 선택과 같은 순서).
/// - 어느 것도 지원하지 않으면 `en` 이다 (스펙 4.1).
/// - 중국어는 간체(`Hans`, 또는 스크립트 없이 `CN`·`SG`·지역 없음)만 맞는다.
///   번체(`Hant`, `TW`·`HK`·`MO`)는 지원 밖이라 다음 후보로 넘어간다.
///
/// 반환값은 항상 [supported] 의 원소다 — `zh` 는 `zh-Hans` 로 돌려준다.
Locale resolveAppLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  final byLanguage = {for (final l in supported) l.languageCode: l};
  for (final p in preferred ?? const <Locale>[]) {
    final hit = byLanguage[p.languageCode];
    if (hit == null) continue;
    if (p.languageCode == 'zh' && _isTraditionalChinese(p)) continue;
    return hit;
  }
  return byLanguage['en'] ?? const Locale('en');
}

bool _isTraditionalChinese(Locale l) {
  if (l.scriptCode == 'Hant') return true;
  if (l.scriptCode == 'Hans') return false;
  return _traditionalChineseRegions.contains(l.countryCode);
}
```

- [ ] **Step 4: 통과를 확인한다**

Run: `cd client && flutter test test/l10n/locale_policy_test.dart && flutter analyze`
Expected: **PASS**, `No issues found!`

- [ ] **Step 5: 커밋 (`/pro-commit`)**

```bash
git add client/lib/core/l10n/locale_policy.dart client/test/l10n/locale_policy_test.dart
```

## Task 3: `context.l10n` 과 `appL10n` — 문구를 얻는 두 통로

**Files:**
- Create: `client/lib/core/l10n/l10n_context.dart`, `client/lib/core/l10n/current_l10n.dart`
- Test: `client/test/l10n/l10n_context_test.dart`, `client/test/l10n/current_l10n_test.dart`

**Interfaces:**
- Consumes: `AppLocalizations`, `lookupAppLocalizations` (Task 1)
- Produces:
  - `extension L10nContext on BuildContext { AppLocalizations get l10n; Locale get appLocale; }` — 번역 delegate 가 없으면 `ko` 번들(마스터 C4 의 `l10n` getter + 이 계획의 `appLocale`)
  - `AppLocalizations get appL10n;` `void syncAppL10n(BuildContext context);` `@visibleForTesting void setAppL10nForTest([AppLocalizations? value]);`
  - `l10n_context.dart` 는 `AppLocalizations` 를 다시 export 한다(화면 파일이 import 한 줄로 끝나게).

**왜 두 통로인가.** `context.l10n` 은 `Localizations` 에 의존해 언어가 바뀌면 위젯을 다시 그린다. 하지만 도메인 getter(`AppRole.label`)·저장소 대체 문구(`RoutineSuggestion.fallback`)·`AppFailure.hint` 에는 `context` 가 없다. 이들의 호출부·테스트를 모두 고치지 않으려고(결정 D2) 마지막으로 정한 언어의 문구를 `appL10n` 으로 읽게 한다. **`appL10n` 을 읽는 getter 는 `context.l10n` 을 읽는 위젯의 `build` 안에서만 부른다** — 그래야 언어가 바뀔 때 같이 다시 그려진다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`client/test/l10n/l10n_context_test.dart`

```dart
import 'package:elum/core/l10n/app_locales.dart';
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('번역 delegate 가 없는 MaterialApp 에서도 ko 문구가 나온다 — 기존 테스트가 그대로 돈다', (tester) async {
    late String confirm;
    late Locale locale;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            confirm = context.l10n.commonConfirm;
            locale = context.appLocale;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(confirm, '확인');
    // MaterialApp 의 기본 언어는 en_US 지만 앱 언어는 ko 다 — keepWords 같은 언어 분기가 ko 로 돈다
    expect(locale, const Locale('ko'));
  });

  testWidgets('번역 delegate 가 있으면 그 언어를 쓴다', (tester) async {
    late String localeName;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: supportedAppLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            localeName = context.l10n.localeName;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(localeName, 'es');
  });

  testWidgets('번역이 빈 언어는 문구가 ko 로 채워져 화면이 깨지지 않는다', (tester) async {
    late String confirm;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        supportedLocales: supportedAppLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            confirm = context.l10n.commonConfirm;
            return const SizedBox();
          },
        ),
      ),
    );

    // 골격 단계 — ja ARB 가 비어 있다. 번역이 들어오면 이 기대를 ja 문구로 고친다.
    expect(confirm, isNotEmpty);
  });
}
```

`client/test/l10n/current_l10n_test.dart`

```dart
import 'package:elum/core/l10n/current_l10n.dart';
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(setAppL10nForTest);

  test('처음에는 ko 다 — 앱을 띄우지 않는 단위 테스트가 그대로 돈다', () {
    expect(appL10n.localeName, 'ko');
    expect(appL10n.commonConfirm, '확인');
  });

  testWidgets('syncAppL10n 은 현재 트리의 번역으로 맞춘다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: const [Locale('ko'), Locale('es')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            syncAppL10n(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(appL10n.localeName, 'es');
  });

  testWidgets('번역 delegate 가 없으면 건드리지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            syncAppL10n(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(appL10n.localeName, 'ko');
  });

  test('테스트가 통로를 직접 정할 수 있다', () {
    setAppL10nForTest(lookupAppLocalizations(const Locale('es')));
    expect(appL10n.localeName, 'es');
    setAppL10nForTest();
    expect(appL10n.localeName, 'ko');
  });
}
```

- [ ] **Step 2: 실행해 실패를 확인한다**

Run: `cd client && flutter test test/l10n/l10n_context_test.dart test/l10n/current_l10n_test.dart`
Expected: **FAIL** — 두 파일이 없다(컴파일 오류).

- [ ] **Step 3: 구현한다**

`client/lib/core/l10n/l10n_context.dart`

```dart
import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

export '../../l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  /// 화면 문구. `MaterialApp` 에 번역 delegate 가 없으면(일부 위젯 테스트) `ko` 번들로 떨어진다.
  ///
  /// 번역 로드가 실패해도 화면이 죽지 않게 하는 안전망이기도 하다 (스펙 4.1 실패 경로).
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(const Locale('ko'));

  /// 앱이 문구에 쓰는 언어. `Localizations.localeOf` 를 쓰지 않는다 — 번역 delegate 가 없는
  /// 테스트의 `MaterialApp` 은 기본 언어가 `en_US` 라서 `ko` 로 도는 기존 테스트가 달라진다.
  Locale get appLocale => Locale(l10n.localeName);
}
```

`client/lib/core/l10n/current_l10n.dart`

```dart
import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

AppLocalizations _current = lookupAppLocalizations(const Locale('ko'));

/// `context` 가 없는 층(도메인 getter·저장소의 대체 문구·`AppFailure.hint`)이 쓰는 문구 통로.
///
/// 앱이 마지막으로 정한 언어의 문구다. `MaterialApp.builder` 가 매 빌드마다 맞춘다
/// ([syncAppL10n]). 위젯 코드는 이것을 쓰지 말고 `context.l10n` 을 쓴다 — `context.l10n`
/// 만 언어가 바뀔 때 위젯을 다시 그리게 한다.
///
/// **이 값을 읽는 getter 는 `context.l10n` 을 읽는 위젯의 build 안에서만 부른다.** 그래야
/// 언어가 바뀔 때 같이 다시 그려져 옛 언어 문구가 남지 않는다.
AppLocalizations get appL10n => _current;

/// 현재 위젯 트리의 번역을 전역 통로에 맞춘다. 번역 delegate 가 없으면(일부 테스트) 건드리지 않는다.
void syncAppL10n(BuildContext context) {
  final found = Localizations.of<AppLocalizations>(context, AppLocalizations);
  if (found != null) _current = found;
}

/// 테스트가 통로를 직접 정하거나 `ko` 로 되돌린다.
@visibleForTesting
void setAppL10nForTest([AppLocalizations? value]) {
  _current = value ?? lookupAppLocalizations(const Locale('ko'));
}
```

- [ ] **Step 4: 통과를 확인한다**

Run: `cd client && flutter test test/l10n/ && flutter analyze`
Expected: **PASS**, `No issues found!`

- [ ] **Step 5: 커밋 (`/pro-commit`)**

```bash
git add client/lib/core/l10n/l10n_context.dart client/lib/core/l10n/current_l10n.dart client/test/l10n/l10n_context_test.dart client/test/l10n/current_l10n_test.dart
```

## Task 4: 개발자 도구 언어 강제 스위치

**Files:**
- Create: `client/lib/core/dev/dev_locale_override.dart`, `client/lib/core/l10n/effective_locale.dart`
- Modify: `client/lib/core/dev/dev_tools_overlay.dart` — 상단 import(1~17행), `enum _DevView`(199행), `_header()` 의 `switch`(252~260행), `_body()` 의 `switch`(296~317행), `_DevMenuState.build` 의 `화면 이동` 타일 뒤(368~373행), `_ConfirmResetView` 앞(410행 근처)에 `_LocaleView` 추가
- Test: `client/test/l10n/dev_locale_override_test.dart`, `client/test/dev_locale_menu_test.dart`

**Interfaces:**
- Consumes: `supportedAppLocales` (Task 1), `resolveAppLocale` (Task 2), `AppConfig.showDevTools`
- Produces:
  - `final devLocaleOverrideProvider = NotifierProvider<DevLocaleOverrideNotifier, Locale?>` — 마스터 C4 의 이름 그대로, 타입은 `StateProvider` 대신 `NotifierProvider`(위 "부딪힌 곳" 3번). `DevLocaleOverrideNotifier.set(Locale? locale)`
  - `Locale effectiveAppLocale({Locale? devOverride})` — 개발자 강제 → 휴대폰 언어 판정 순서

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`client/test/l10n/dev_locale_override_test.dart`

```dart
import 'package:elum/core/dev/dev_locale_override.dart';
import 'package:elum/core/l10n/effective_locale.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 언어 강제는 QA·시연 전용이다. **릴리스 빌드(개발자 도구 꺼짐)에서는 어떤 경로로도 먹지 않는다.**
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => binding.platformDispatcher.localesTestValue = const [Locale('ko', 'KR')]);
  tearDown(() {
    binding.platformDispatcher.clearLocalesTestValue();
    dotenv.loadFromString(envString: '', isOptional: true);
  });

  test('개발자 도구가 꺼져 있으면 강제 값이 들어오지 않는다', () {
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=false');
    final c = ProviderContainer();
    addTearDown(c.dispose);

    c.read(devLocaleOverrideProvider.notifier).set(const Locale('ja'));

    expect(c.read(devLocaleOverrideProvider), isNull);
  });

  test('켜져 있으면 강제 값이 저장되고 null 로 풀 수 있다', () {
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=true');
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final notifier = c.read(devLocaleOverrideProvider.notifier);

    notifier.set(const Locale('ja'));
    expect(c.read(devLocaleOverrideProvider), const Locale('ja'));

    notifier.set(null);
    expect(c.read(devLocaleOverrideProvider), isNull);
  });

  test('effectiveAppLocale: 강제가 없으면 휴대폰 언어를 따른다', () {
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=true');
    expect(effectiveAppLocale(), const Locale('ko'));

    binding.platformDispatcher.localesTestValue = const [Locale('es', 'MX')];
    expect(effectiveAppLocale(), const Locale('es'));

    binding.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
    expect(effectiveAppLocale(), const Locale('en'));
  });

  test('effectiveAppLocale: 개발자 도구가 켜져 있으면 강제가 이긴다', () {
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=true');
    expect(effectiveAppLocale(devOverride: const Locale('ja')), const Locale('ja'));
  });

  test('effectiveAppLocale: 꺼져 있으면 강제 값이 넘어와도 무시한다 — 릴리스 빌드 방어선', () {
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=false');
    expect(effectiveAppLocale(devOverride: const Locale('ja')), const Locale('ko'));
  });
}
```

`client/test/dev_locale_menu_test.dart`

```dart
import 'package:elum/core/dev/dev_locale_override.dart';
import 'package:elum/core/dev/dev_tools_overlay.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

/// 개발자 도구 패널에서 언어를 강제한다 (스펙 4.1 ④).
void main() {
  Widget subject() => ProviderScope(
    overrides: [
      testStorageOverride(),
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    ],
    child: MaterialApp(
      home: const Scaffold(body: Text('앱 화면')),
      builder: (context, child) => DevToolsOverlay(
        onNavigate: (_) {},
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );

  testWidgets('언어 강제 메뉴에서 English 를 고르면 provider 가 en 이 되고 따르기로 풀 수 있다', (tester) async {
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=true');
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bug_report));
    await tester.pumpAndSettle();
    await tester.tap(find.text('언어 강제'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.text('앱 화면')));

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(container.read(devLocaleOverrideProvider), const Locale('en'));

    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();
    expect(
      container.read(devLocaleOverrideProvider),
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    );

    await tester.tap(find.text('휴대폰 언어 따르기'));
    await tester.pumpAndSettle();
    expect(container.read(devLocaleOverrideProvider), isNull);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: 실행해 실패를 확인한다**

Run: `cd client && flutter test test/l10n/dev_locale_override_test.dart test/dev_locale_menu_test.dart`
Expected: **FAIL** — `dev_locale_override.dart`·`effective_locale.dart` 가 없고 메뉴에 `언어 강제` 가 없다.

- [ ] **Step 3: 구현한다 — provider 와 판정 함수**

`client/lib/core/dev/dev_locale_override.dart`

```dart
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// 개발자 도구의 언어 강제 값. null 이면 휴대폰 언어를 따른다.
///
/// QA·시연이 휴대폰 언어를 바꾸지 않고 다른 언어 화면을 보게 한다 (스펙 4.1 ④).
/// **메모리에만 둔다**(결정 D7) — 앱을 다시 켜면 휴대폰 언어로 돌아가, 강제가 남은 줄
/// 모르고 지나치는 일이 없다.
class DevLocaleOverrideNotifier extends Notifier<Locale?> {
  @override
  Locale? build() => null;

  /// 릴리스 빌드(개발자 도구 꺼짐)에서는 어떤 경로로 불려도 무시한다.
  void set(Locale? locale) {
    state = AppConfig.showDevTools ? locale : null;
  }
}

final devLocaleOverrideProvider =
    NotifierProvider<DevLocaleOverrideNotifier, Locale?>(
      DevLocaleOverrideNotifier.new,
    );
```

`client/lib/core/l10n/effective_locale.dart`

```dart
import 'package:flutter/widgets.dart';

import '../config/app_config.dart';
import 'app_locales.dart';
import 'locale_policy.dart';

/// 지금 앱이 쓰는 언어 — 개발자 강제 → 휴대폰 언어 순서로 판정한다.
///
/// `Accept-Language` 를 요청마다 이 함수로 만든다(OS 언어가 바뀌어도 다음 요청부터 따라간다).
/// 휴대폰 언어는 `PlatformDispatcher.instance` 가 아니라 **바인딩의 것**을 읽는다 — 테스트가
/// `localesTestValue` 로 바꿀 수 있는 쪽이다.
Locale effectiveAppLocale({Locale? devOverride}) {
  // 개발자 도구가 꺼진(릴리스) 빌드에서는 어떤 경로로 값이 들어와도 무시한다
  if (AppConfig.showDevTools && devOverride != null) return devOverride;
  return resolveAppLocale(
    WidgetsBinding.instance.platformDispatcher.locales,
    supportedAppLocales,
  );
}
```

- [ ] **Step 4: 구현한다 — 개발자 패널 메뉴**

`client/lib/core/dev/dev_tools_overlay.dart` 상단 import 에 두 줄을 더한다.

```dart
import '../l10n/app_locales.dart';
import 'dev_locale_override.dart';
```

199행의 enum 에 `locale` 을 더한다.

```dart
enum _DevView { menu, logs, status, navigate, confirmReset, confirmLogout, dump, locale }
```

`_header()` 의 switch(252~260행, 제목 문구)에도 한 줄을 더한다 — enum 이 늘면 두 switch 모두 빠짐없이 맞춰야 컴파일된다.

```dart
      _DevView.dump => '상태 덤프',
      _DevView.locale => '언어 강제',
```

`_body()` 의 switch(296~317행)에서 `_DevView.dump` 줄 앞에 한 줄을 더한다.

```dart
        _DevView.locale => const _LocaleView(),
        _DevView.dump => const _DumpView(),
```

`_DevMenuState.build` 의 `화면 이동` 타일(368~373행) 바로 뒤에 타일을 더한다.

```dart
        _Tile(
          icon: Icons.language,
          label: '언어 강제',
          subtitle: '휴대폰 언어와 무관하게 앱 언어를 고른다 (QA·시연용)',
          onTap: () => widget.onSelect(_DevView.locale),
        ),
```

`_DevMenuState` 클래스가 끝난 뒤(`/// 회원삭제 확인` 주석 앞)에 보기를 더한다.

```dart
/// 앱 언어 강제 — 휴대폰 언어를 바꾸지 않고 다른 언어 화면을 본다.
///
/// 값은 메모리에만 있다. 앱을 다시 켜면 휴대폰 언어로 돌아간다([DevLocaleOverrideNotifier]).
class _LocaleView extends ConsumerWidget {
  const _LocaleView();

  /// 각 언어가 자기 이름으로 적힌다 — 어느 언어가 켜져 있어도 찾을 수 있게.
  static const _names = {
    'ko': '한국어',
    'en': 'English',
    'ja': '日本語',
    'zh': '简体中文',
    'es': 'Español',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forced = ref.watch(devLocaleOverrideProvider);
    final notifier = ref.read(devLocaleOverrideProvider.notifier);
    return ListView(
      shrinkWrap: true,
      children: [
        _LocaleTile(
          label: '휴대폰 언어 따르기',
          selected: forced == null,
          onTap: () => notifier.set(null),
        ),
        for (final l in supportedAppLocales)
          _LocaleTile(
            label: _names[l.languageCode] ?? l.languageCode,
            selected: forced == l,
            onTap: () => notifier.set(l),
          ),
      ],
    );
  }
}

class _LocaleTile extends StatelessWidget {
  const _LocaleTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Radio 의 groupValue·onChanged 는 deprecated 라 체크 아이콘으로 고른 줄을 표시한다
    return ListTile(
      title: Text(label),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: onTap,
    );
  }
}
```

- [ ] **Step 5: 통과를 확인한다**

Run: `cd client && flutter test test/l10n/dev_locale_override_test.dart test/dev_locale_menu_test.dart test/dev_tools_overlay_test.dart && flutter analyze`
Expected: **PASS**(기존 오버레이 테스트 포함), `No issues found!`

- [ ] **Step 6: 커밋 (`/pro-commit`)**

```bash
git add client/lib/core/dev/dev_locale_override.dart client/lib/core/dev/dev_tools_overlay.dart client/lib/core/l10n/effective_locale.dart client/test/l10n/dev_locale_override_test.dart client/test/dev_locale_menu_test.dart
```

## Task 5: 언어별 대체 글꼴 (`fontFamilyFallback`)

**Files:**
- Modify: `client/lib/core/theme/app_typography.dart:92-96`(`fontFamily` 상수 아래에 `fontFamilyFallbackFor` 추가)
- Modify: `client/lib/core/theme/app_theme.dart:1-28`(`light` 를 `lightFor(Locale)` 로 일반화)
- Test: `client/test/l10n/font_fallback_test.dart`

**Interfaces:**
- Consumes: (없음)
- Produces:
  - `static List<String> AppTypography.fontFamilyFallbackFor(Locale locale)` — `ko` 는 빈 목록
  - `static ThemeData AppTheme.lightFor(Locale locale)`; `AppTheme.light` 는 `lightFor(ko)` 와 같다(기존 호출 110개 파일 173곳 그대로)

**근거(실측).** TmoneyRoundWind 에는 스페인어 악센트 문자(`á é í ó ú ñ ü`)가 없고, 번들 폰트 둘 다 한자가 0자다(가나는 있다). 그래서 `en`·`es` 는 라틴을 모두 가진 `Pretendard` 로, `ja`·`zh` 는 번들 `Pretendard`(가나) 다음에 **시스템 글꼴 이름**으로 떨어진다. 시스템 글꼴 이름은 기기마다 달라 맞지 않으면 Flutter 가 그 항목을 건너뛰고 엔진의 기본 시스템 대체로 간다 — 이 이름들이 실제 기기에서 한자를 올바른 자형(일본어/중국어)으로 그리는지는 **실기기에서 확인하지 못했다**(결정 D3, 계획 6 이후 `ja`·`zh` 출시 단계에서 확인). 번들 폰트 추가는 이 계획에서 하지 않는다.

`ko` 는 대체 목록을 비운다 — 지금 화면과 한 픽셀도 달라지지 않아야 하고, 글꼴에 없는 글자가 지금은 시스템 글꼴로 가는 것을 `Pretendard` 로 바꾸면 골든이 흔들릴 수 있다.

`app_typography.dart` 의 `fontFamily:` 81곳은 고치지 않는다. `ThemeData(fontFamilyFallback:)` 가 위젯이 직접 넘긴 `TextStyle(fontFamily: …)` 에도 상속된다(실행해 확인).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`client/test/l10n/font_fallback_test.dart`

```dart
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const zhHans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');

  group('언어별 대체 글꼴 목록', () {
    test('ko 는 비어 있다 — 기존 화면이 한 픽셀도 달라지지 않는다', () {
      expect(AppTypography.fontFamilyFallbackFor(const Locale('ko')), isEmpty);
    });

    test('en·es 는 라틴 전체를 가진 Pretendard 다 — TmoneyRoundWind 에 악센트 문자가 없다', () {
      expect(AppTypography.fontFamilyFallbackFor(const Locale('en')), ['Pretendard']);
      expect(AppTypography.fontFamilyFallbackFor(const Locale('es')), ['Pretendard']);
    });

    test('ja·zh 는 Pretendard 다음에 시스템 글꼴이 온다', () {
      final ja = AppTypography.fontFamilyFallbackFor(const Locale('ja'));
      final zh = AppTypography.fontFamilyFallbackFor(zhHans);
      expect(ja.first, 'Pretendard');
      expect(zh.first, 'Pretendard');
      expect(ja, containsAll(['Hiragino Sans', 'Noto Sans CJK JP']));
      expect(zh, containsAll(['PingFang SC', 'Noto Sans CJK SC']));
      // 일본어 자형이 중국어 화면에 섞이면 안 된다
      expect(zh, isNot(contains('Hiragino Sans')));
    });
  });

  group('테마', () {
    test('AppTheme.light 는 ko 테마다 — 대체 글꼴이 없다', () {
      expect(AppTheme.light.textTheme.bodyMedium!.fontFamilyFallback, isNull);
      expect(
        AppTheme.lightFor(const Locale('ko')).textTheme.bodyMedium!.fontFamilyFallback,
        isNull,
      );
    });

    testWidgets('es 테마는 위젯이 직접 넘긴 TextStyle 에도 대체 글꼴을 입힌다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightFor(const Locale('es')),
          home: Scaffold(
            // 81곳이 이렇게 fontFamily 를 직접 박는다 — 상속되는지가 핵심이다
            body: Text('Ñandú', style: AppTypography.standard.title),
          ),
        ),
      );

      final paragraph = tester.renderObject<RenderParagraph>(find.text('Ñandú'));
      expect(
        (paragraph.text as TextSpan).style!.fontFamilyFallback,
        ['Pretendard'],
      );
      expect((paragraph.text as TextSpan).style!.fontFamily, AppTypography.fontFamily);
    });

    testWidgets('ko 테마는 같은 위젯에 대체 글꼴을 입히지 않는다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: Text('가', style: AppTypography.standard.title)),
        ),
      );

      final paragraph = tester.renderObject<RenderParagraph>(find.text('가'));
      expect((paragraph.text as TextSpan).style!.fontFamilyFallback, isNull);
    });
  });
}
```

- [ ] **Step 2: 실행해 실패를 확인한다**

Run: `cd client && flutter test test/l10n/font_fallback_test.dart`
Expected: **FAIL** — `fontFamilyFallbackFor`·`lightFor` 가 없다.

- [ ] **Step 3: 구현한다**

`client/lib/core/theme/app_typography.dart` 92~96행(`fontFamily`·`promptFontFamily` 상수) 바로 아래에 더한다.

```dart
  /// 언어별 대체 글꼴 — 주 글꼴에 없는 글자가 이 순서로 떨어진다.
  ///
  /// 실측(fontTools 로 cmap 조회): `TmoneyRoundWind` 에는 스페인어 악센트 문자(á é í ó ú ñ ü)가
  /// 없고, `Pretendard` 에는 있다. 둘 다 한자가 없다(가나는 있다).
  /// - `ko`: 비운다. 기존 화면이 한 픽셀도 달라지면 안 된다.
  /// - `en`·`es`: Pretendard.
  /// - `ja`·`zh`: Pretendard(가나) 다음에 시스템 글꼴. 한자 자형이 일본어/중국어로 갈려서
  ///   언어마다 이름이 다르다. 이름이 기기에 없으면 Flutter 가 건너뛰고 엔진 기본 대체로 간다.
  static List<String> fontFamilyFallbackFor(Locale locale) =>
      switch (locale.languageCode) {
        'ko' => const [],
        'ja' => const ['Pretendard', 'Hiragino Sans', 'Noto Sans CJK JP'],
        'zh' => const ['Pretendard', 'PingFang SC', 'Noto Sans CJK SC'],
        _ => const ['Pretendard'],
      };
```

`client/lib/core/theme/app_theme.dart` 전체를 바꾼다.

```dart
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// ThemeData 조립.
///
/// 토큰은 ThemeExtension으로 등록하되, 표준 Material 슬롯에도 매핑한다.
/// 그래야 기본 Flutter 위젯이 별도 설정 없이 올바른 스타일로 나온다.
abstract final class AppTheme {
  /// 한국어 테마. 기존 호출부 전부가 이것을 쓴다.
  static ThemeData get light => lightFor(const Locale('ko'));

  /// [locale] 의 대체 글꼴을 입힌 테마. `ko` 는 [light] 와 같다.
  static ThemeData lightFor(Locale locale) {
    const colors = AppColors.light;
    const typo = AppTypography.standard;
    final fallback = AppTypography.fontFamilyFallbackFor(locale);

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      // 비어 있으면 null 을 넘긴다 — ko 테마가 지금과 완전히 같게 한다.
      // 위젯이 TextStyle(fontFamily:) 를 직접 넘겨도 이 값이 상속된다.
      fontFamilyFallback: fallback.isEmpty ? null : fallback,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.brandOrange,
        surface: colors.surface,
      ),
      textTheme: typo.toTextTheme(colors.textPrimary, colors.textSecondary),
      extensions: const [colors, typo, AppSpacing.standard],
    );
  }
}
```

- [ ] **Step 4: 통과를 확인한다**

Run: `cd client && flutter test test/l10n/font_fallback_test.dart test/design_token_test.dart && flutter analyze`
Expected: **PASS**, `No issues found!`

- [ ] **Step 5: 커밋 (`/pro-commit`)**

```bash
git add client/lib/core/theme/app_typography.dart client/lib/core/theme/app_theme.dart client/test/l10n/font_fallback_test.dart
```

## Task 6: `MaterialApp.router` 에 언어 배선

**Files:**
- Create: `client/lib/core/l10n/app_l10n.dart`
- Modify: `client/lib/app.dart` — import(1~22행), `_buildApp()`(117~148행)
- Test: `client/test/l10n/app_l10n_wiring_test.dart`

**Interfaces:**
- Consumes: `AppLocalizations` (Task 1), `resolveAppLocale` (Task 2), `syncAppL10n`·`context.appLocale` (Task 3), `devLocaleOverrideProvider` (Task 4), `AppTheme.lightFor` (Task 5)
- Produces: `abstract final class AppL10n { static const delegates; static const supportedLocales; static Locale? resolveLocales(List<Locale>?, Iterable<Locale>); static Widget themed(BuildContext, Widget) }` — `app.dart` 와 테스트가 **같은 상수**를 쓰게 하려는 묶음이다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`client/test/l10n/app_l10n_wiring_test.dart`

```dart
import 'package:elum/core/l10n/app_l10n.dart';
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `app.dart` 가 쓰는 [AppL10n] 상수로 앱을 띄워 휴대폰 언어 → 앱 언어를 확인한다.
void main() {
  Future<String> pumpPhone(
    WidgetTester tester,
    List<Locale> phone, {
    Locale? forced,
  }) async {
    tester.platformDispatcher.localesTestValue = phone;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    late String name;
    await tester.pumpWidget(
      MaterialApp(
        locale: forced,
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: AppL10n.delegates,
        localeListResolutionCallback: AppL10n.resolveLocales,
        home: Builder(
          builder: (context) {
            name = context.l10n.localeName;
            return const SizedBox();
          },
        ),
      ),
    );
    return name;
  }

  testWidgets('휴대폰이 한국어면 ko', (t) async => expect(await pumpPhone(t, const [Locale('ko', 'KR')]), 'ko'));
  testWidgets('스페인어(멕시코)면 es', (t) async => expect(await pumpPhone(t, const [Locale('es', 'MX')]), 'es'));
  testWidgets('중국어 간체면 zh', (t) async {
    expect(
      await pumpPhone(t, const [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans', countryCode: 'CN')]),
      'zh',
    );
  });
  testWidgets('프랑스어는 en', (t) async => expect(await pumpPhone(t, const [Locale('fr', 'FR')]), 'en'));
  testWidgets('번체 중국어는 en', (t) async => expect(await pumpPhone(t, const [Locale('zh', 'TW')]), 'en'));
  testWidgets('개발자 도구가 강제한 언어는 휴대폰 언어를 이긴다', (t) async {
    expect(await pumpPhone(t, const [Locale('ko', 'KR')], forced: const Locale('ja')), 'ja');
  });

  group('themed — 언어별 글꼴 테마', () {
    Future<List<String>?> fallbackIn(WidgetTester tester, Locale locale) async {
      List<String>? fallback;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          theme: AppTheme.light,
          supportedLocales: AppL10n.supportedLocales,
          localizationsDelegates: AppL10n.delegates,
          builder: (context, child) => AppL10n.themed(context, child!),
          home: Builder(
            builder: (context) {
              fallback = Theme.of(context).textTheme.bodyMedium!.fontFamilyFallback;
              return const SizedBox();
            },
          ),
        ),
      );
      return fallback;
    }

    testWidgets('ko 는 트리를 건드리지 않는다 — 대체 글꼴 없음', (t) async {
      expect(await fallbackIn(t, const Locale('ko')), isNull);
    });

    testWidgets('es 는 Pretendard 를 입힌다', (t) async {
      expect(await fallbackIn(t, const Locale('es')), ['Pretendard']);
    });

    testWidgets('ja 는 Pretendard 다음에 시스템 글꼴을 입힌다', (t) async {
      final fallback = await fallbackIn(t, const Locale('ja'));
      expect(fallback!.first, 'Pretendard');
      expect(fallback, contains('Hiragino Sans'));
    });
  });
}
```

- [ ] **Step 2: 실행해 실패를 확인한다**

Run: `cd client && flutter test test/l10n/app_l10n_wiring_test.dart`
Expected: **FAIL** — `app_l10n.dart` 가 없다.

- [ ] **Step 3: 구현한다**

`client/lib/core/l10n/app_l10n.dart`

```dart
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_locales.dart';
import 'l10n_context.dart';
import 'locale_policy.dart';

/// `MaterialApp.router` 에 꽂는 언어 설정 묶음.
///
/// `app.dart` 와 테스트가 **같은 값**을 쓰게 한다 — 앱 전체를 띄우지 않고도 휴대폰 언어 → 앱 언어
/// 판정을 확인할 수 있다.
abstract final class AppL10n {
  /// 번역 + Material·Widgets·Cupertino 기본 문구(날짜 선택기·복사 메뉴 등)
  static const delegates = AppLocalizations.localizationsDelegates;

  static const supportedLocales = supportedAppLocales;

  /// 휴대폰 언어 목록 → 앱 언어. 5개 밖이면 en (스펙 4.1).
  static Locale? resolveLocales(
    List<Locale>? locales,
    Iterable<Locale> supported,
  ) => resolveAppLocale(locales, supported);

  /// 앱 언어에 맞는 글꼴 테마를 입힌다. **`ko` 는 트리를 그대로 둔다** — 위젯 하나 늘지 않는다.
  ///
  /// `MaterialApp.theme` 은 언어가 정해지기 전에 고정돼 대체 글꼴을 모른다. `builder` 는
  /// `Localizations` 안쪽이라 여기서 정해진 언어를 읽을 수 있다.
  static Widget themed(BuildContext context, Widget child) {
    final locale = context.appLocale;
    if (locale.languageCode == 'ko') return child;
    return Theme(data: AppTheme.lightFor(locale), child: child);
  }
}
```

`client/lib/app.dart` — import 에 아래를 더한다(알파벳 순서를 지켜 기존 import 사이에 넣는다).

```dart
import 'core/config/app_config.dart';
import 'core/dev/dev_locale_override.dart';
import 'core/l10n/app_l10n.dart';
import 'core/l10n/current_l10n.dart';
import 'core/l10n/l10n_context.dart';
```

`_buildApp()` 을 아래로 바꾼다(`SyncTriggers`~`DevToolsOverlay` 의 안쪽 구조는 그대로다).

```dart
  Widget _buildApp() {
    // 개발자 도구가 언어를 강제했으면 그 값, 아니면 null — 휴대폰 언어를 따른다 (스펙 4.1).
    // 릴리스 빌드(개발자 도구 꺼짐)는 provider 도 null 만 갖지만 한 번 더 막는다.
    final forcedLocale =
        AppConfig.showDevTools ? ref.watch(devLocaleOverrideProvider) : null;

    return ScreenUtilInit(
      // Figma 프레임 크기(iPhone 16). 이 기준으로 .w/.h/.sp가 계산되므로
      // 화면 코드에서 Figma 좌표를 그대로 쓸 수 있다.
      designSize: const Size(393, 852),
      minTextAdapt: true,
      builder: (context, child) => MaterialApp.router(
        // 앱 이름은 운영체제 앱 전환 화면에 보인다 — 언어마다 다를 수 있어 ARB 에서 읽는다
        onGenerateTitle: (context) => context.l10n.appTitle,
        theme: AppTheme.light,
        locale: forcedLocale,
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: AppL10n.delegates,
        localeListResolutionCallback: AppL10n.resolveLocales,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
        // 개발자 도구를 모든 화면 위에 얹는다. 화면별 코드는 건드리지 않는다.
        // 플래그가 꺼지면 child를 그대로 반환해 비용이 0이다. (이슈 #13)
        builder: (context, child) {
          // context 가 없는 층(도메인 getter·저장소 대체 문구)이 쓰는 문구를 지금 언어에 맞춘다
          syncAppL10n(context);
          return AppL10n.themed(
            context,
            SyncTriggers(
              // 동기화 트리거는 라우터·오버레이와 무관하므로 가장 바깥에 둔다 (이슈 #140)
              child: AppStatusGate(
                // 점검 중이거나 너무 낮은 버전이면 여기서 화면을 대신 그린다 (이슈 #279).
                // 확인하지 못하면 그대로 통과시키므로 평소에는 비용이 없다.
                child: DevToolsOverlay(
                  // 오버레이는 GoRouter보다 위에 있어 context로 라우터를 찾지 못한다.
                  // 라우터를 들고 있는 여기서 이동 방법을 넘겨준다.
                  onNavigate: _router.go,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
```

- [ ] **Step 4: 통과를 확인한다**

Run: `cd client && flutter test test/l10n/app_l10n_wiring_test.dart test/splash_screen_test.dart test/router_redirect_test.dart && flutter analyze`
Expected: **PASS**, `No issues found!`. (`ElumApp` 자체를 띄우는 테스트는 없다 — `invite_link_flow_test.dart` 는 같은 배선을 흉내 낼 뿐이다. 실제 앱 동작은 Task 26 의 시뮬레이터 확인에서 본다.)

- [ ] **Step 5: 커밋 (`/pro-commit`)**

```bash
git add client/lib/core/l10n/app_l10n.dart client/lib/app.dart client/test/l10n/app_l10n_wiring_test.dart
```

## Task 7: `AcceptLanguageInterceptor` — 요청마다 앱 언어를 싣는다

**Files:**
- Create: `client/lib/core/network/accept_language_interceptor.dart`
- Modify: `client/lib/core/network/dio_client.dart` — import(1~17행), `dioProvider`(68~72행, `ProfileHeaderInterceptor` 앞)
- Test: `client/test/core/network/accept_language_interceptor_test.dart`, `client/test/accept_language_dio_wiring_test.dart`

**Interfaces:**
- Consumes: `effectiveAppLocale` · `devLocaleOverrideProvider` (Task 4)
- Produces: `class AcceptLanguageInterceptor extends Interceptor { AcceptLanguageInterceptor({required Locale Function() locale}); static const headerName = 'Accept-Language'; static String headerValue(Locale l); }` — 마스터 C1 형식(`ko` `en` `ja` `zh-Hans` `es`)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`client/test/core/network/accept_language_interceptor_test.dart`

```dart
import 'package:dio/dio.dart';
import 'package:elum/core/l10n/app_locales.dart';
import 'package:elum/core/network/accept_language_interceptor.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio.dart';

/// 요청마다 앱 언어를 `Accept-Language` 로 싣는다 (마스터 C1). 서버가 이것으로 문구 언어를 고른다.
void main() {
  late FakeAdapter adapter;
  var phone = const Locale('ko');

  Dio build({Map<String, Object?>? routes}) {
    adapter = FakeAdapter(routes ?? {'GET /api/ping': {'ok': true}});
    return Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter
      ..interceptors.add(AcceptLanguageInterceptor(locale: () => phone));
  }

  setUp(() => phone = const Locale('ko'));

  group('전송 값 형식 (C1)', () {
    test('ko en ja es 는 언어 코드 그대로, 중국어는 zh-Hans', () {
      expect(AcceptLanguageInterceptor.headerValue(const Locale('ko')), 'ko');
      expect(AcceptLanguageInterceptor.headerValue(const Locale('en')), 'en');
      expect(AcceptLanguageInterceptor.headerValue(const Locale('ja')), 'ja');
      expect(AcceptLanguageInterceptor.headerValue(const Locale('es')), 'es');
      expect(AcceptLanguageInterceptor.headerValue(supportedAppLocales[3]), 'zh-Hans');
    });
  });

  group('요청에 싣기', () {
    test('요청마다 지금 앱 언어를 싣는다', () async {
      final dio = build();
      await dio.get<dynamic>('/api/ping');
      expect(adapter.sentHeaders['GET /api/ping']!['Accept-Language'], 'ko');
    });

    test('앱 언어가 바뀌면 다음 요청부터 따라간다 — 값이 아니라 함수를 받는다', () async {
      final dio = build();
      await dio.get<dynamic>('/api/ping');
      phone = supportedAppLocales[3];
      await dio.get<dynamic>('/api/ping');
      expect(adapter.sentHeaders['GET /api/ping']!['Accept-Language'], 'zh-Hans');
    });

    test('호출부가 직접 정한 값은 덮지 않는다', () async {
      final dio = build();
      await dio.get<dynamic>(
        '/api/ping',
        options: Options(headers: {'accept-language': 'en'}),
      );
      final sent = adapter.sentHeaders['GET /api/ping']!;
      expect(sent['accept-language'] ?? sent['Accept-Language'], 'en');
      expect(
        sent.keys.where((k) => k.toLowerCase() == 'accept-language'),
        hasLength(1),
        reason: '대소문자만 다른 헤더가 두 개 나가면 안 된다',
      );
    });
  });
}
```

`client/test/accept_language_dio_wiring_test.dart`

```dart
import 'package:elum/core/dev/dev_locale_override.dart';
import 'package:elum/core/network/dio_client.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_dio.dart';

/// 앱이 실제로 쓰는 Dio(`dioProvider`)에 언어 헤더가 붙어 있는가.
///
/// 인터셉터 단위 테스트가 통과해도 **provider 에 안 달려 있으면** 헤더는 영영 안 나간다.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAdapter adapter;

  ProviderContainer build() {
    final c = ProviderContainer(
      overrides: [
        localStorageProvider.overrideWithValue(InMemoryStorage(onboardingCompleted: true)),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      ],
    );
    addTearDown(c.dispose);
    adapter = FakeAdapter({'GET /api/ping': {'ok': true}});
    c.read(dioProvider).httpClientAdapter = adapter;
    return c;
  }

  Future<String?> sentLanguage(ProviderContainer c) async {
    await c.read(dioProvider).get<dynamic>('/api/ping');
    return adapter.sentHeaders['GET /api/ping']!['Accept-Language'] as String?;
  }

  tearDown(() {
    binding.platformDispatcher.clearLocalesTestValue();
    dotenv.loadFromString(envString: '', isOptional: true);
  });

  test('휴대폰 언어가 요청 헤더로 나간다', () async {
    binding.platformDispatcher.localesTestValue = const [Locale('es', 'MX')];
    expect(await sentLanguage(build()), 'es');
  });

  test('중국어 간체는 zh-Hans, 지원 밖 언어는 en', () async {
    binding.platformDispatcher.localesTestValue = const [Locale('zh', 'CN')];
    expect(await sentLanguage(build()), 'zh-Hans');
    binding.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
    expect(await sentLanguage(build()), 'en');
  });

  test('개발자 도구가 강제한 언어가 이긴다', () async {
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=true');
    binding.platformDispatcher.localesTestValue = const [Locale('ko', 'KR')];
    final c = build();
    c.read(devLocaleOverrideProvider.notifier).set(const Locale('ja'));
    expect(await sentLanguage(c), 'ja');
  });

  test('개발자 도구가 꺼져 있으면 휴대폰 언어를 보낸다', () async {
    dotenv.loadFromString(envString: 'ELUM_SHOW_DEV_TOOLS=false');
    binding.platformDispatcher.localesTestValue = const [Locale('ko', 'KR')];
    final c = build();
    c.read(devLocaleOverrideProvider.notifier).set(const Locale('ja'));
    expect(await sentLanguage(c), 'ko');
  });
}
```

- [ ] **Step 2: 실행해 실패를 확인한다**

Run: `cd client && flutter test test/core/network/accept_language_interceptor_test.dart test/accept_language_dio_wiring_test.dart`
Expected: **FAIL** — `accept_language_interceptor.dart` 가 없다.

- [ ] **Step 3: 구현한다**

`client/lib/core/network/accept_language_interceptor.dart`

```dart
import 'dart:ui';

import 'package:dio/dio.dart';

/// 요청마다 앱 언어를 `Accept-Language` 로 싣는다 (공통 계약 C1).
///
/// 서버는 이 헤더로 에러 문구·폴백 질문·공지·약관의 언어를 고른다. 헤더가 없는 옛 앱은 서버가
/// `ko` 로 응답하므로 이미 배포된 앱은 영향이 없고, 새 앱만 이 값을 보낸다.
class AcceptLanguageInterceptor extends Interceptor {
  AcceptLanguageInterceptor({required this.locale});

  static const headerName = 'Accept-Language';

  /// 요청 시점의 앱 언어. OS 언어가 바뀌어도 다음 요청부터 따라가도록 값이 아니라 함수다.
  final Locale Function() locale;

  /// 내부 코드 → 전송 값. 중국어만 간체 표기(`zh-Hans`)로 보낸다.
  static String headerValue(Locale l) =>
      l.languageCode == 'zh' ? 'zh-Hans' : l.languageCode;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 호출부가 직접 정한 값(예: 약관을 다른 언어로 미리보기)은 덮지 않는다.
    // Dio 헤더는 대소문자를 가리지 않아 `accept-language` 로 넣은 값도 막아 준다.
    options.headers.putIfAbsent(headerName, () => headerValue(locale()));
    handler.next(options);
  }
}
```

`client/lib/core/network/dio_client.dart` import 에 두 줄을 더한다.

```dart
import '../dev/dev_locale_override.dart';
import '../l10n/effective_locale.dart';
import 'accept_language_interceptor.dart';
```

`dioProvider`(68행)에서 `final dio = DioClient.create();` 다음, `ProfileHeaderInterceptor` 등록(73행) **앞에** 더한다.

```dart
  // 앱 언어를 모든 요청에 싣는다 (다국어 #521). 요청마다 판정해 OS 언어가 바뀌어도 따라간다.
  // 맨 앞에 둔다 — 토큰 갱신 뒤 요청을 되살릴 때도 같은 헤더로 나간다.
  dio.interceptors.add(
    AcceptLanguageInterceptor(
      locale: () => effectiveAppLocale(
        devOverride: ref.read(devLocaleOverrideProvider),
      ),
    ),
  );
```

- [ ] **Step 4: 통과를 확인한다**

Run: `cd client && flutter test test/core/network/accept_language_interceptor_test.dart test/accept_language_dio_wiring_test.dart test/dio_client_test.dart test/profile_dio_wiring_test.dart test/profile_header_test.dart && flutter analyze`
Expected: **PASS**(기존 Dio 테스트 포함), `No issues found!`

- [ ] **Step 5: 커밋 (`/pro-commit`)**

```bash
git add client/lib/core/network/accept_language_interceptor.dart client/lib/core/network/dio_client.dart client/test/core/network/accept_language_interceptor_test.dart client/test/accept_language_dio_wiring_test.dart
```

## Task 8: 테스트 기반 — `pumpWithLocale` 과 넘침 파일럿

**Files:**
- Create: `client/test/helpers/pump_with_locale.dart`
- Test: `client/test/l10n/pump_with_locale_test.dart`, `client/test/l10n/overflow_pilot_test.dart`

**Interfaces:**
- Consumes: `AppL10n` (Task 6), `syncAppL10n` (Task 3), `AppTheme.lightFor` (Task 5)
- Produces: `Future<void> pumpWithLocale(WidgetTester tester, Widget home, {Locale locale = const Locale('ko'), ThemeData? theme, Widget Function(Widget app)? wrap})` — 번역 delegate·앱 테마·화면 크기 설정을 갖춘 `MaterialApp` 으로 띄운다. **새 테스트용**이다(기존 116개 파일은 그대로 `context.l10n` 의 `ko` 대체로 돈다). 계획 5 의 넘침 검사가 재사용한다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`client/test/l10n/pump_with_locale_test.dart`

```dart
import 'package:elum/core/l10n/current_l10n.dart';
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_with_locale.dart';

void main() {
  tearDown(setAppL10nForTest);

  testWidgets('기본은 ko 다 — 문구와 appL10n 이 모두 ko', (tester) async {
    await pumpWithLocale(
      tester,
      Builder(builder: (context) => Text(context.l10n.commonConfirm)),
    );

    expect(find.text('확인'), findsOneWidget);
    expect(appL10n.localeName, 'ko');
  });

  testWidgets('언어를 바꿔 다시 띄우면 appL10n 도 따라간다', (tester) async {
    await pumpWithLocale(tester, const SizedBox());
    expect(appL10n.localeName, 'ko');

    await pumpWithLocale(tester, const SizedBox(), locale: const Locale('es'));
    await tester.pump();
    expect(appL10n.localeName, 'es');
  });

  testWidgets('wrap 으로 ProviderScope 같은 바깥 껍질을 씌울 수 있다', (tester) async {
    await pumpWithLocale(
      tester,
      const Text('안쪽'),
      wrap: (app) => Directionality(textDirection: TextDirection.ltr, child: app),
    );

    expect(find.text('안쪽'), findsOneWidget);
  });
}
```

`client/test/l10n/overflow_pilot_test.dart`

```dart
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:elum/core/widgets/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';
import '../helpers/pump_with_locale.dart';

/// 번역이 길어도(스페인어) 고정 폭·고정 높이 위젯에서 넘치지 않는다 (Review Focus).
///
/// **파일럿이다.** 하네스(`pumpWithLocale` + 393×852 뷰포트 + 글자 상자 비교)가 동작함을 보이고
/// 가장 흔한 공용 위젯 셋을 본다. 전 화면 넘침 검사는 하위 계획 5 가 이 하네스로 한다.
/// RenderFlex 넘침은 `flutter_test_config.dart` 가 예외로 바꾸지만, 글자가 고정 높이 상자를
/// 삐져나가는 것은 예외가 아니라 **글자 상자 비교**로만 잡힌다.
///
/// 이 계획을 쓰며 실제 앱 코드(임시 복사본)에서 세 테스트를 돌려 모두 통과했다 — `ElumButton` 은 85자 라벨에서 글자 3줄 높이 66 이 버튼 높이 66 에 **딱 맞았다**(한 줄이 더 늘면 넘친다). 실패하는 위젯이 나오면 이 계획에서 고치지 않는다(ko 화면이 달라질 수 있다). 그 테스트에
/// `skip: '계획 5 넘침 검사 대상 — <위젯>'` 을 달고 커밋 메시지에 적어 계획 5 로 넘긴다.
void main() {
  useFigmaViewport();

  const es = Locale('es');
  const longEs =
      'Todavía no has creado ninguna rutina para hoy, ¿quieres crear la primera ahora mismo?';

  /// 가장자리에 딱 맞는 것(66 높이 상자에 66 높이 글)도 들어온 것이다 — `Rect.contains` 는
  /// 오른쪽·아래 가장자리를 밖으로 보므로 쓰지 않는다.
  bool inside(Rect outer, Rect inner) =>
      inner.left >= outer.left &&
      inner.top >= outer.top &&
      inner.right <= outer.right &&
      inner.bottom <= outer.bottom;

  testWidgets('ElumButton — 긴 라벨이 버튼 상자 안에 있다', (tester) async {
    await pumpWithLocale(
      tester,
      const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: ElumButton(label: longEs),
        ),
      ),
      locale: es,
      theme: AppTheme.lightFor(es),
    );

    final button = tester.getRect(find.byType(ElumButton));
    final text = tester.getRect(find.text(longEs));
    expect(inside(button, text), isTrue, reason: '버튼 $button 밖으로 글자 $text 가 나갔다');
  });

  testWidgets('SettingsTile — 긴 라벨이 줄 상자 안에 있다', (tester) async {
    await pumpWithLocale(
      tester,
      const Scaffold(body: SettingsTile(label: longEs, onTap: null)),
      locale: es,
      theme: AppTheme.lightFor(es),
    );

    final tile = tester.getRect(find.byType(SettingsTile));
    final text = tester.getRect(find.text(longEs));
    expect(inside(tile, text), isTrue, reason: '줄 $tile 밖으로 글자 $text 가 나갔다');
  });

  testWidgets('ElumDialogCard — 긴 제목이 화면 폭 안에 있다', (tester) async {
    await pumpWithLocale(
      tester,
      const Scaffold(
        body: Center(
          child: ElumDialogCard<void>(
            title: longEs,
            actions: [ElumDialogAction(label: 'Aceptar')],
          ),
        ),
      ),
      locale: es,
      theme: AppTheme.lightFor(es),
    );

    final text = tester.getRect(find.text(longEs));
    expect(text.left, greaterThanOrEqualTo(0));
    expect(text.right, lessThanOrEqualTo(393));
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: 실행해 실패를 확인한다**

Run: `cd client && flutter test test/l10n/pump_with_locale_test.dart test/l10n/overflow_pilot_test.dart`
Expected: **FAIL** — `pump_with_locale.dart` 가 없다.

- [ ] **Step 3: 구현한다**

`client/test/helpers/pump_with_locale.dart`

```dart
import 'package:elum/core/l10n/app_l10n.dart';
import 'package:elum/core/l10n/current_l10n.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// 번역 delegate·Figma 기준 화면 크기(393×852)·`appL10n` 동기화를 갖춘 앱으로 [home] 을 띄운다.
///
/// 기존 테스트는 `MaterialApp` 을 제각각 만들고 `context.l10n` 의 `ko` 대체로 돈다. 이 헬퍼는
/// **다른 언어로 띄워야 하는 새 테스트**(하위 계획 5 의 넘침 검사 등)를 위한 것이다.
///
/// - [locale]: 앱 언어. 기본 `ko`.
/// - [theme]: 기본은 [locale] 에 맞는 `AppTheme.lightFor`. 글꼴 대체까지 보려면 그대로 둔다.
/// - [wrap]: `ProviderScope` 같은 바깥 껍질을 씌울 때. `(app) => ProviderScope(overrides: […], child: app)`
///
/// 화면 크기는 호출 쪽이 `useFigmaViewport()` 로 맞춘다 (`test/helpers/device_viewport.dart`).
Future<void> pumpWithLocale(
  WidgetTester tester,
  Widget home, {
  Locale locale = const Locale('ko'),
  ThemeData? theme,
  Widget Function(Widget app)? wrap,
}) async {
  Widget app = ScreenUtilInit(
    designSize: const Size(393, 852),
    minTextAdapt: true,
    builder: (context, _) => MaterialApp(
      theme: theme ?? AppTheme.lightFor(locale),
      locale: locale,
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: AppL10n.delegates,
      builder: (context, child) {
        // 실제 앱의 builder 와 같다 — context 가 없는 층이 이 언어의 문구를 읽는다
        syncAppL10n(context);
        return child ?? const SizedBox.shrink();
      },
      home: home,
    ),
  );
  if (wrap != null) app = wrap(app);
  await tester.pumpWidget(app);
  await tester.pump();
}
```

- [ ] **Step 4: 통과를 확인한다**

Run: `cd client && flutter test test/l10n/ && flutter analyze`
Expected: **PASS**. 넘침 파일럿이 실패하면 위 지침대로 `skip` 으로 돌리고 커밋 메시지에 위젯 이름을 적는다. `No issues found!`

- [ ] **Step 5: 커밋 (`/pro-commit`)**

```bash
git add client/test/helpers/pump_with_locale.dart client/test/l10n/pump_with_locale_test.dart client/test/l10n/overflow_pilot_test.dart
```

## Task 9: 검증 도구 — 한글 리터럴 검사기와 `ko` 문구 감사기

**Files:**
- Create: `client/tool/check_hangul_literals.dart`, `client/tool/l10n_ko_audit.dart`, `client/tool/l10n_ko_audit_accepted.txt`(빈 파일)
- Modify(개발자용 한글에 `l10n-ignore` 표식 4곳): `client/lib/core/widgets/elum_scaffold.dart:42`, `client/lib/features/credit/data/credit_repository.dart:29`, `client/lib/features/guardian/application/routine_notifier.dart:359`, `client/lib/core/config/app_config.dart:162`
- Test: `client/test/tool/check_hangul_literals_test.dart`, `client/test/tool/l10n_ko_audit_test.dart`

**Interfaces:**
- Consumes: (없음)
- Produces:
  - `dart run tool/check_hangul_literals.dart [경로...]` — 사용자에게 보이는 한글 리터럴을 `경로:줄: 내용` 으로 찍고, 있으면 종료 코드 1. `List<String> scan(String path, String source)` 는 테스트용으로 공개.
  - `dart run tool/l10n_ko_audit.dart --base <커밋> [--arb <파일>]` — `app_ko.arb` 의 문구 조각이 기준 커밋 소스에 그대로 있는지 확인. 없으면 종료 코드 1. `List<String> fragmentsOf(String message)` 는 테스트용으로 공개.

**왜 두 도구인가.** 이 계획의 가장 큰 위험은 문구를 옮기다 한국어가 달라지는 것이다. 검사기는 "아직 안 옮긴 곳"을, 감사기는 "옮긴 문구가 원본과 글자 하나까지 같은가"를 센다. 테스트가 안 덮는 문구(약 절반)의 오타는 감사기만 잡는다.

**검사기가 건너뛰는 것**(이유를 코드에 적는다): 개발자 도구·로거·약관 번들/파서(계획 4)·`routine_repository.dart`(로그·예외·로컬 마스킹 정규식뿐)·미사용 `dlp_screen.dart`/`demo_cards.dart`·`app_assets.dart`(`@Deprecated` 안내)·`oauth_sdk.dart`(제공자 이름은 로그에만 쓴다), 그리고 줄 안의 `AppLogger.`·`debugPrint(`·`throw `·예외 생성자·`RegExp(`·`assert(`·`Key('`·`l10n-ignore`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`client/test/tool/check_hangul_literals_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_hangul_literals.dart';

void main() {
  List<String> scanLines(String source) => scan('a.dart', source);

  test('문자열 안의 한글을 줄 번호와 함께 찾는다', () {
    expect(scanLines("final a = 1;\nfinal t = Text('확인');"), [
      "a.dart:2: final t = Text('확인');",
    ]);
  });

  test('주석은 건너뛴다 — 줄 주석·줄 끝 주석·블록 주석', () {
    const source = "// 확인\n"
        "final a = 1; // 확인\n"
        "/* 확인\n"
        "   확인 */\n"
        "/// 확인";
    expect(scanLines(source), isEmpty);
  });

  test('문자열 안의 // 는 주석이 아니다', () {
    expect(scanLines("final u = 'http://a.com/확인';"), hasLength(1));
  });

  test('로그·예외·정규식·assert·키는 사용자에게 보이지 않으므로 건너뛴다', () {
    const source = "AppLogger.error('실패');\n"
        "debugPrint('실패');\n"
        "throw StateError('실패');\n"
        "throw const FormatException('실패');\n"
        "final r = RegExp(r'[가-힣]');\n"
        "const k = Key('광고 틀');";
    expect(scanLines(source), isEmpty);
  });

  test('줄 끝 l10n-ignore 표식은 건너뛴다', () {
    expect(scanLines("x('실패'); // l10n-ignore: 로그"), isEmpty);
  });
}
```

`client/test/tool/l10n_ko_audit_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';

import '../../tool/l10n_ko_audit.dart';

void main() {
  test('줄바꿈을 기준으로 조각낸다', () {
    expect(fragmentsOf('이 휴대폰은 누가\n사용하나요?'), ['이 휴대폰은 누가', '사용하나요?']);
  });

  test('자리표시자와 ICU 가지 이름을 걷어낸다', () {
    expect(
      fragmentsOf('{name}{batchim, select, yes{이} other{가}} 할 일을 해내서\n루루가 선물을 가져왔다고 해요'),
      ['할 일을 해내서', '루루가 선물을 가져왔다고 해요'],
    );
    expect(fragmentsOf('{weekday, select, mon{월} tue{화} other{}}'), isEmpty);
  });

  test('한 글자 조각은 어디에나 있으므로 버린다', () {
    expect(fragmentsOf('{count, plural, other{{count}개}}'), isEmpty);
  });

  test('소스 표기와 달라지는 따옴표·역슬래시가 든 조각은 버린다', () {
    expect(fragmentsOf("it's 좋아요"), isEmpty);
  });
}
```

- [ ] **Step 2: 실행해 실패를 확인한다**

Run: `cd client && flutter test test/tool/`
Expected: **FAIL** — `tool/check_hangul_literals.dart`·`tool/l10n_ko_audit.dart` 가 없다.

- [ ] **Step 3: 검사기를 만든다**

`client/tool/check_hangul_literals.dart`

```dart
// 사용자에게 보일 수 있는 한글 리터럴을 코드에서 찾는다 (다국어 문구 추출 검증용).
//
// 사용: `cd client && dart run tool/check_hangul_literals.dart [경로...]` (기본 `lib`)
// 한 줄이라도 걸리면 종료 코드 1 이다. 걸린 줄은 ARB 로 옮기거나, 사용자에게 안 보이는
// 글(로그·예외·정규식)이면 줄 끝에 `// l10n-ignore: 이유` 를 단다.
import 'dart:io';

/// 파일·폴더 전체를 건너뛴다. 이유를 반드시 적는다.
const _skipPaths = <String, String>{
  'lib/l10n/': '생성된 번역 코드',
  'lib/core/dev/': '개발자 도구 — 운영자·QA 전용이라 번역하지 않는다 (스펙 1장)',
  'lib/core/logger/': '로그 — 번역하지 않는다',
  'lib/features/auth/domain/consent_documents.dart': '약관 번들 기본값 — 하위 계획 4 소관',
  'lib/features/auth/domain/consent_body.dart': '약관 본문 파서의 한국어 규칙 — 하위 계획 4 소관',
  'lib/features/guardian/data/routine_repository.dart': '로그·예외 문구와 로컬 마스킹 정규식뿐이다',
  'lib/features/guardian/presentation/dlp_screen.dart': 'DLP 폐기(#377) 후 어디서도 열지 않는 화면',
  'lib/features/guardian/data/demo_cards.dart': 'lib 어디서도 쓰지 않는 데모 카드(테스트만 참조)',
  'lib/core/assets/app_assets.dart': '@Deprecated 개발자 안내문뿐이다',
  'lib/features/auth/data/oauth_sdk.dart': '제공자 이름은 로그에만 쓴다(사용자에게 보이지 않는다)',
};

/// 이 줄은 사용자에게 보이지 않는 글이다.
final _skipLine = RegExp(
  r'''AppLogger\.|debugPrint\(|throw |FormatException|StateError|ArgumentError|'''
  r'''UnimplementedError|@Deprecated|RegExp\(|assert\(|\[config\]|\.env\.example|'''
  r'''\[cost\]|Key\('|l10n-ignore''',
);
final _hangul = RegExp(r'[가-힣]');

/// 따옴표 밖의 `//` 뒤를 지운다. 문자열 안의 `//`(URL 등)는 건드리지 않는다.
String _stripTrailingComment(String line) {
  final out = StringBuffer();
  String? quote;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (quote != null) {
      out.write(c);
      if (c == r'\' && i + 1 < line.length) {
        out.write(line[++i]);
      } else if (c == quote) {
        quote = null;
      }
    } else if (c == "'" || c == '"') {
      quote = c;
      out.write(c);
    } else if (line.startsWith('//', i)) {
      break;
    } else {
      out.write(c);
    }
  }
  return out.toString();
}

/// 파일 하나에서 걸린 줄(`경로:줄: 내용`)을 모은다.
List<String> scan(String path, String source) {
  final found = <String>[];
  var inBlock = false;
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final s = line.trim();
    if (inBlock) {
      if (s.contains('*/')) inBlock = false;
      continue;
    }
    if (s.startsWith('/*')) {
      if (!s.contains('*/')) inBlock = true;
      continue;
    }
    if (s.startsWith('//')) continue;
    if (!_hangul.hasMatch(_stripTrailingComment(line))) continue;
    if (_skipLine.hasMatch(line)) continue;
    found.add('$path:${i + 1}: $s');
  }
  return found;
}

bool _skipped(String path) => _skipPaths.keys.any(path.startsWith);

void main(List<String> args) {
  final roots = args.isEmpty ? ['lib'] : args;
  final hits = <String>[];
  for (final root in roots) {
    final type = FileSystemEntity.typeSync(root);
    final files = switch (type) {
      FileSystemEntityType.directory => Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path),
      FileSystemEntityType.file => [root],
      _ => <String>[],
    };
    for (final path in files) {
      if (!path.endsWith('.dart') || path.endsWith('.freezed.dart')) continue;
      if (_skipped(path)) continue;
      hits.addAll(scan(path, File(path).readAsStringSync()));
    }
  }
  hits.forEach(stdout.writeln);
  stdout.writeln('--- 사용자 노출 한글 리터럴 ${hits.length}줄');
  if (hits.isNotEmpty) exit(1);
}
```

- [ ] **Step 4: 감사기를 만든다**

`client/tool/l10n_ko_audit.dart`

```dart
// ko ARB 문구가 기준 커밋의 한글 리터럴과 글자 하나까지 같은지 확인한다 (`ko` 불변 검증).
//
// 사용: `cd client && dart run tool/l10n_ko_audit.dart --base 99b65ac0`
//   --arb  검사할 ARB (기본 lib/l10n/app_ko.arb)
//   --base 문구를 옮기기 **전** 커밋. 이 커밋의 lib 에서 조각을 찾는다.
//
// ARB 문구를 자리표시자·ICU 가지·줄바꿈 기준으로 조각내고, 각 조각(2글자 이상)이 기준
// 커밋의 소스에 그대로 있는지 `git grep -F` 로 묻는다. 없으면 오타이거나 문구를 고친 것이다.
// 붙여 쓴 문자열 리터럴(`'a' 'b'`)의 경계를 가로지르는 조각은 걸릴 수 있다 — 눈으로
// 확인한 뒤 `tool/l10n_ko_audit_accepted.txt` 에 한 줄씩 적는다.
import 'dart:convert';
import 'dart:io';

const _nul = '\u0000';

/// ARB 문구 하나를 소스에서 찾을 조각들로 나눈다.
List<String> fragmentsOf(String message) {
  var m = message;
  m = m.replaceAll(RegExp(r'\{\s*\w+\s*\}'), _nul); // {name}
  m = m.replaceAll(RegExp(r'\{\s*\w+\s*,\s*(plural|select)\s*,'), _nul); // {n, plural,
  // 남은 `가지이름{` (other{ · yes{ · mon{ · =0{) — 앞의 두 줄이 자리표시자를 먼저 지웠으므로 여기 남는 `{` 는 가지뿐이다
  m = m.replaceAll(RegExp(r'(=\d+|[A-Za-z_]\w*)\s*\{'), _nul);
  m = m.replaceAll('}', _nul);
  return m
      .split(RegExp('$_nul|\n'))
      .map((f) => f.trim())
      .where((f) => f.runes.length >= 2)
      // 따옴표·역슬래시가 든 조각은 소스 표기(`\'`, `\n`)와 달라 이 방법으로 못 맞댄다
      .where((f) => !f.contains("'") && !f.contains(r'\'))
      .toList();
}

bool _inBase(String base, String fragment) {
  final r = Process.runSync('git', ['grep', '-F', '-q', '-e', fragment, base, '--', 'lib']);
  return r.exitCode == 0;
}

void main(List<String> args) {
  String opt(String name, String fallback) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  }

  final base = opt('--base', '');
  final arbPath = opt('--arb', 'lib/l10n/app_ko.arb');
  if (base.isEmpty) {
    stderr.writeln('--base <커밋> 이 필요하다');
    exit(2);
  }
  final accepted = File('tool/l10n_ko_audit_accepted.txt').existsSync()
      ? File('tool/l10n_ko_audit_accepted.txt')
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty)
          .toSet()
      : <String>{};

  final arb = jsonDecode(File(arbPath).readAsStringSync()) as Map<String, dynamic>;
  var checked = 0;
  final missing = <String>[];
  for (final e in arb.entries) {
    if (e.key.startsWith('@') || e.value is! String) continue;
    final text = e.value as String;
    // JSON 의 `\n` 은 줄바꿈 문자로 읽힌다. 역슬래시가 **글자로** 남았다면 `\\n` 으로 잘못 쓴 것이다
    // (조각 검사는 역슬래시가 든 조각을 건너뛰므로 여기서 따로 잡는다).
    if (text.contains(r'\')) {
      missing.add('${e.key}: 역슬래시 글자가 있다 — 줄바꿈은 JSON 에서 `\\n` 하나다');
      continue;
    }
    for (final f in fragmentsOf(text)) {
      checked++;
      if (accepted.contains(f) || _inBase(base, f)) continue;
      missing.add('${e.key}: "$f"');
    }
  }
  missing.forEach(stdout.writeln);
  stdout.writeln('--- 조각 $checked개 중 기준 커밋에 없는 것 ${missing.length}개');
  if (missing.isNotEmpty) exit(1);
}
```

그리고 빈 파일 `client/tool/l10n_ko_audit_accepted.txt` 를 만든다(`touch client/tool/l10n_ko_audit_accepted.txt`).

- [ ] **Step 5: 기준선을 센다**

Run: `cd client && flutter test test/tool/ && dart run tool/check_hangul_literals.dart lib | tail -1`
Expected: 테스트 **PASS**, 검사기 마지막 줄 `--- 사용자 노출 한글 리터럴 548줄`(종료 코드 1). 기준 커밋의 549줄에서 Task 6 이 `app.dart` 의 앱 이름 1줄을 옮긴 값이다. 줄 목록에서 개발자용 4줄이 보인다.

- [ ] **Step 6: 개발자용 한글 4줄에 표식을 단다**

사용자에게 보이지 않는 글이라 번역 대상이 아니다. 줄 끝에 이유를 적는다(한국어 문구는 바뀌지 않는다).

`client/lib/core/widgets/elum_scaffold.dart:42`

```dart
         '하단 고정 버튼과 배너를 함께 쓰면 버튼을 가린다 — 배너는 버튼이 없는 화면에만 둔다', // l10n-ignore: 개발자용 assert 메시지
```

`client/lib/features/credit/data/credit_repository.dart:29`

```dart
        summary.enabled ? '남음 ${summary.available}' : '꺼짐', // l10n-ignore: 로그
```

`client/lib/features/guardian/application/routine_notifier.dart:359`

```dart
        '이미 ${state.routine != null ? "생성 완료" : "생성 중"}. 서버 요청 안 보냄', // l10n-ignore: 로그
```

`client/lib/core/config/app_config.dart:162`

```dart
  static String get naverClientName => _string('ELUM_NAVER_CLIENT_NAME', '이룸'); // l10n-ignore: 네이버 SDK 에 넘기는 앱 이름 기본값 — 계획 6(네이티브)
```

Run: `cd client && dart run tool/check_hangul_literals.dart lib | tail -1 && flutter analyze`
Expected: `--- 사용자 노출 한글 리터럴 544줄`(남은 것 중 `KoreanParticle` 4줄은 Task 13 이 표식을 단다), `No issues found!`

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add client/tool/check_hangul_literals.dart client/tool/l10n_ko_audit.dart client/tool/l10n_ko_audit_accepted.txt client/test/tool client/lib/core/widgets/elum_scaffold.dart client/lib/features/credit/data/credit_repository.dart client/lib/features/guardian/application/routine_notifier.dart client/lib/core/config/app_config.dart
```

## Task 10: `keepWords` — 한국어에서만 어절 표시를 넣는다

**Files:**
- Modify: `client/lib/core/text/keep_words.dart:1-52`(전체)
- Modify(호출 12곳, 모두 `build` 안이라 `context` 가 있다): `client/lib/core/widgets/elum_dialog.dart:194,196`, `client/lib/features/notice/presentation/notice_popup.dart:193`, `client/lib/features/notice/presentation/widgets/notice_controls.dart:65`, `client/lib/features/notice/presentation/widgets/notice_slide.dart:49,87`, `client/lib/features/guardian/presentation/question_screen.dart:229`, `client/lib/features/guardian/presentation/widgets/default_card_art.dart:120`, `client/lib/features/onboarding/presentation/widgets/image_style_option_card.dart:121`
- Test: `client/test/l10n/keep_words_locale_test.dart` (기존 `client/test/keep_words_test.dart` 는 고치지 않는다 — 그대로 통과해야 한다)

**Interfaces:**
- Consumes: `context.appLocale` (Task 3), `pumpWithLocale` (Task 8)
- Produces: `String keepWords(String text, {Locale? locale})`, `List<String> keepWordsParts(List<String> parts, {Locale? locale})`, `bool usesWordJoiner(Locale? locale)` — `locale` 이 null 이면 한국어로 본다(기존 호출·테스트와 같다).

**왜 한국어에서만인가.** U+2060(WORD JOINER)을 글자 사이마다 넣어 "띄어쓰기에서만 끊기게" 하는 것이 `keepWords` 다. 한국어는 띄어쓰기가 있는데도 글자 단위로 끊겨서 필요하다. 영어·스페인어는 원래 띄어쓰기에서만 끊기고, 일본어·중국어는 띄어쓰기가 없어 표시를 넣으면 **줄바꿈이 아예 막힌다**. 관리자 미리보기(`notice-preview.js` 의 `keepWords`)가 같은 규칙을 쓴다고 주석에 적혀 있다 — 그쪽 변경은 **하위 계획 4 소관**이다. 계획 4 에 넘기는 인터페이스: "`ko` 만 표시를 넣고 그 밖의 언어는 원문 그대로"(= `usesWordJoiner`).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`client/test/l10n/keep_words_locale_test.dart`

```dart
import 'package:elum/core/text/keep_words.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';
import '../helpers/pump_with_locale.dart';

void main() {
  useFigmaViewport();

  const wj = '⁠';
  const zhHans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');

  group('keepWords — 한국어만 어절 표시를 넣는다', () {
    test('locale 이 null 이면 한국어다 — 기존 호출이 그대로 동작한다', () {
      expect(keepWords('방침에서'), '방$wj침$wj에$wj서');
    });

    test('ko 는 표시를 넣는다', () {
      expect(
        keepWords('방침에서', locale: const Locale('ko')),
        '방$wj침$wj에$wj서',
      );
    });

    test('en·es·ja·zh 는 원문 그대로다 — 일본어·중국어에 넣으면 줄바꿈이 막힌다', () {
      for (final l in [
        const Locale('en'),
        const Locale('es'),
        const Locale('ja'),
        zhHans,
      ]) {
        expect(keepWords('Hello 日本語 방침에서', locale: l), 'Hello 日本語 방침에서', reason: '$l');
      }
    });

    test('keepWordsParts 도 같은 규칙이다 — ko 는 조각 경계도 한 어절로 본다', () {
      expect(
        keepWordsParts(['9월', '30일'], locale: const Locale('ko')),
        ['9$wj월', '${wj}3${wj}0$wj일'],
      );
      expect(
        keepWordsParts(['9월', '30일'], locale: const Locale('ja')),
        ['9월', '30일'],
      );
    });

    test('usesWordJoiner', () {
      expect(usesWordJoiner(null), isTrue);
      expect(usesWordJoiner(const Locale('ko')), isTrue);
      expect(usesWordJoiner(const Locale('ja')), isFalse);
      expect(usesWordJoiner(const Locale('en')), isFalse);
    });
  });

  group('팝업 설명', () {
    Future<String> shownMessage(WidgetTester tester, Locale locale) async {
      await pumpWithLocale(
        tester,
        const Scaffold(
          body: Center(
            child: ElumDialogCard<void>(
              title: '제목',
              message: '방침에서 확인해요',
              keepWordsInMessage: true,
            ),
          ),
        ),
        locale: locale,
      );
      // 낭독기에는 원문을 주므로(semanticsLabel) 그것으로 위젯을 찾는다
      final text = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && w.semanticsLabel == '방침에서 확인해요',
        ),
      );
      return text.data!;
    }

    testWidgets('ko 팝업 설명에는 어절 표시가 들어간다 — 지금과 같다', (tester) async {
      expect(await shownMessage(tester, const Locale('ko')), contains(wj));
    });

    testWidgets('ja 팝업 설명에는 표시가 없다', (tester) async {
      expect(await shownMessage(tester, const Locale('ja')), isNot(contains(wj)));
    });
  });
}
```

- [ ] **Step 2: 실행해 실패를 확인한다**

Run: `cd client && flutter test test/l10n/keep_words_locale_test.dart`
Expected: **FAIL** — `keepWords` 에 `locale` 인자가 없다(컴파일 오류).

- [ ] **Step 3: `keep_words.dart` 를 바꾼다**

`client/lib/core/text/keep_words.dart` 전체

```dart
import 'package:flutter/widgets.dart';

/// 끊지 말라는 표시 (U+2060 WORD JOINER). 폭이 0 이라 보이지 않는다.
const _joiner = '⁠';

bool _isSpace(String ch) => ch.trim().isEmpty;

/// 끊지 말라는 표시를 넣는 언어인가 — **한국어만** 넣는다.
///
/// 한국어는 띄어쓰기가 있는데도 글자 단위로 끊겨서 표시가 필요하다. 영어·스페인어는 띄어쓰기에서만
/// 끊기고, 일본어·중국어는 띄어쓰기가 없어 표시를 넣으면 **줄바꿈이 아예 막힌다**.
/// [locale] 이 null 이면 한국어로 본다(언어를 모르는 기존 호출·테스트와 같다).
///
/// 관리자 미리보기(`notice-preview.js`)의 같은 함수가 이 규칙을 따라야 한다 (하위 계획 4).
bool usesWordJoiner(Locale? locale) =>
    locale == null || locale.languageCode == 'ko';

/// 한글을 **어절 단위로** 줄바꿈하게 만든다 (이슈 #390 · #385 A).
///
/// Flutter 는 한글을 글자 단위로 끊는다 — "자세한 내용은 방 / 침에서". CSS 의
/// `word-break: keep-all` 같은 설정이 없어서, 붙어 있는 글자 사이마다 끊지 말라는
/// 표시를 넣어 **띄어쓰기에서만** 끊기게 한다. 한 어절이 줄보다 길면 그때는
/// 엔진이 글자에서 끊는다(넘치지 않는다).
///
/// **정해 둔 곳에만 쓴다** — 공지 팝업(#390), 보상 도움말 팝업·추가 질문 제목(#393
/// S4·S5). 앱의 다른 화면은 시안 대조가 글자 단위 줄에 맞춰져 있어 앱 전체 규칙으로
/// 바꾸지 않았다.
/// 관리자 미리보기(`notice-preview.js` 의 `keepWords`)가 **같은 규칙**으로 표시를
/// 넣는다 — 한쪽만 바꾸면 관리자가 본 줄과 보호자가 본 줄이 다시 달라진다.
///
/// [locale] 이 한국어가 아니면 원문을 그대로 돌려준다 ([usesWordJoiner]).
/// 화면 낭독기에 표시가 섞이지 않게, 그리는 쪽은 원문을 `semanticsLabel` 로 준다.
String keepWords(String text, {Locale? locale}) =>
    keepWordsParts([text], locale: locale).single;

/// [keepWords] 를 여러 조각에 걸쳐 한다. 강조(`**…**`)로 나뉜 제목처럼 한 줄 글이
/// 여러 조각일 때, **조각 경계도** 붙어 있으면 한 어절로 본다 — "9월 30일"+"에".
List<String> keepWordsParts(List<String> parts, {Locale? locale}) {
  if (!usesWordJoiner(locale)) return List.of(parts);

  final out = <String>[];
  String? prev;
  for (final part in parts) {
    final buffer = StringBuffer();
    // 이모지처럼 여러 코드 포인트가 한 글자인 것은 통째로 다룬다 — 안에 넣으면 그림이 갈라진다
    for (final ch in part.characters) {
      if (prev != null && !_isSpace(prev) && !_isSpace(ch)) {
        buffer.write(_joiner);
      }
      buffer.write(ch);
      prev = ch;
    }
    out.add(buffer.toString());
  }
  return out;
}
```

- [ ] **Step 4: 호출 12곳에 앱 언어를 넘긴다**

모든 호출이 `build` 안이라 `context` 가 있다. 같은 모양으로 `locale: context.appLocale` 을 더하고, 그 파일에 `import '<상대경로>/core/l10n/l10n_context.dart';` 가 없으면 더한다.

`client/lib/core/widgets/elum_dialog.dart:194-196`

```dart
              Text(
                keepWordsInMessage
                    ? keepWords(message!, locale: context.appLocale)
                    : message!,
                // 끊지 말라는 표시가 낭독기에 섞이지 않게 원문을 준다
                semanticsLabel: keepWordsInMessage ? message : null,
```

나머지도 같은 한 줄 변환이다.

| 파일:줄 | 바꾸기 전 | 바꾼 뒤 |
| --- | --- | --- |
| `notice_popup.dart:193` | `keepWords(button.label)` | `keepWords(button.label, locale: context.appLocale)` |
| `notice_controls.dart:65` | `keepWords(label)` | `keepWords(label, locale: context.appLocale)` |
| `notice_slide.dart:49` | `keepWordsParts([for (final part in title) part.text])` | `keepWordsParts([for (final part in title) part.text], locale: context.appLocale)` |
| `notice_slide.dart:87` | `keepWords(notice.body)` | `keepWords(notice.body, locale: context.appLocale)` |
| `question_screen.dart:229` | `keepWords(widget.item.question)` | `keepWords(widget.item.question, locale: context.appLocale)` |
| `default_card_art.dart:120` | `keepWords(title)` | `keepWords(title, locale: context.appLocale)` |
| `image_style_option_card.dart:121` | `keepWords(_breakAtSentence(style.description))` | `keepWords(_breakAtSentence(style.description), locale: context.appLocale)` |

- [ ] **Step 5: 통과를 확인한다**

Run:
```bash
cd client && flutter test test/l10n/keep_words_locale_test.dart test/keep_words_test.dart $(grep -rlE "keepWords|NoticePopup|ElumDialog|DefaultCardArt|ImageStyleOptionCard|QuestionScreen" test | sort) && flutter analyze
```
Expected: **PASS**(기존 어절 테스트 포함 — `ko` 불변), `No issues found!`. 골든 PNG 변경 없음: `git status --short client/test | grep -c png` → `0`.

- [ ] **Step 6: 커밋 (`/pro-commit`)**

```bash
git add client/lib/core/text/keep_words.dart client/lib/core/widgets/elum_dialog.dart client/lib/features/notice/presentation/notice_popup.dart client/lib/features/notice/presentation/widgets/notice_controls.dart client/lib/features/notice/presentation/widgets/notice_slide.dart client/lib/features/guardian/presentation/question_screen.dart client/lib/features/guardian/presentation/widgets/default_card_art.dart client/lib/features/onboarding/presentation/widgets/image_style_option_card.dart client/test/l10n/keep_words_locale_test.dart
```

## Task 11: 한국어 전제 로직의 언어 중립 헬퍼 — 받침 판정·날짜 라벨·글자 수 제한 고정

**Files:**
- Create: `client/lib/core/l10n/batchim.dart`, `client/lib/core/l10n/date_labels.dart`
- Modify: `client/lib/l10n/app_ko.arb`(날짜 문구 6개 추가) → 재생성
- Test: `client/test/l10n/batchim_test.dart`, `client/test/l10n/date_labels_test.dart`, `client/test/l10n/text_limit_grapheme_test.dart`

**Interfaces:**
- Consumes: `AppLocalizations` (Task 1), `pumpWithLocale` (Task 8)
- Produces:
  - `String batchimOf(String name)` — `'yes'`(끝 글자가 받침 있는 한글) 또는 `'no'`. ARB 의 `{batchim, select, yes{…} other{…}}` 가 읽는다.
  - `extension DateLabels on AppLocalizations { String weekdayShortOf(DateTime); String yearMonthDay(DateTime); String monthDaySince(DateTime); String resetAt(DateTime); }`
  - ARB 키: `dateYearMonthDay(year, month, day)`, `dateMonthDaySince(month, day)`, `weekdayShort(weekday)`, `creditResetAt(month, day, weekday, hour)`, `creditResetAtMinute(month, day, weekday, hour, minute)`, `creditResetFallback`

이 Task 는 **헬퍼만** 만든다. 조사·날짜를 쓰는 호출부는 폴더별 Task(13, 16, 17, 18, 23)가 바꾼다.

**조사를 코드가 붙이지 않는다(마스터 C4 의 취지).** 코드는 받침 **판정값**만 주고, 조사 글자는 문구가 정한다. 다른 언어 문구는 `batchim` 을 쓰지 않는다.

**글자 수 제한(스펙 "grapheme 기준")은 코드 변경이 없다.** `LengthLimitingTextInputFormatter` 가 이미 grapheme cluster 단위다 — 고정 테스트만 둔다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`client/test/l10n/batchim_test.dart`

```dart
import 'package:elum/core/l10n/batchim.dart';
import 'package:flutter_test/flutter_test.dart';

/// 이름 끝 글자의 받침 판정 — 기존 `KoreanParticle` 과 판정이 같아야 `ko` 문구가 안 바뀐다.
void main() {
  test('받침이 있는 한글이면 yes', () {
    expect(batchimOf('민준'), 'yes'); // 준 → ㄴ
    expect(batchimOf('하늘'), 'yes'); // 늘 → ㄹ
    expect(batchimOf('지훈'), 'yes');
  });

  test('받침이 없는 한글이면 no', () {
    expect(batchimOf('루미'), 'no');
    expect(batchimOf('서연이'), 'no');
  });

  test('한글이 아니면 no — 영문·숫자·이모지·빈 문자열은 받침 없음으로 본다', () {
    expect(batchimOf('Alex'), 'no');
    expect(batchimOf('7'), 'no');
    expect(batchimOf('😀'), 'no');
    expect(batchimOf(''), 'no');
  });
}
```

`client/test/l10n/date_labels_test.dart`

```dart
import 'package:elum/core/l10n/date_labels.dart';
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 날짜 라벨은 ARB 로 옮겨도 `ko` 결과가 옛 직접 조립과 글자 하나까지 같아야 한다.
void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  test('2026년 9월 20일 (Routine.scheduledDateLabel 이 하던 조립)', () {
    expect(ko.yearMonthDay(DateTime(2026, 9, 20)), '2026년 9월 20일');
    expect(ko.yearMonthDay(DateTime(2026, 12, 1)), '2026년 12월 1일');
  });

  test('9월 18일부터 (LinkedDevice.sinceLabel 이 하던 조립)', () {
    expect(ko.monthDaySince(DateTime(2026, 9, 18)), '9월 18일부터');
  });

  test('요일은 월~일 한 글자', () {
    // 2026-09-28 은 월요일, 2026-10-04 는 일요일
    expect(ko.weekdayShortOf(DateTime(2026, 9, 28)), '월');
    expect(ko.weekdayShortOf(DateTime(2026, 9, 29)), '화');
    expect(ko.weekdayShortOf(DateTime(2026, 10, 4)), '일');
  });

  test('9월 28일(월) 0시 — 분이 0이면 분을 적지 않는다 (CreditSummary.resetLabel)', () {
    expect(ko.resetAt(DateTime(2026, 9, 28)), '9월 28일(월) 0시');
  });

  test('분이 있으면 뒤에 붙는다', () {
    expect(ko.resetAt(DateTime(2026, 9, 29, 3, 30)), '9월 29일(화) 3시 30분');
  });

  test('다음 주 월요일 0시 — 다음 초기화 시각을 모를 때의 문구', () {
    expect(ko.creditResetFallback, '다음 주 월요일 0시');
  });
}
```

`client/test/l10n/text_limit_grapheme_test.dart`

```dart
import 'package:elum/core/widgets/elum_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';
import '../helpers/pump_with_locale.dart';

/// 글자 수 제한은 UTF-16 코드 단위가 아니라 **사용자가 보는 글자(grapheme)** 로 센다.
/// 이모지 한 개가 코드 단위 둘 이상이라 코드 단위로 세면 일본어·중국어·이모지 이름이 잘린다.
/// 지금 `LengthLimitingTextInputFormatter` 가 이미 그렇게 동작한다 — 바뀌지 않게 고정한다.
void main() {
  useFigmaViewport();

  Future<String> typed(WidgetTester tester, String input, int max) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpWithLocale(
      tester,
      Scaffold(
        body: ElumTextField(
          hintText: 'name',
          controller: controller,
          maxLength: max,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), input);
    await tester.pump();
    return controller.text;
  }

  testWidgets('이모지(가족) 한 개는 한 글자로 센다', (tester) async {
    const family = '👨‍👩‍👧';
    expect(await typed(tester, '$family$family$family$family가', 3), '$family$family$family');
  });

  testWidgets('일본어·중국어도 글자 수로 센다', (tester) async {
    expect(await typed(tester, '日本語学校', 3), '日本語');
  });

  testWidgets('한글 이름은 지금처럼 자른다', (tester) async {
    expect(await typed(tester, '가나다라마', 3), '가나다');
  });
}
```

- [ ] **Step 2: 실행해 실패를 확인한다**

Run: `cd client && flutter test test/l10n/batchim_test.dart test/l10n/date_labels_test.dart test/l10n/text_limit_grapheme_test.dart`
Expected: 앞의 둘 **FAIL**(`batchim.dart`·`date_labels.dart` 없음). `text_limit_grapheme_test` 는 **PASS**(이미 그렇게 동작한다 — 고정 테스트라서 먼저 통과하는 것이 맞다).

- [ ] **Step 3: ARB 에 날짜 문구를 더한다**

`client/lib/l10n/app_ko.arb` 의 마지막 `}` 앞에 더한다(앞 항목 끝에 쉼표를 붙인다).

```json
  "dateYearMonthDay": "{year}년 {month}월 {day}일",
  "@dateYearMonthDay": {
    "description": "지난 일과 카드에 적는 날짜. 예: 2026년 9월 20일",
    "placeholders": { "year": {"type": "int"}, "month": {"type": "int"}, "day": {"type": "int"} }
  },

  "dateMonthDaySince": "{month}월 {day}일부터",
  "@dateMonthDaySince": {
    "description": "이룸이 휴대폰이 연결된 날. 예: 9월 18일부터",
    "placeholders": { "month": {"type": "int"}, "day": {"type": "int"} }
  },

  "weekdayShort": "{weekday, select, mon{월} tue{화} wed{수} thu{목} fri{금} sat{토} sun{일} other{}}",
  "@weekdayShort": {
    "description": "짧은 요일. weekday 는 mon·tue·wed·thu·fri·sat·sun 중 하나다.",
    "placeholders": { "weekday": {"type": "String"} }
  },

  "creditResetAt": "{month}월 {day}일({weekday}) {hour}시",
  "@creditResetAt": {
    "description": "AI 크레딧이 다시 채워지는 시각. weekday 는 weekdayShort 결과다. 예: 9월 28일(월) 0시",
    "placeholders": {
      "month": {"type": "int"}, "day": {"type": "int"},
      "weekday": {"type": "String"}, "hour": {"type": "int"}
    }
  },

  "creditResetAtMinute": "{month}월 {day}일({weekday}) {hour}시 {minute}분",
  "@creditResetAtMinute": {
    "description": "creditResetAt 에서 분이 0이 아닐 때. 예: 9월 29일(화) 3시 30분",
    "placeholders": {
      "month": {"type": "int"}, "day": {"type": "int"},
      "weekday": {"type": "String"}, "hour": {"type": "int"}, "minute": {"type": "int"}
    }
  },

  "creditResetFallback": "다음 주 월요일 0시",
  "@creditResetFallback": { "description": "다음 초기화 시각을 서버가 주지 않았을 때의 문구" }
```

- [ ] **Step 4: 헬퍼를 만든다**

`client/lib/core/l10n/batchim.dart`

```dart
/// 이름 끝 글자의 받침 유무를 ARB 의 `select` 가 읽는 값으로 돌려준다.
///
/// 한국어 조사(이/가·을/를·은/는)는 **받침이 있느냐**로 갈리는데 이름은 보호자가 직접 적어서
/// 코드가 미리 알 수 없다. 조사 글자 자체는 ARB 문구가 정하고(`{batchim, select,
/// yes{이} other{가}}`), 코드는 판정값만 준다 — 다른 언어 ARB 는 이 값을 쓰지 않는다.
///
/// 한글 음절이 아니면(영문·숫자·이모지·빈 문자열) `no` 다 (기존 `KoreanParticle` 과 같다).
/// 한글 음절은 U+AC00 부터 28개 종성 주기로 배열된다. 나머지가 0이면 받침이 없다.
String batchimOf(String name) {
  if (name.isEmpty) return 'no';
  final code = name.codeUnitAt(name.length - 1);
  if (code < 0xAC00 || code > 0xD7A3) return 'no';
  return (code - 0xAC00) % 28 != 0 ? 'yes' : 'no';
}
```

`client/lib/core/l10n/date_labels.dart`

```dart
import '../../l10n/app_localizations.dart';

/// `DateTime.weekday`(1=월 … 7=일) → ARB `select` 키.
const _weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// 날짜·요일 문구. 순서·단위·요일 이름은 언어마다 ARB 가 정한다 — 코드가 `월`·`일` 을 붙이지 않는다.
extension DateLabels on AppLocalizations {
  /// `월` 같은 짧은 요일.
  String weekdayShortOf(DateTime d) => weekdayShort(_weekdayKeys[d.weekday - 1]);

  /// `2026년 9월 20일`
  String yearMonthDay(DateTime d) => dateYearMonthDay(d.year, d.month, d.day);

  /// `9월 18일부터`
  String monthDaySince(DateTime d) => dateMonthDaySince(d.month, d.day);

  /// `9월 28일(월) 0시` — 분이 0이면 분을 적지 않는다.
  String resetAt(DateTime d) => d.minute == 0
      ? creditResetAt(d.month, d.day, weekdayShortOf(d), d.hour)
      : creditResetAtMinute(
          d.month,
          d.day,
          weekdayShortOf(d),
          d.hour,
          d.minute,
        );
}
```

- [ ] **Step 5: 생성하고 통과를 확인한다**

```bash
cd client && flutter gen-l10n && flutter test test/l10n/ && flutter analyze
```
Expected: **PASS**, `No issues found!`. 감사기: `dart run tool/l10n_ko_audit.dart --base 99b65ac0` → `기준 커밋에 없는 것 0개`(날짜 문구 조각 `부터`·`일(` 등이 기준 소스에 있다).

- [ ] **Step 6: 커밋 (`/pro-commit`)**

```bash
git add client/lib/core/l10n/batchim.dart client/lib/core/l10n/date_labels.dart client/lib/l10n client/test/l10n/batchim_test.dart client/test/l10n/date_labels_test.dart client/test/l10n/text_limit_grapheme_test.dart
```

---

# 2단계 — 문구 추출 (Task 12~23)

폴더 단위로 사용자 노출 한글을 ARB 로 옮긴다. 대상 목록은 `origin/develop`(`0164a36a`)에서 Task 9 의 검사기로 **실제로 뽑은** 파일과 줄 번호이고(Task 6 이후 기준), 구현 중 줄 번호는 앞선 Task 때문에 조금 밀릴 수 있어 **검사기 출력이 최종 기준**이다.

| 폴더 | Task | 파일 | 줄 |
| --- | --- | ---: | ---: |
| `core/` | 12 | 11 | 28 |
| `shared/` | 13 | 2 | 9 |
| `features/auth` | 14 | 9 | 40 |
| `features/onboarding` | 15 | 11 | 40 |
| `features/link` | 16 | 6 | 52 |
| `features/profile` | 17 | 8 | 79 |
| `features/credit` | 18 | 3 | 25 |
| `features/notice` | 19 | 3 | 4 |
| `features/guardian` 도메인·데이터·응용 | 20 | 3 | 23 |
| `features/guardian/presentation` 화면 | 21 | 10 | 99 |
| `features/guardian/presentation/widgets` | 22 | 20 | 106 |
| `features/child` | 23 | 8 | 35 |
| **합계** | | **94** | **540** |

각 Task 는 **검사기 → 감사기 → `flutter analyze` → 해당 폴더 테스트 → PNG 0건**으로 끝난다. 이 단계에서 `ko` 화면은 한 글자도 달라지지 않는다. 순서는 의존 순이다(공용 위젯 → 모델 → 기능별).

## Task 12: core — 공용 위젯·앱 상태·실패 문구

**Files:**
- Modify: 아래 표의 11개 파일. 그리고 `ElumScaffold.backLabel` 상수를 없애면서 참조 5곳을 함께 고친다 — `client/lib/features/guardian/presentation/routine_input_screen.dart:189`, `client/lib/features/guardian/presentation/widgets/routine_flow_scaffold.dart:296`, `client/lib/features/child/presentation/child_stars_screen.dart:138`, `client/lib/features/child/presentation/child_routine_detail_screen.dart:374`(모두 `semanticLabel: ElumScaffold.backLabel` → `context.l10n.commonBack`)
- Modify: `client/lib/l10n/app_ko.arb`(+ 생성물)
- Modify(상수 참조 테스트): `client/test/elum_dialog_test.dart:67-68,78`, `client/test/child_elumi_settings_test.dart:196`, `client/test/mode_switch_no_pin_test.dart:135`
- Test: `client/test/l10n/core_messages_ko_test.dart`, `client/test/l10n/failure_sentence_test.dart`, `client/test/l10n/app_failure_l10n_test.dart`

**Interfaces:**
- Consumes: `context.l10n`·`appL10n` (Task 3), `commonConfirm`·`commonRetry` (Task 1)
- Produces: ARB 키 `commonPopupClose` `commonBack` `commonScreenNotFound` `commonAd` `commonAppInfo` `commonRetryLater` `commonRetryWithCode` `sentenceStop` `failureHintOffline` `failureHintTimeout` `failureHintBadCertificate` `coachStepLabel` `coachCloseHint` `coachNextHint` `coachTapToClose` `coachTapToNext` `loginSceneEyebrow` `loginSceneTitle` `appStatus*`; `String failureSentence(String? title, String body, {String stop = '.'})`

대상(`app.dart` 의 `title: '이룸'` 은 Task 6 에서 끝났다):

| 파일 | 줄 수 | 줄 |
| --- | ---: | --- |
| `client/lib/core/ads/ad_native_slot.dart` | 1 | 126 |
| `client/lib/core/app_status/app_status_gate.dart` | 9 | 70-71, 89, 91, 93, 106, 108-109, 112 |
| `client/lib/core/network/app_failure.dart` | 3 | 111-113 |
| `client/lib/core/widgets/app_info_tile.dart` | 1 | 24 |
| `client/lib/core/widgets/elum_scaffold.dart` | 1 | 104 |
| `client/lib/core/widgets/show_failure.dart` | 1 | 54 |
| `client/lib/core/widgets/elum_dialog.dart` | 2 | 118, 162 |
| `client/lib/core/widgets/login_scene.dart` | 2 | 360, 375 |
| `client/lib/core/widgets/coach_mark_overlay.dart` | 4 | 347, 349, 526, 553 |
| `client/lib/core/widgets/elum_error_view.dart` | 3 | 120, 154, 160 |
| `client/lib/core/router/app_router.dart` | 1 | 588 |
| **합계 11개 파일** | **28** | |

- [ ] **Step 1: 기준선을 센다**

Run: `cd client && dart run tool/check_hangul_literals.dart lib/core | tail -1`
Expected: `--- 사용자 노출 한글 리터럴 28줄` (종료 코드 1)

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`client/test/l10n/core_messages_ko_test.dart`

```dart
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 옮긴 공용 문구가 옛 한국어와 같다 — 코드가 조립하던 것(보간·접두)은 값으로 고정한다.
void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  test('팝업·뒤로가기·찾을 수 없는 화면', () {
    expect(ko.commonPopupClose, '팝업 닫기');
    expect(ko.commonBack, '뒤로 가기');
    expect(ko.commonScreenNotFound, '화면을 찾을 수 없어요');
    expect(ko.commonRetryLater, '잠시 후 다시 해주세요');
  });

  test('다시 시도 — 에러 코드가 있으면 괄호로 붙는다', () {
    expect(ko.commonRetry, '다시 시도');
    expect(ko.commonRetryWithCode('E-NET-OFFLINE'), '다시 시도 (E-NET-OFFLINE)');
  });

  test('코치마크 낭독 문구', () {
    expect(
      ko.coachStepLabel(2, 3, '이룸이가 수행할 새로운 일과를 만들 수 있어요'),
      '안내 2/3. 이룸이가 수행할 새로운 일과를 만들 수 있어요',
    );
    expect(ko.coachCloseHint, '안내 닫기');
    expect(ko.coachNextHint, '다음 안내');
    expect(ko.coachTapToClose, '화면을 누르면 닫혀요');
    expect(ko.coachTapToNext, '화면을 누르면 다음으로 넘어가요');
  });

  test('네트워크 안내와 문장 끝', () {
    expect(ko.failureHintOffline, '인터넷 연결을 확인해주세요');
    expect(ko.failureHintTimeout, '연결이 느려요. 잠시 후 다시 해주세요');
    expect(ko.failureHintBadCertificate, '안전하지 않은 연결이에요. 다른 망에서 해주세요');
    expect(ko.sentenceStop, '.');
  });
}
```

`client/test/l10n/failure_sentence_test.dart`

```dart
import 'package:elum/core/widgets/show_failure.dart';
import 'package:flutter_test/flutter_test.dart';

/// 제목과 할 일을 한 문장으로 잇는다. 끝맺는 문장부호는 언어마다 다르다(일본어·중국어 `。`).
void main() {
  test('기본은 마침표다 — 기존 한국어 문장 그대로', () {
    expect(
      failureSentence('로그인하지 못했어요', '잠시 후 다시 시도해주세요'),
      '로그인하지 못했어요.\n잠시 후 다시 시도해주세요',
    );
  });

  test('제목이 이미 문장부호로 끝나면 더하지 않는다 — 전각 문장부호 포함', () {
    expect(failureSentence('다시 할까요?', '확인해주세요'), '다시 할까요?\n확인해주세요');
    expect(
      failureSentence('ログインできませんでした。', 'もう一度お試しください'),
      'ログインできませんでした。\nもう一度お試しください',
    );
    expect(failureSentence('できましたか！', 'どうぞ'), 'できましたか！\nどうぞ');
  });

  test('문장부호가 없으면 stop 을 붙인다', () {
    expect(
      failureSentence('ログインできませんでした', 'もう一度お試しください', stop: '。'),
      'ログインできませんでした。\nもう一度お試しください',
    );
  });

  test('제목이 비면 할 일만 돌려준다', () {
    expect(failureSentence(null, '잠시 후 다시 해주세요'), '잠시 후 다시 해주세요');
    expect(failureSentence('', '잠시 후 다시 해주세요'), '잠시 후 다시 해주세요');
  });
}
```

`client/test/l10n/app_failure_l10n_test.dart`

```dart
import 'package:elum/core/l10n/current_l10n.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/l10n/app_localizations_ko.dart';
import 'package:flutter_test/flutter_test.dart';

/// `AppFailure.hint` 는 번역 문구를 쓰되, **서버가 준 문구가 이기는 규칙(#347)은 그대로**다.
class _FakeL10n extends AppLocalizationsKo {
  @override
  String get failureHintOffline => 'OFFLINE-HINT';
}

void main() {
  tearDown(setAppL10nForTest);

  test('hint 는 앱 언어의 문구다', () {
    setAppL10nForTest(_FakeL10n());
    expect(const AppFailure(fault: NetworkFault.offline).hint, 'OFFLINE-HINT');
  });

  test('기본(ko)은 옛 문구와 같다', () {
    expect(const AppFailure(fault: NetworkFault.offline).hint, '인터넷 연결을 확인해주세요');
    expect(const AppFailure(fault: NetworkFault.timeout).hint, '연결이 느려요. 잠시 후 다시 해주세요');
    expect(const AppFailure(fault: NetworkFault.none).hint, isNull);
  });

  test('서버 문구가 있으면 서버 문구가 이긴다 — 언어와 무관', () {
    setAppL10nForTest(_FakeL10n());
    const failure = AppFailure(
      fault: NetworkFault.none,
      server: ServerError(
        code: ServerErrorCode.unknown,
        message: '서버가 준 문구예요',
        statusCode: 403,
      ),
    );
    expect(failure.bodyOr('화면 기본 문구'), '서버가 준 문구예요');
    expect(failure.messageOr('화면 기본 문구'), '서버가 준 문구예요');
  });

  test('안내를 붙일 때는 화면 문구의 첫 문장만 쓴다 — 일본어 `。` 도 문장 끝이다', () {
    setAppL10nForTest(_FakeL10n());
    const failure = AppFailure(fault: NetworkFault.offline);
    expect(
      failure.bodyOr('일과를 불러오지 못했어요. 다시 해주세요'),
      '일과를 불러오지 못했어요 · OFFLINE-HINT',
    );
    expect(
      failure.bodyOr('読み込めませんでした。もう一度お試しください'),
      '読み込めませんでした · OFFLINE-HINT',
    );
  });
}
```

Run: `cd client && flutter test test/l10n/core_messages_ko_test.dart test/l10n/failure_sentence_test.dart test/l10n/app_failure_l10n_test.dart`
Expected: **FAIL** — 키·`stop` 인자·`failureHintOffline` 이 없다.

- [ ] **Step 3: 특수 문구를 ARB 에 더하고 구조를 바꾼다**

`client/lib/l10n/app_ko.arb` 에 더한다(나머지 단순 문구는 Step 4 에서 규칙대로 더한다).

```json
  "commonPopupClose": "팝업 닫기",
  "@commonPopupClose": { "description": "팝업 바깥 배경 막을 낭독기가 읽는 이름" },

  "commonBack": "뒤로 가기",
  "@commonBack": { "description": "뒤로가기 화살표를 낭독기가 읽는 이름" },

  "commonScreenNotFound": "화면을 찾을 수 없어요",
  "@commonScreenNotFound": { "description": "잘못된 경로로 들어왔을 때의 화면 문구" },

  "commonRetryLater": "잠시 후 다시 해주세요",
  "@commonRetryLater": { "description": "서버가 이유를 주지 않은 일시 실패의 기본 안내" },

  "commonRetryWithCode": "다시 시도 ({code})",
  "@commonRetryWithCode": {
    "description": "실패 화면의 다시 시도 버튼. 괄호 안은 추적용 에러 코드(번역하지 않는다)",
    "placeholders": { "code": { "type": "String" } }
  },

  "sentenceStop": ".",
  "@sentenceStop": { "description": "제목 문장이 문장부호 없이 끝날 때 붙이는 마침표. 일본어·중국어는 。" },

  "failureHintOffline": "인터넷 연결을 확인해주세요",
  "@failureHintOffline": { "description": "서버에 닿지 못했을 때(오프라인) 무엇을 하면 되는지" },

  "failureHintTimeout": "연결이 느려요. 잠시 후 다시 해주세요",
  "@failureHintTimeout": { "description": "서버가 제때 답하지 않았을 때의 안내" },

  "failureHintBadCertificate": "안전하지 않은 연결이에요. 다른 망에서 해주세요",
  "@failureHintBadCertificate": { "description": "공용 와이파이 가로채기 등 인증서 문제의 안내" },

  "coachStepLabel": "안내 {index}/{total}. {message}",
  "@coachStepLabel": {
    "description": "코치마크 한 단계를 낭독기가 읽는 문장. message 는 강조 표식을 걷어낸 안내문",
    "placeholders": {
      "index": { "type": "int" },
      "total": { "type": "int" },
      "message": { "type": "String" }
    }
  },
```

`client/lib/core/widgets/show_failure.dart` — `showFailure` 의 확인 버튼과 `failureSentence` 를 바꾼다.

```dart
  final l10n = context.l10n;
  await showElumDialog<void>(
    context: context,
    // 제목이 `무엇이 안 됐는지`를 이미 말하므로, 네트워크 안내가 있으면 할 일
    // 자리를 그 안내로 바꾼다. 둘을 잇으면 할 일이 두 개가 된다 (#428).
    title: failureSentence(
      title,
      title == null
          ? failure.bodyOr(fallback)
          : failure.serverMessage ?? failure.hint ?? fallback,
      stop: l10n.sentenceStop,
    ),
    code: failure.badgeOr(fallbackCode),
    icon: ElumDialogIcon.alert,
    actions: [
      ElumDialogAction(label: l10n.commonConfirm, tone: ElumDialogTone.danger),
    ],
  );
}

/// 제목과 할 일을 시안 문장 모양(`로그인하지 못했어요.\n잠시 후 다시 시도해주세요`)으로 잇는다.
///
/// 제목이 이미 문장부호로 끝나면 문장부호를 더하지 않는다 — `?` 뒤에 `.` 가 붙는다.
/// 전각 문장부호(`。！？`)도 문장 끝이다. 붙일 문장부호는 언어마다 달라 [stop] 으로 받는다.
@visibleForTesting
String failureSentence(String? title, String body, {String stop = '.'}) {
  if (title == null || title.isEmpty) return body;
  final ended = RegExp(r'[.!?。！？]$').hasMatch(title);
  return '${ended ? title : '$title$stop'}\n$body';
}
```
(`import '../l10n/l10n_context.dart';` 를 더한다. `showFailure` 가 `await` 전에 `context.l10n` 을 잡으므로 lint 가 걸리지 않는다.)

`client/lib/core/network/app_failure.dart:111-113`(`hint`)과 `_headline`:

```dart
  String? get hint => switch (fault) {
    NetworkFault.offline => appL10n.failureHintOffline,
    NetworkFault.timeout => appL10n.failureHintTimeout,
    NetworkFault.badCertificate => appL10n.failureHintBadCertificate,
    _ => null,
  };
```

```dart
  /// 문구의 첫 문장 — `무엇이 안 됐는지`. 첫 문장 끝(`. ` 또는 `。`)에서 자르고 그 문장부호는 뺀다.
  static String _headline(String text) {
    final end = RegExp(r'(\. |。)').firstMatch(text);
    return end == null ? text : text.substring(0, end.start);
  }
```
(`import '../l10n/current_l10n.dart';` 를 더한다.)

`client/lib/core/widgets/elum_dialog.dart` — 배경 막 이름 상수(118행)를 없애고 context 에서 읽는다.

```dart
    // 배경 막을 읽어 줄 이름 (#393 S7). 번역 문구라 context 에서 읽는다.
    barrierLabel: context.l10n.commonPopupClose,
```
(99행. 118행의 `const elumDialogBarrierLabel = '팝업 닫기';` 와 그 위 주석을 지운다.) 기본 확인 버튼(162행):

```dart
    final resolved = actions.isEmpty
        ? <ElumDialogAction<T>>[ElumDialogAction(label: context.l10n.commonConfirm)]
        : actions;
```

`client/lib/core/widgets/elum_scaffold.dart` — 104행 `static const backLabel = '뒤로 가기';` 와 그 주석을 지우고, 208행의 `label: backLabel` 을 `label: context.l10n.commonBack` 으로 바꾼다. 위 Files 의 참조 4곳도 `semanticLabel: context.l10n.commonBack` 으로 바꾼다.

`client/lib/core/widgets/coach_mark_overlay.dart:345-349`

```dart
          label: context.l10n.coachStepLabel(
            widget.index + 1,
            widget.steps.length,
            coachPlainMessage(step.message),
          ),
          onTap: _tap,
          onTapHint: last ? context.l10n.coachCloseHint : context.l10n.coachNextHint,
```
526행 `last ? context.l10n.coachTapToClose : context.l10n.coachTapToNext`, 553행 `label: context.l10n.coachCloseHint`.

`client/lib/core/router/app_router.dart:588`

```dart
    errorBuilder: (context, state) => _Placeholder(context.l10n.commonScreenNotFound),
```

`client/lib/core/widgets/elum_error_view.dart:120,154,160` — `errorCode == null ? context.l10n.commonRetry : context.l10n.commonRetryWithCode(errorCode!)`, `description ?? context.l10n.commonRetryLater`, `ElumButton(label: context.l10n.commonRetry, …)`.

`client/lib/core/app_status/app_status_gate.dart` — `_openStore` 는 `noticeContext` 로 팝업을 띄우므로 맨 앞에서 문구를 잡는다.

```dart
  Future<void> _openStore(BuildContext noticeContext, String url) async {
    final l10n = noticeContext.l10n;
    // …(기존 코드)…
    await showFailure(
      noticeContext,
      error,
      title: l10n.appStatusStoreOpenFailedTitle,
      fallback: l10n.appStatusStoreOpenFailedFallback,
      fallbackCode: storeFailureCode,
    );
  }
```
`build` 안의 `_FullNotice(title: …, body: …, actionLabel: …)` 는 `context.l10n.appStatus…` 로 바꾼다. 서버가 준 점검 문구(`status.maintenanceMessage`)가 있으면 그것이 이긴다 — 이 규칙은 그대로다.


나머지 단순 문구 중 **위 코드·테스트가 이름으로 부르는 것**도 같은 파일에 더한다(이름과 `ko` 값은 아래가 정한다. 이 폴더의 나머지 문구는 Step 4 에서 규칙대로 더한다).

```json
  "commonAd": "광고",
  "@commonAd": { "description": "광고임을 알리는 라벨(일과로 오인해 누르는 것을 막는다)" },

  "commonAppInfo": "앱 정보",
  "@commonAppInfo": { "description": "설정의 앱 정보 줄 이름" },

  "coachCloseHint": "안내 닫기",
  "@coachCloseHint": { "description": "코치마크를 닫는 버튼·동작의 낭독 이름" },

  "coachNextHint": "다음 안내",
  "@coachNextHint": { "description": "코치마크 다음 단계로 가는 동작의 낭독 이름" },

  "coachTapToClose": "화면을 누르면 닫혀요",
  "@coachTapToClose": { "description": "마지막 코치마크 단계의 안내 문구" },

  "coachTapToNext": "화면을 누르면 다음으로 넘어가요",
  "@coachTapToNext": { "description": "코치마크 중간 단계의 안내 문구" },

  "loginSceneEyebrow": "오늘의 하루,",
  "@loginSceneEyebrow": { "description": "로그인 장면의 윗줄 문구" },

  "loginSceneTitle": "차근차근 함께해요",
  "@loginSceneTitle": { "description": "로그인 장면의 큰 문구" },

  "appStatusStoreOpenFailedTitle": "스토어를 열지 못했어요",
  "@appStatusStoreOpenFailedTitle": { "description": "스토어 열기 실패 팝업의 제목" },

  "appStatusStoreOpenFailedFallback": "스토어에서 이룸을 찾아 업데이트해주세요",
  "@appStatusStoreOpenFailedFallback": { "description": "스토어 열기 실패 시 직접 하는 방법 안내" },

  "appStatusMaintenanceTitle": "잠시 쉬고 있어요",
  "@appStatusMaintenanceTitle": { "description": "점검 중 화면 제목" },

  "appStatusMaintenanceBody": "조금 뒤에 다시 열어주세요",
  "@appStatusMaintenanceBody": { "description": "점검 중 화면의 기본 설명(서버가 문구를 주면 그것이 이긴다)" },

  "appStatusRecheck": "다시 확인하기",
  "@appStatusRecheck": { "description": "점검 화면의 버튼" },

  "appStatusUpdateTitle": "새 이룸이 나왔어요",
  "@appStatusUpdateTitle": { "description": "강제 업데이트 화면 제목" },

  "appStatusUpdateBody": "앱을 새로 받아야 이어서 쓸 수 있어요.\n스토어에서 이룸을 업데이트해주세요",
  "@appStatusUpdateBody": { "description": "강제 업데이트 화면 설명" },

  "appStatusUpdated": "업데이트했어요",
  "@appStatusUpdated": { "description": "스토어 주소가 없을 때의 버튼" },

  "appStatusGoUpdate": "업데이트하러 가기",
  "@appStatusGoUpdate": { "description": "스토어로 가는 버튼" }
```

- [ ] **Step 4: 나머지 문구를 규칙대로 옮긴다**

**변환 규칙** (아래 대상 파일 전부에 같다. 한국어 문구는 한 글자도 바꾸지 않는다 — 감사기가 잡는다)

1. **위젯 안의 문구**: `Text('확인')` → `Text(context.l10n.commonConfirm)`. 키는 `app_ko.arb` 에 `"키": "확인"` 과 `"@키": { "description": "어디에 쓰이는 문구인지" }` 로 더한다. 같은 문구가 이미 있으면(`commonConfirm`·`commonCancel`·`commonClose`·`commonNext`·`commonRetry` 등) 키를 재사용한다. `const` 에 걸리면 가장 가까운 바깥 `const` 를 뗀다(analyze 가 위치를 알려준다). 파일 맨 위에 `core/l10n/l10n_context.dart`(`context.l10n`)·`core/l10n/current_l10n.dart`(`appL10n`) import 를 더한다.
2. **보간**: `'$name의 하루'` → ARB `"{name}의 하루"` 와 `"@키": { "placeholders": { "name": { "type": "String" } } }` → `context.l10n.키(name)`. 숫자는 `"type": "int"`.
3. **`String` 인자로 넘기는 문구**(`showFailure(title:, fallback:)`·`ElumDialogAction(label:)`): 호출 지점에서 `context.l10n` 으로 넘긴다. `await` 뒤에서 `context` 를 쓰면 `use_build_context_synchronously` 가 걸리므로 함수 맨 앞에서 `final l10n = context.l10n;` 로 잡아 둔다.
4. **상수·기본값**: 생성자 기본값(`this.label = '…'`)은 `String? label` 로 바꾸고 `build` 에서 `label ?? context.l10n.키` 로 푼다. `static const` 문구는, 다른 파일·테스트가 참조하면 `static String get` 으로 바꿔 `appL10n.키` 를 돌려주고(API 이름 유지), 같은 파일 안에서만 쓰면 `build` 에서 푼다. 상수를 `const` 로 참조하던 테스트는 한글 리터럴로 바꾼다.
5. **`context` 가 없는 층**(도메인 getter·enum 라벨·저장소 대체 문구): getter API 를 그대로 두고 값만 `appL10n.키` 로 돌려준다. 이런 getter 는 `context.l10n` 을 읽는 위젯의 `build` 안에서만 부른다(언어가 바뀔 때 같이 다시 그려진다).
6. **조사**: `'$name${name.objectParticle} …'` → ARB `"{name}{batchim, select, yes{을} other{를}} …"`(`batchim` 도 `String` 자리표시자) → `context.l10n.키(name, batchimOf(name))`. 코드가 조사 글자를 붙이지 않는다. `import 'package:elum/core/l10n/batchim.dart';` (프로젝트 내부는 상대 경로).
7. **단위·복수**: `'$n개'` → `"{count, plural, other{{count}개}}"`(ko 는 `other` 하나. 영어 등은 번역 단계에서 `one` 을 더한다).
8. **날짜**: `core/l10n/date_labels.dart` 의 `yearMonthDay`·`monthDaySince`·`resetAt` 을 쓴다.
9. `\n`·`*강조*` 같은 표식은 문구 그대로 ARB 에 옮긴다(JSON 에서는 `\n`). 작은따옴표는 ICU 에서 `''` 로 쓴다.

위 표의 줄을 위에서 아래로 처리한다. 이 폴더의 키 접두어는 `common` `coach` `appStatus` `loginScene` 이다.

- [ ] **Step 5: 생성·분석·감사**

```bash
cd client && flutter gen-l10n && flutter analyze && dart run tool/l10n_ko_audit.dart --base 99b65ac0
```
Expected: `No issues found!`, `--- 조각 N개 중 기준 커밋에 없는 것 0개`.

- [ ] **Step 6: 검사기와 테스트**

```bash
cd client && dart run tool/check_hangul_literals.dart lib/core
cd client && flutter test test/l10n/ $(grep -rlE "package:elum/core/(widgets|app_status|network|router|ads)/" test | sort)
git status --short client/test | grep -c png
```
Expected: 검사기 `0줄`(종료 0). 테스트 **PASS**(상수를 한글 리터럴로 바꾼 `elum_dialog_test`·`child_elumi_settings_test`·`mode_switch_no_pin_test` 포함 — `find.bySemanticsLabel('팝업 닫기')`, `labeled('뒤로 가기')`). PNG 변경 `0`.

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add client/lib/core/ads/ad_native_slot.dart client/lib/core/app_status/app_status_gate.dart client/lib/core/network/app_failure.dart client/lib/core/widgets/app_info_tile.dart client/lib/core/widgets/elum_scaffold.dart client/lib/core/widgets/show_failure.dart client/lib/core/widgets/elum_dialog.dart client/lib/core/widgets/login_scene.dart client/lib/core/widgets/coach_mark_overlay.dart client/lib/core/widgets/elum_error_view.dart client/lib/core/router/app_router.dart client/lib/features/guardian/presentation/routine_input_screen.dart client/lib/features/guardian/presentation/widgets/routine_flow_scaffold.dart client/lib/features/child/presentation/child_stars_screen.dart client/lib/features/child/presentation/child_routine_detail_screen.dart client/lib/l10n client/test/l10n/core_messages_ko_test.dart client/test/l10n/failure_sentence_test.dart client/test/l10n/app_failure_l10n_test.dart client/test/elum_dialog_test.dart client/test/child_elumi_settings_test.dart client/test/mode_switch_no_pin_test.dart
```

## Task 13: shared — 일과 모델·보상 프리셋·조사 확장 표식

**Files:**
- Modify: 아래 표의 2개 파일(`client/lib/shared/models/routine.dart`, `client/lib/shared/models/reward_preset.dart`), `client/lib/shared/utils/korean_particle.dart:23,26,29,32`(표식), `client/lib/l10n/app_ko.arb`(+ 생성물)
- Test: `client/test/l10n/shared_messages_ko_test.dart`

**Interfaces:**
- Consumes: `appL10n` (Task 3), `batchimOf`·`yearMonthDay` (Task 11)
- Produces: ARB 키 `routineForeignCreator(name, batchim)` `routineForeignCreatorUnknown` `routineDefaultTitle` `rewardPresetSnack` `rewardPresetVideo` `rewardPresetPlay` `rewardPresetWalk` `rewardPresetCustom`. `Routine.foreignCreatorLabel`·`displayTitle`·`scheduledDateLabel`·`RewardPreset.label` 의 **API 는 그대로**다.

대상:

| 파일 | 줄 수 | 줄 |
| --- | ---: | --- |
| `client/lib/shared/models/reward_preset.dart` | 5 | 11-14, 18 |
| `client/lib/shared/models/routine.dart` | 4 | 91-92, 122, 150 |
| **합계 2개 파일** | **9** | |

`KoreanParticle` 확장(`korean_particle.dart`)은 이 Task 이후 `routine.dart` 가 더는 쓰지 않는다. 남은 호출은 `invite_code_screen`·`invite_enter_screen`(Task 17), `child_home_screen`·`reward_character`(Task 23)이고 그곳에서 `batchimOf` 로 바꾼다. **파일 삭제는 하지 않는다**(결정 D6, 파일 삭제는 사용자 허락) — 4줄에 표식만 단다.

- [ ] **Step 1: 기준선을 센다**

Run: `cd client && dart run tool/check_hangul_literals.dart lib/shared | tail -1`
Expected: `--- 사용자 노출 한글 리터럴 13줄`(표 9줄 + 조사 확장 4줄, 종료 코드 1)

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`client/test/l10n/shared_messages_ko_test.dart`

```dart
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/shared/models/reward_preset.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 조사·날짜를 ARB 가 넘겨받아도 `ko` 결과가 옛 직접 조립과 같다.
void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  test('만든 사람 문구 — 받침에 따라 이/가', () {
    expect(ko.routineForeignCreator('민준', 'yes'), '민준이 만든 일과예요');
    expect(ko.routineForeignCreator('루미', 'no'), '루미가 만든 일과예요');
    expect(ko.routineForeignCreatorUnknown, '다른 보호자가 만든 일과예요');
  });

  test('Routine 의 문구 getter 는 API 그대로 ko 문구를 준다', () {
    const base = Routine(id: 'r1', createdByMe: false);
    expect(base.foreignCreatorLabel, '다른 보호자가 만든 일과예요');
    expect(base.copyWith(creatorName: '엄마').foreignCreatorLabel, '엄마가 만든 일과예요');
    expect(base.copyWith(creatorName: '아빠').foreignCreatorLabel, '아빠가 만든 일과예요');
    expect(base.copyWith(creatorName: '선생님').foreignCreatorLabel, '선생님이 만든 일과예요');
    expect(const Routine(id: 'r2').displayTitle, '오늘의 일과');
    expect(
      Routine(id: 'r3', scheduledAt: DateTime(2026, 9, 20)).scheduledDateLabel,
      '2026년 9월 20일',
    );
    expect(const Routine(id: 'r4').scheduledDateLabel, '');
  });

  test('보상 프리셋 라벨', () {
    expect(RewardPreset.snack.label, '좋아하는 간식');
    expect(RewardPreset.video.label, '유튜브 10분');
    expect(RewardPreset.play.label, '좋아하는 놀이');
    expect(RewardPreset.walk.label, '산책');
    expect(RewardPreset.custom.label, '직접 입력');
    expect(RewardPreset.snack.key, 'SNACK');
    expect(RewardPreset.snack.emoji, '🍪');
  });
}
```

Run: `cd client && flutter test test/l10n/shared_messages_ko_test.dart`
Expected: **FAIL** — `routineForeignCreator` 등 키가 없다.

- [ ] **Step 3: 특수 문구와 구조를 바꾼다**

`client/lib/l10n/app_ko.arb` 에 더한다.

```json
  "routineForeignCreator": "{name}{batchim, select, yes{이} other{가}} 만든 일과예요",
  "@routineForeignCreator": {
    "description": "다른 보호자가 만든 일과에 붙는 문구. name 은 만든 사람이 이 이룸이 안에서 불리는 이름. batchim 은 한국어 조사 선택용(yes/no)이라 다른 언어는 쓰지 않는다",
    "placeholders": { "name": { "type": "String" }, "batchim": { "type": "String" } }
  },

  "routineForeignCreatorUnknown": "다른 보호자가 만든 일과예요",
  "@routineForeignCreatorUnknown": { "description": "만든 사람 이름을 모를 때의 문구" },

  "routineDefaultTitle": "오늘의 일과",
  "@routineDefaultTitle": { "description": "AI 가 제목을 못 만들었을 때의 대체 제목" },

  "rewardPresetSnack": "좋아하는 간식",
  "@rewardPresetSnack": { "description": "보상 프리셋 칩" },
  "rewardPresetVideo": "유튜브 10분",
  "@rewardPresetVideo": { "description": "보상 프리셋 칩" },
  "rewardPresetPlay": "좋아하는 놀이",
  "@rewardPresetPlay": { "description": "보상 프리셋 칩" },
  "rewardPresetWalk": "산책",
  "@rewardPresetWalk": { "description": "보상 프리셋 칩" },
  "rewardPresetCustom": "직접 입력",
  "@rewardPresetCustom": { "description": "프리셋에 없는 보상을 직접 적는 칩" },
```

`client/lib/shared/models/routine.dart` — 3행의 `import '../utils/korean_particle.dart';` 를 세 줄로 바꾼다.

```dart
import '../../core/l10n/batchim.dart';
import '../../core/l10n/current_l10n.dart';
import '../../core/l10n/date_labels.dart';
```

91~92행(`foreignCreatorLabel`), 122행(`displayTitle`), 147~151행(`scheduledDateLabel`)

```dart
  String? get foreignCreatorLabel {
    if (createdByMe != false) return null;
    final name = creatorName?.trim();
    if (name == null || name.isEmpty) return appL10n.routineForeignCreatorUnknown;
    // 조사 글자는 문구가 정한다 — 코드는 받침 판정값만 넘긴다
    return appL10n.routineForeignCreator(name, batchimOf(name));
  }
```

```dart
  String get displayTitle =>
      title.trim().isNotEmpty ? title.trim() : appL10n.routineDefaultTitle;
```

```dart
  String get scheduledDateLabel {
    final at = scheduledAt;
    if (at == null) return '';
    return appL10n.yearMonthDay(at);
  }
```

`client/lib/shared/models/reward_preset.dart` — 생성자에서 `label` 을 빼고 getter 로 바꾼다(상단에 `import '../../core/l10n/current_l10n.dart';`).

```dart
enum RewardPreset {
  snack('SNACK', '🍪'),
  video('VIDEO', '📺'),
  play('PLAY', '🧸'),
  walk('WALK', '🚶'),

  /// 프리셋에 없는 것을 보호자가 직접 적은 경우.
  /// **대표 그림이 없다** — 보호자가 적지 않은 별을 앱이 지어내면 안 된다 (#275).
  custom('CUSTOM', '');

  const RewardPreset(this.key, this.emoji);

  /// 서버로 보내는 값. enum 이름(`snack`)이 아니라 이 값을 쓴다.
  final String key;

  /// 보호자 화면 칩에 보여줄 이름 — 앱 언어의 문구다.
  String get label => switch (this) {
    RewardPreset.snack => appL10n.rewardPresetSnack,
    RewardPreset.video => appL10n.rewardPresetVideo,
    RewardPreset.play => appL10n.rewardPresetPlay,
    RewardPreset.walk => appL10n.rewardPresetWalk,
    RewardPreset.custom => appL10n.rewardPresetCustom,
  };

  /// 아동 화면용. 프리셋 그림이 준비되기 전까지 이모지로 대신한다.
  /// **[custom]은 비어 있다** — 직접 적은 말에 어울리는 그림은 앱이 알 수 없다.
  final String emoji;
  // …(selectable·fromKey·emojiOf 는 그대로)…
```

`client/lib/shared/utils/korean_particle.dart` — 조사 판정이 ARB(`batchim`)로 넘어갔다. 호출이 모두 사라지면 삭제 후보(결정 D6)라는 표시를 4줄에 단다.

```dart
  String get subjectParticle => _hasFinalConsonant ? '이' : '가'; // l10n-ignore: 한국어 조사 판정 — ARB(batchim select)가 대체. 삭제는 사용자 확인 후(D6)

  String get objectParticle => _hasFinalConsonant ? '을' : '를'; // l10n-ignore: 위와 같다

  String get topicParticle => _hasFinalConsonant ? '은' : '는'; // l10n-ignore: 위와 같다

  String get withParticle => _hasFinalConsonant ? '과' : '와'; // l10n-ignore: 위와 같다
```

- [ ] **Step 4: 나머지 문구를 규칙대로 옮긴다**

**변환 규칙** (아래 대상 파일 전부에 같다. 한국어 문구는 한 글자도 바꾸지 않는다 — 감사기가 잡는다)

1. **위젯 안의 문구**: `Text('확인')` → `Text(context.l10n.commonConfirm)`. 키는 `app_ko.arb` 에 `"키": "확인"` 과 `"@키": { "description": "어디에 쓰이는 문구인지" }` 로 더한다. 같은 문구가 이미 있으면(`commonConfirm`·`commonCancel`·`commonClose`·`commonNext`·`commonRetry` 등) 키를 재사용한다. `const` 에 걸리면 가장 가까운 바깥 `const` 를 뗀다(analyze 가 위치를 알려준다). 파일 맨 위에 `core/l10n/l10n_context.dart`(`context.l10n`)·`core/l10n/current_l10n.dart`(`appL10n`) import 를 더한다.
2. **보간**: `'$name의 하루'` → ARB `"{name}의 하루"` 와 `"@키": { "placeholders": { "name": { "type": "String" } } }` → `context.l10n.키(name)`. 숫자는 `"type": "int"`.
3. **`String` 인자로 넘기는 문구**(`showFailure(title:, fallback:)`·`ElumDialogAction(label:)`): 호출 지점에서 `context.l10n` 으로 넘긴다. `await` 뒤에서 `context` 를 쓰면 `use_build_context_synchronously` 가 걸리므로 함수 맨 앞에서 `final l10n = context.l10n;` 로 잡아 둔다.
4. **상수·기본값**: 생성자 기본값(`this.label = '…'`)은 `String? label` 로 바꾸고 `build` 에서 `label ?? context.l10n.키` 로 푼다. `static const` 문구는, 다른 파일·테스트가 참조하면 `static String get` 으로 바꿔 `appL10n.키` 를 돌려주고(API 이름 유지), 같은 파일 안에서만 쓰면 `build` 에서 푼다. 상수를 `const` 로 참조하던 테스트는 한글 리터럴로 바꾼다.
5. **`context` 가 없는 층**(도메인 getter·enum 라벨·저장소 대체 문구): getter API 를 그대로 두고 값만 `appL10n.키` 로 돌려준다. 이런 getter 는 `context.l10n` 을 읽는 위젯의 `build` 안에서만 부른다(언어가 바뀔 때 같이 다시 그려진다).
6. **조사**: `'$name${name.objectParticle} …'` → ARB `"{name}{batchim, select, yes{을} other{를}} …"`(`batchim` 도 `String` 자리표시자) → `context.l10n.키(name, batchimOf(name))`. 코드가 조사 글자를 붙이지 않는다. `import 'package:elum/core/l10n/batchim.dart';` (프로젝트 내부는 상대 경로).
7. **단위·복수**: `'$n개'` → `"{count, plural, other{{count}개}}"`(ko 는 `other` 하나. 영어 등은 번역 단계에서 `one` 을 더한다).
8. **날짜**: `core/l10n/date_labels.dart` 의 `yearMonthDay`·`monthDaySince`·`resetAt` 을 쓴다.
9. `\n`·`*강조*` 같은 표식은 문구 그대로 ARB 에 옮긴다(JSON 에서는 `\n`). 작은따옴표는 ICU 에서 `''` 로 쓴다.

위 표의 줄을 위에서 아래로 처리한다. 이 폴더의 키 접두어는 ``routine` `reward`` 이다.

- [ ] **Step 5: 생성·분석·감사**

```bash
cd client && flutter gen-l10n && flutter analyze && dart run tool/l10n_ko_audit.dart --base 99b65ac0
```
Expected: `No issues found!`, `--- 조각 N개 중 기준 커밋에 없는 것 0개`.

- [ ] **Step 6: 검사기와 테스트**

```bash
cd client && dart run tool/check_hangul_literals.dart lib/shared
cd client && flutter test test/l10n/ $(grep -rlE "package:elum/shared/" test | sort)
git status --short client/test | grep -c png
```
Expected: 검사기 `0줄`(종료 0). 테스트 **PASS**. PNG 변경 `0`(골든·시안 PNG 는 `--update-goldens` 없이 그대로 통과해야 한다).

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add client/lib/shared/models/reward_preset.dart client/lib/shared/models/routine.dart client/lib/shared/utils/korean_particle.dart client/lib/l10n client/test/l10n/shared_messages_ko_test.dart
```

## Task 14: auth — 로그인·역할 선택·약관 동의 화면

**Files:**
- Modify: 아래 표의 9개 파일, `client/lib/l10n/app_ko.arb`(+ 생성물), `client/tool/l10n_ko_audit_accepted.txt`(분리해 쓴 문구 조각 2줄). (`oauth_sdk.dart` 의 제공자 이름은 로그에만 쓰여 번역하지 않는다 — 검사기가 건너뛴다. 약관 번들·파서는 하위 계획 4.)
- Test: `client/test/l10n/auth_messages_ko_test.dart`

**Interfaces:**
- Consumes: `appL10n`·`context.l10n` (Task 3)
- Produces: ARB 키 `roleGuardianWord` `roleElumiWord` `roleLabelSuffix` `roleGuardianDescription` `roleElumiDescription` `loginKakaoButton` `loginNaverButton` `loginAppleButton` `loginConnecting` `loginLastUsed` `loginDuplicate*` `loginOffline*` `loginFailed*` `consentRequiredTag` `consentOptionalTag` `consentChipRequired(label)` `consentChipOptional(label)` `consentDocumentMetaRequired(version)` `consentDocumentMetaOptional(version)` … `AppRole.roleWord`·`labelSuffix`·`label`·`description` 의 API 는 그대로.

대상:

| 파일 | 줄 수 | 줄 |
| --- | ---: | --- |
| `client/lib/features/auth/domain/app_role.dart` | 5 | 35-36, 40, 48-49 |
| `client/lib/features/auth/presentation/consent_screen.dart` | 8 | 95, 142, 148-149, 163, 172, 176-177 |
| `client/lib/features/auth/presentation/login_screen.dart` | 16 | 138-139, 145-146, 154-155, 161-162, 168-169, 175-176, 262, 274, 305, 432 |
| `client/lib/features/auth/presentation/role_select_screen.dart` | 3 | 74, 84, 87 |
| `client/lib/features/auth/presentation/consent_document_screen.dart` | 1 | 93 |
| `client/lib/features/auth/presentation/widgets/consent_all_agree_button.dart` | 1 | 83 |
| `client/lib/features/auth/presentation/widgets/consent_chip.dart` | 1 | 82 |
| `client/lib/features/auth/presentation/widgets/consent_row.dart` | 1 | 86 |
| `client/lib/features/auth/presentation/consent_document_list_screen.dart` | 4 | 31, 63, 73, 78 |
| **합계 9개 파일** | **40** | |

**해외 사용자 로그인 수단 노출 정책(스펙 8장 열린 질문, 결정 D5)은 이 Task 에서 바꾸지 않는다.** 카카오·네이버·구글·애플 4종이 모든 언어에서 그대로 보인다.

- [ ] **Step 1: 기준선을 센다**

Run: `cd client && dart run tool/check_hangul_literals.dart lib/features/auth | tail -1`
Expected: `--- 사용자 노출 한글 리터럴 40줄`(종료 코드 1)

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`client/test/l10n/auth_messages_ko_test.dart`

```dart
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/features/auth/domain/app_role.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  test('역할 카드 제목은 색이 다른 앞부분 + 나머지 — 합치면 옛 문구', () {
    expect(AppRole.guardian.roleWord, '보호자');
    expect(AppRole.elumi.roleWord, '이룸이');
    expect(AppRole.guardian.labelSuffix, '가 사용해요');
    expect(AppRole.guardian.label, '보호자가 사용해요');
    expect(AppRole.elumi.label, '이룸이가 사용해요');
    expect(AppRole.guardian.description, '일과를 만들고 관리해요');
    expect(AppRole.elumi.description, '일과를 실천해요');
  });

  test('약관 칩·문서 줄의 필수/선택 표기', () {
    expect(ko.consentChipRequired('서비스 이용약관'), '[필수] 서비스 이용약관');
    expect(ko.consentChipOptional('마케팅 수신'), '[선택] 마케팅 수신');
    expect(ko.consentDocumentMetaRequired('3'), '필수 · 버전 3');
    expect(ko.consentDocumentMetaOptional('1'), '선택 · 버전 1');
    expect(ko.consentRequiredTag, '필수');
    expect(ko.consentOptionalTag, '선택');
  });

  test('로그인 버튼', () {
    expect(ko.loginKakaoButton, '카카오로 로그인');
    expect(ko.loginNaverButton, '네이버로 로그인');
    expect(ko.loginAppleButton, 'Apple로 로그인');
    expect(ko.loginConnecting, '연결하고 있어요');
  });
}
```

Run: `cd client && flutter test test/l10n/auth_messages_ko_test.dart`
Expected: **FAIL** — 키가 없다.

- [ ] **Step 3: 특수 문구와 구조를 바꾼다**

`client/lib/l10n/app_ko.arb` 에 더한다(나머지 단순 문구는 Step 4).

```json
  "roleGuardianWord": "보호자",
  "@roleGuardianWord": { "description": "역할 카드 제목에서 색이 다른 앞부분(민트). 뒤에 roleLabelSuffix 가 이어 붙는다" },
  "roleElumiWord": "이룸이",
  "@roleElumiWord": { "description": "역할 카드 제목에서 색이 다른 앞부분(주황)" },
  "roleLabelSuffix": "가 사용해요",
  "@roleLabelSuffix": { "description": "역할 카드 제목의 나머지. 앞부분과 이어 붙여 `보호자가 사용해요` 가 된다" },
  "roleGuardianDescription": "일과를 만들고 관리해요",
  "@roleGuardianDescription": { "description": "보호자 역할 카드 설명" },
  "roleElumiDescription": "일과를 실천해요",
  "@roleElumiDescription": { "description": "이룸이 역할 카드 설명" },

  "consentRequiredTag": "필수",
  "@consentRequiredTag": { "description": "약관 행의 필수 표시" },
  "consentOptionalTag": "선택",
  "@consentOptionalTag": { "description": "약관 행의 선택 표시" },
  "consentChipRequired": "[필수] {label}",
  "@consentChipRequired": {
    "description": "약관 칩의 필수 항목",
    "placeholders": { "label": { "type": "String" } }
  },
  "consentChipOptional": "[선택] {label}",
  "@consentChipOptional": {
    "description": "약관 칩의 선택 항목",
    "placeholders": { "label": { "type": "String" } }
  },
  "consentDocumentMetaRequired": "필수 · 버전 {version}",
  "@consentDocumentMetaRequired": {
    "description": "약관 문서 화면 머리의 필수 항목 줄",
    "placeholders": { "version": { "type": "String" } }
  },
  "consentDocumentMetaOptional": "선택 · 버전 {version}",
  "@consentDocumentMetaOptional": {
    "description": "약관 문서 화면 머리의 선택 항목 줄",
    "placeholders": { "version": { "type": "String" } }
  },
```

원본이 `'${item.required ? '필수' : '선택'} · 버전 ${item.version}'` 로 삼항 연산자를 사이에 두고 있어, 감사기가 `필수 · 버전`·`선택 · 버전` 조각을 소스에서 한 덩어리로 찾지 못한다(분리해 쓴 문구가 같은 글자임을 눈으로 확인한 뒤 허용한다). `client/tool/l10n_ko_audit_accepted.txt` 에 두 줄을 적는다.

```text
필수 · 버전
선택 · 버전
```

`client/lib/features/auth/domain/app_role.dart:35-49` — `context` 가 없는 getter 라 `appL10n` 을 쓴다(API 그대로).

```dart
  String get roleWord => switch (this) {
        AppRole.guardian => appL10n.roleGuardianWord,
        AppRole.elumi => appL10n.roleElumiWord,
      };

  /// 카드 제목의 나머지. 앞부분과 이어 붙여 `보호자가 사용해요`가 된다.
  String get labelSuffix => appL10n.roleLabelSuffix;

  /// 카드 제목 전체. 색 구분이 필요 없는 곳(테스트·접근성)에서 쓴다.
  String get label => '$roleWord$labelSuffix';

  String get description => switch (this) {
        AppRole.guardian => appL10n.roleGuardianDescription,
        AppRole.elumi => appL10n.roleElumiDescription,
      };
```
(`import '../../../core/l10n/current_l10n.dart';`)

`client/lib/features/auth/presentation/consent_document_screen.dart:93`, `widgets/consent_chip.dart:82`, `widgets/consent_row.dart:86`

```dart
    // consent_document_screen.dart
    item.required
        ? context.l10n.consentDocumentMetaRequired('${item.version}')
        : context.l10n.consentDocumentMetaOptional('${item.version}'),
    // consent_chip.dart
    item.required
        ? context.l10n.consentChipRequired(item.label)
        : context.l10n.consentChipOptional(item.label),
    // consent_row.dart
    item.required ? context.l10n.consentRequiredTag : context.l10n.consentOptionalTag,
```

`client/lib/features/auth/presentation/login_screen.dart:132-176` — 실패 알림. 서버 문구가 이기는 규칙은 `_alert`(→`showFailure`)가 지키므로 기본 문구만 옮긴다. 핸들러 맨 앞에서 `final l10n = context.l10n;` 를 잡는다(SDK 호출 `await` 뒤에서 `context` 를 쓰지 않기 위해).

```dart
      case AuthOutcome.emailConflict:
        await _alert(
          result,
          title: l10n.loginDuplicateTitle,
          fallback: l10n.loginDuplicateFallback,
          fallbackCode: 'E-DUP',
        );
      case AuthOutcome.offline:
        await _alert(
          result,
          title: l10n.loginOfflineTitle,
          fallback: l10n.loginOfflineFallback,
          fallbackCode: 'E-NET',
        );
      case AuthOutcome.failedSdk:
        await _alert(
          result,
          title: l10n.loginFailedTitle,
          fallback: l10n.loginFailedFallback,
          fallbackCode: 'E-AUTH-SDK',
        );
```
`failedToken`·`failedApi`·`failed` 도 같은 두 키(`loginFailedTitle`·`loginFailedFallback`)에 코드만 다르다.


나머지 단순 문구 중 **위 코드·테스트가 이름으로 부르는 것**도 같은 파일에 더한다(이름과 `ko` 값은 아래가 정한다. 이 폴더의 나머지 문구는 Step 4 에서 규칙대로 더한다).

```json
  "loginKakaoButton": "카카오로 로그인",
  "@loginKakaoButton": { "description": "카카오 로그인 버튼" },

  "loginNaverButton": "네이버로 로그인",
  "@loginNaverButton": { "description": "네이버 로그인 버튼" },

  "loginAppleButton": "Apple로 로그인",
  "@loginAppleButton": { "description": "Apple 로그인 버튼" },

  "loginConnecting": "연결하고 있어요",
  "@loginConnecting": { "description": "소셜 로그인 진행 중 버튼 문구" },

  "loginLastUsed": "최근 로그인",
  "@loginLastUsed": { "description": "마지막으로 쓴 로그인 수단 표시" },

  "loginDuplicateTitle": "이미 가입된 계정이에요",
  "@loginDuplicateTitle": { "description": "같은 이메일로 다른 수단으로 가입돼 있을 때의 제목" },

  "loginDuplicateFallback": "처음 쓰신 방법으로 로그인해주세요",
  "@loginDuplicateFallback": { "description": "같은 경우의 안내(서버 문구가 이긴다)" },

  "loginOfflineTitle": "인터넷 연결을 확인해주세요",
  "@loginOfflineTitle": { "description": "로그인 중 오프라인일 때의 제목" },

  "loginOfflineFallback": "연결한 뒤 다시 해주세요",
  "@loginOfflineFallback": { "description": "같은 경우의 안내" },

  "loginFailedTitle": "로그인하지 못했어요",
  "@loginFailedTitle": { "description": "로그인 실패의 제목" },

  "loginFailedFallback": "잠시 후 다시 시도해주세요",
  "@loginFailedFallback": { "description": "로그인 실패의 안내(서버 문구가 이긴다)" }
```

- [ ] **Step 4: 나머지 문구를 규칙대로 옮긴다**

**변환 규칙** (아래 대상 파일 전부에 같다. 한국어 문구는 한 글자도 바꾸지 않는다 — 감사기가 잡는다)

1. **위젯 안의 문구**: `Text('확인')` → `Text(context.l10n.commonConfirm)`. 키는 `app_ko.arb` 에 `"키": "확인"` 과 `"@키": { "description": "어디에 쓰이는 문구인지" }` 로 더한다. 같은 문구가 이미 있으면(`commonConfirm`·`commonCancel`·`commonClose`·`commonNext`·`commonRetry` 등) 키를 재사용한다. `const` 에 걸리면 가장 가까운 바깥 `const` 를 뗀다(analyze 가 위치를 알려준다). 파일 맨 위에 `core/l10n/l10n_context.dart`(`context.l10n`)·`core/l10n/current_l10n.dart`(`appL10n`) import 를 더한다.
2. **보간**: `'$name의 하루'` → ARB `"{name}의 하루"` 와 `"@키": { "placeholders": { "name": { "type": "String" } } }` → `context.l10n.키(name)`. 숫자는 `"type": "int"`.
3. **`String` 인자로 넘기는 문구**(`showFailure(title:, fallback:)`·`ElumDialogAction(label:)`): 호출 지점에서 `context.l10n` 으로 넘긴다. `await` 뒤에서 `context` 를 쓰면 `use_build_context_synchronously` 가 걸리므로 함수 맨 앞에서 `final l10n = context.l10n;` 로 잡아 둔다.
4. **상수·기본값**: 생성자 기본값(`this.label = '…'`)은 `String? label` 로 바꾸고 `build` 에서 `label ?? context.l10n.키` 로 푼다. `static const` 문구는, 다른 파일·테스트가 참조하면 `static String get` 으로 바꿔 `appL10n.키` 를 돌려주고(API 이름 유지), 같은 파일 안에서만 쓰면 `build` 에서 푼다. 상수를 `const` 로 참조하던 테스트는 한글 리터럴로 바꾼다.
5. **`context` 가 없는 층**(도메인 getter·enum 라벨·저장소 대체 문구): getter API 를 그대로 두고 값만 `appL10n.키` 로 돌려준다. 이런 getter 는 `context.l10n` 을 읽는 위젯의 `build` 안에서만 부른다(언어가 바뀔 때 같이 다시 그려진다).
6. **조사**: `'$name${name.objectParticle} …'` → ARB `"{name}{batchim, select, yes{을} other{를}} …"`(`batchim` 도 `String` 자리표시자) → `context.l10n.키(name, batchimOf(name))`. 코드가 조사 글자를 붙이지 않는다. `import 'package:elum/core/l10n/batchim.dart';` (프로젝트 내부는 상대 경로).
7. **단위·복수**: `'$n개'` → `"{count, plural, other{{count}개}}"`(ko 는 `other` 하나. 영어 등은 번역 단계에서 `one` 을 더한다).
8. **날짜**: `core/l10n/date_labels.dart` 의 `yearMonthDay`·`monthDaySince`·`resetAt` 을 쓴다.
9. `\n`·`*강조*` 같은 표식은 문구 그대로 ARB 에 옮긴다(JSON 에서는 `\n`). 작은따옴표는 ICU 에서 `''` 로 쓴다.

위 표의 줄을 위에서 아래로 처리한다. 이 폴더의 키 접두어는 ``role` `login` `consent`` 이다.

- [ ] **Step 5: 생성·분석·감사**

```bash
cd client && flutter gen-l10n && flutter analyze && dart run tool/l10n_ko_audit.dart --base 99b65ac0
```
Expected: `No issues found!`, `--- 조각 N개 중 기준 커밋에 없는 것 0개`.

- [ ] **Step 6: 검사기와 테스트**

```bash
cd client && dart run tool/check_hangul_literals.dart lib/features/auth
cd client && flutter test test/l10n/ $(grep -rlE "package:elum/features/auth/" test | sort)
git status --short client/test | grep -c png
```
Expected: 검사기 `0줄`(종료 0). 테스트 **PASS**. PNG 변경 `0`(골든·시안 PNG 는 `--update-goldens` 없이 그대로 통과해야 한다).

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add client/lib/features/auth/domain/app_role.dart client/lib/features/auth/presentation/consent_screen.dart client/lib/features/auth/presentation/login_screen.dart client/lib/features/auth/presentation/role_select_screen.dart client/lib/features/auth/presentation/consent_document_screen.dart client/lib/features/auth/presentation/widgets/consent_all_agree_button.dart client/lib/features/auth/presentation/widgets/consent_chip.dart client/lib/features/auth/presentation/widgets/consent_row.dart client/lib/features/auth/presentation/consent_document_list_screen.dart client/tool/l10n_ko_audit_accepted.txt client/lib/l10n client/test/l10n/auth_messages_ko_test.dart
```

## Task 15: onboarding — 온보딩 화면·캐릭터·그림 방식·도움 목표

**Files:**
- Modify: 아래 표의 11개 파일, `client/lib/l10n/app_ko.arb`(+ 생성물)
- Test: `client/test/l10n/onboarding_messages_ko_test.dart`

**Interfaces:**
- Consumes: `appL10n`·`context.l10n` (Task 3)
- Produces: ARB 키 `commonElumiName`(`이룸이`) `characterCatLabel` `characterCatName` `characterFoxLabel` `characterFoxName` `agentChickLabel` `imageStyleCartoonLabel` `imageStyleCartoonDescription` `imageStyleRealisticLabel` `imageStyleRealisticDescription` `imageStylePhotoOnlyLabel` `imageStylePhotoOnlyDescription` `goalStepByStep` `goalPrepareItems` `goalPrepareNew` `goalIndependent` `onboardingCharacterTitle(name)` `onboardingGoalsTitle(name)` … `CardCharacter.label`·`displayName`, `AgentPersona.label`, `ImageStyle.label`·`description`, `SupportGoal.label` 의 **API 는 그대로**다(생성자 인자만 줄어든다).

대상:

| 파일 | 줄 수 | 줄 |
| --- | ---: | --- |
| `client/lib/features/onboarding/domain/image_style.dart` | 4 | 14-15, 17, 19 |
| `client/lib/features/onboarding/domain/onboarding_profile.dart` | 1 | 40 |
| `client/lib/features/onboarding/domain/character.dart` | 3 | 11-12, 44 |
| `client/lib/features/onboarding/domain/support_goal.dart` | 4 | 12-15 |
| `client/lib/features/onboarding/presentation/image_style_screen.dart` | 4 | 68, 81, 96-97 |
| `client/lib/features/onboarding/presentation/card_completion_screen.dart` | 2 | 63, 71 |
| `client/lib/features/onboarding/presentation/character_screen.dart` | 3 | 62, 77-78 |
| `client/lib/features/onboarding/presentation/name_screen.dart` | 5 | 63, 76, 90, 92, 99 |
| `client/lib/features/onboarding/presentation/pin_screen.dart` | 10 | 129, 152-153, 172-173, 205, 217-219, 228 |
| `client/lib/features/onboarding/presentation/goals_screen.dart` | 3 | 33, 44-45 |
| `client/lib/features/onboarding/presentation/splash_screen.dart` | 1 | 164 |
| **합계 11개 파일** | **40** | |

**캐릭터 이름(`루루`·`포포`·`루미`)과 `이룸이` 를 번역할지는 열린 질문**이다(스펙 8장, 하위 계획 5 가 정한다). 이 Task 는 이름도 ARB 항목(`characterCatName` 등)으로만 만들고 `ko` 값은 지금 그대로다.

- [ ] **Step 1: 기준선을 센다**

Run: `cd client && dart run tool/check_hangul_literals.dart lib/features/onboarding | tail -1`
Expected: `--- 사용자 노출 한글 리터럴 40줄`(종료 코드 1)

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`client/test/l10n/onboarding_messages_ko_test.dart`

```dart
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/features/onboarding/domain/character.dart';
import 'package:elum/features/onboarding/domain/image_style.dart';
import 'package:elum/features/onboarding/domain/onboarding_profile.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// enum 라벨을 ARB 로 옮겨도 API 와 `ko` 문구가 같다. 서버 값(apiValue)은 건드리지 않았다.
void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  test('캐릭터', () {
    expect(CardCharacter.cat.label, '고양이');
    expect(CardCharacter.cat.displayName, '루루');
    expect(CardCharacter.cat.apiValue, 'LULU');
    expect(CardCharacter.fox.label, '여우');
    expect(CardCharacter.fox.displayName, '포포');
    expect(CardCharacter.fox.apiValue, 'POPO');
    expect(AgentPersona.chick.label, '병아리');
  });

  test('카드 그림 방식', () {
    expect(ImageStyle.cartoon.label, '만화');
    expect(ImageStyle.cartoon.description, '캐릭터가 나오는 그림이에요');
    expect(ImageStyle.realistic.label, '실사');
    expect(ImageStyle.realistic.description, '실제 물건 사진처럼 보여요');
    expect(ImageStyle.photoOnly.label, '직접 찍은 사진');
    expect(ImageStyle.photoOnly.description, '그림은 직접 찍은 사진으로 넣어요. 글은 계속 만들어 드려요');
    expect(ImageStyle.cartoon.apiValue, 'CARTOON');
  });

  test('도움 목표', () {
    expect(SupportGoal.stepByStep.label, '해야 할 일을 순서대로 이해해요');
    expect(SupportGoal.prepareItems.label, '필요한 준비물을 스스로 챙겨요');
    expect(SupportGoal.prepareNew.label, '새로운 상황을 미리 준비해요');
    expect(SupportGoal.independent.label, '혼자 끝까지 해내는 경험을 만들어요');
    expect(SupportGoal.stepByStep.apiValue, 'STEP_BY_STEP');
  });

  test('호칭이 비면 이룸이로 대신한다', () {
    expect(const OnboardingProfile().displayName, '이룸이');
    expect(const OnboardingProfile(childNickname: '하늘').displayName, '하늘');
  });

  test('이름이 들어가는 제목', () {
    expect(ko.onboardingCharacterTitle('하늘'), '하늘의 하루를 함께할\n친구를 골라주세요');
    expect(ko.onboardingGoalsTitle('하늘'), '하늘의 어떤 순간을\n도와주고 싶으신가요?');
  });
}
```

Run: `cd client && flutter test test/l10n/onboarding_messages_ko_test.dart`
Expected: **FAIL** — 키가 없다.

- [ ] **Step 3: 특수 문구와 구조를 바꾼다**

`client/lib/l10n/app_ko.arb` 에 더한다.

```json
  "commonElumiName": "이룸이",
  "@commonElumiName": { "description": "이룸을 쓰는 당사자를 부르는 말. 이름을 못 받았을 때의 대체 호칭이기도 하다. 번역 여부는 용어집이 정한다" },

  "onboardingCharacterTitle": "{name}의 하루를 함께할\n친구를 골라주세요",
  "@onboardingCharacterTitle": {
    "description": "캐릭터 고르기 화면 제목. name 은 이룸이 호칭",
    "placeholders": { "name": { "type": "String" } }
  },

  "onboardingGoalsTitle": "{name}의 어떤 순간을\n도와주고 싶으신가요?",
  "@onboardingGoalsTitle": {
    "description": "도움 목표 화면 제목. name 은 이룸이 호칭",
    "placeholders": { "name": { "type": "String" } }
  },
```

`client/lib/features/onboarding/domain/character.dart` — 라벨·이름을 getter 로(서버 값 `apiValue` 만 남긴다). 파일 맨 위에 `import '../../../core/l10n/current_l10n.dart';`

```dart
enum CardCharacter {
  // 순서가 화면 배치다 — 고양이가 왼쪽, 여우가 오른쪽.
  // enum 순서를 바꾸면 화면이 조용히 뒤집히므로 테스트로 고정해 뒀다.
  //
  // apiValue는 서버 CharacterType enum(LULU/POPO)에 맞춘다 (이슈 #89).
  cat('LULU'),
  fox('POPO');

  const CardCharacter(this.apiValue);

  /// 서버 `CharacterType` enum 값 (`LULU` / `POPO`)
  final String apiValue;

  /// 종류 (접근성 안내·개발자용)
  String get label => switch (this) {
    CardCharacter.cat => appL10n.characterCatLabel,
    CardCharacter.fox => appL10n.characterFoxLabel,
  };

  /// 카드 아래에 표시되는 이름 (Figma `732:5320` 루루 / `732:5319` 포포).
  String get displayName => switch (this) {
    CardCharacter.cat => appL10n.characterCatName,
    CardCharacter.fox => appL10n.characterFoxName,
  };
  // …(fromApiValue 는 그대로)…
```

`AgentPersona` 는 통째로 바꾼다.

```dart
enum AgentPersona {
  chick;

  String get label => appL10n.agentChickLabel;
}
```

`client/lib/features/onboarding/domain/image_style.dart`·`support_goal.dart` 도 같은 모양이다 — 생성자에서 한글 인자를 빼고 getter 를 만든다.

```dart
enum ImageStyle {
  cartoon('CARTOON'),
  realistic('REALISTIC'),
  photoOnly('PHOTO_ONLY');

  const ImageStyle(this.apiValue);

  /// 서버 enum 값
  final String apiValue;

  /// 화면 이름 (선택 카드 제목·설정 줄의 값)
  String get label => switch (this) {
    ImageStyle.cartoon => appL10n.imageStyleCartoonLabel,
    ImageStyle.realistic => appL10n.imageStyleRealisticLabel,
    ImageStyle.photoOnly => appL10n.imageStylePhotoOnlyLabel,
  };

  /// 선택 카드의 한 줄 설명
  String get description => switch (this) {
    ImageStyle.cartoon => appL10n.imageStyleCartoonDescription,
    ImageStyle.realistic => appL10n.imageStyleRealisticDescription,
    ImageStyle.photoOnly => appL10n.imageStylePhotoOnlyDescription,
  };
  // …(fromApiValue 는 그대로)…
```

```dart
enum SupportGoal {
  stepByStep('STEP_BY_STEP'),
  prepareItems('PREPARE_ITEMS'),
  prepareNew('PREPARE_NEW'),
  independent('INDEPENDENT');

  const SupportGoal(this.apiValue);

  /// 서버 전송용 값 (서버 enum name과 동일)
  final String apiValue;

  /// 화면에 표시되는 문구 (Figma `온보딩_목표` 프레임 문구)
  String get label => switch (this) {
    SupportGoal.stepByStep => appL10n.goalStepByStep,
    SupportGoal.prepareItems => appL10n.goalPrepareItems,
    SupportGoal.prepareNew => appL10n.goalPrepareNew,
    SupportGoal.independent => appL10n.goalIndependent,
  };
  // …(fromApiValue 는 그대로)…
```

`client/lib/features/onboarding/domain/onboarding_profile.dart:37-44` — 대체 호칭 상수를 없앤다.

```dart
  /// 화면 제목에 넣을 호칭. 비어있으면 자연스러운 대체어를 준다.
  /// 딥링크로 중간 진입하면 호칭이 비어 "의 어떤 순간을..."처럼 조사만 남는다.
  String get displayName =>
      childNickname.trim().isEmpty ? appL10n.commonElumiName : childNickname.trim();
```
(`import '../../../core/l10n/current_l10n.dart';`)


나머지 단순 문구 중 **위 코드·테스트가 이름으로 부르는 것**도 같은 파일에 더한다(이름과 `ko` 값은 아래가 정한다. 이 폴더의 나머지 문구는 Step 4 에서 규칙대로 더한다).

```json
  "characterCatLabel": "고양이",
  "@characterCatLabel": { "description": "캐릭터 종류(접근성 안내)" },

  "characterCatName": "루루",
  "@characterCatName": { "description": "고양이 캐릭터의 카드 아래 이름. 번역 여부는 용어집이 정한다" },

  "characterFoxLabel": "여우",
  "@characterFoxLabel": { "description": "캐릭터 종류(접근성 안내)" },

  "characterFoxName": "포포",
  "@characterFoxName": { "description": "여우 캐릭터의 카드 아래 이름. 번역 여부는 용어집이 정한다" },

  "agentChickLabel": "병아리",
  "@agentChickLabel": { "description": "서비스 에이전트(루미)의 종류 이름" },

  "imageStyleCartoonLabel": "만화",
  "@imageStyleCartoonLabel": { "description": "카드 그림 방식 이름" },

  "imageStyleCartoonDescription": "캐릭터가 나오는 그림이에요",
  "@imageStyleCartoonDescription": { "description": "카드 그림 방식 설명" },

  "imageStyleRealisticLabel": "실사",
  "@imageStyleRealisticLabel": { "description": "카드 그림 방식 이름" },

  "imageStyleRealisticDescription": "실제 물건 사진처럼 보여요",
  "@imageStyleRealisticDescription": { "description": "카드 그림 방식 설명" },

  "imageStylePhotoOnlyLabel": "직접 찍은 사진",
  "@imageStylePhotoOnlyLabel": { "description": "카드 그림 방식 이름" },

  "imageStylePhotoOnlyDescription": "그림은 직접 찍은 사진으로 넣어요. 글은 계속 만들어 드려요",
  "@imageStylePhotoOnlyDescription": { "description": "카드 그림 방식 설명" },

  "goalStepByStep": "해야 할 일을 순서대로 이해해요",
  "@goalStepByStep": { "description": "도움 목표 선택지" },

  "goalPrepareItems": "필요한 준비물을 스스로 챙겨요",
  "@goalPrepareItems": { "description": "도움 목표 선택지" },

  "goalPrepareNew": "새로운 상황을 미리 준비해요",
  "@goalPrepareNew": { "description": "도움 목표 선택지" },

  "goalIndependent": "혼자 끝까지 해내는 경험을 만들어요",
  "@goalIndependent": { "description": "도움 목표 선택지" }
```

- [ ] **Step 4: 나머지 문구를 규칙대로 옮긴다**

**변환 규칙** (아래 대상 파일 전부에 같다. 한국어 문구는 한 글자도 바꾸지 않는다 — 감사기가 잡는다)

1. **위젯 안의 문구**: `Text('확인')` → `Text(context.l10n.commonConfirm)`. 키는 `app_ko.arb` 에 `"키": "확인"` 과 `"@키": { "description": "어디에 쓰이는 문구인지" }` 로 더한다. 같은 문구가 이미 있으면(`commonConfirm`·`commonCancel`·`commonClose`·`commonNext`·`commonRetry` 등) 키를 재사용한다. `const` 에 걸리면 가장 가까운 바깥 `const` 를 뗀다(analyze 가 위치를 알려준다). 파일 맨 위에 `core/l10n/l10n_context.dart`(`context.l10n`)·`core/l10n/current_l10n.dart`(`appL10n`) import 를 더한다.
2. **보간**: `'$name의 하루'` → ARB `"{name}의 하루"` 와 `"@키": { "placeholders": { "name": { "type": "String" } } }` → `context.l10n.키(name)`. 숫자는 `"type": "int"`.
3. **`String` 인자로 넘기는 문구**(`showFailure(title:, fallback:)`·`ElumDialogAction(label:)`): 호출 지점에서 `context.l10n` 으로 넘긴다. `await` 뒤에서 `context` 를 쓰면 `use_build_context_synchronously` 가 걸리므로 함수 맨 앞에서 `final l10n = context.l10n;` 로 잡아 둔다.
4. **상수·기본값**: 생성자 기본값(`this.label = '…'`)은 `String? label` 로 바꾸고 `build` 에서 `label ?? context.l10n.키` 로 푼다. `static const` 문구는, 다른 파일·테스트가 참조하면 `static String get` 으로 바꿔 `appL10n.키` 를 돌려주고(API 이름 유지), 같은 파일 안에서만 쓰면 `build` 에서 푼다. 상수를 `const` 로 참조하던 테스트는 한글 리터럴로 바꾼다.
5. **`context` 가 없는 층**(도메인 getter·enum 라벨·저장소 대체 문구): getter API 를 그대로 두고 값만 `appL10n.키` 로 돌려준다. 이런 getter 는 `context.l10n` 을 읽는 위젯의 `build` 안에서만 부른다(언어가 바뀔 때 같이 다시 그려진다).
6. **조사**: `'$name${name.objectParticle} …'` → ARB `"{name}{batchim, select, yes{을} other{를}} …"`(`batchim` 도 `String` 자리표시자) → `context.l10n.키(name, batchimOf(name))`. 코드가 조사 글자를 붙이지 않는다. `import 'package:elum/core/l10n/batchim.dart';` (프로젝트 내부는 상대 경로).
7. **단위·복수**: `'$n개'` → `"{count, plural, other{{count}개}}"`(ko 는 `other` 하나. 영어 등은 번역 단계에서 `one` 을 더한다).
8. **날짜**: `core/l10n/date_labels.dart` 의 `yearMonthDay`·`monthDaySince`·`resetAt` 을 쓴다.
9. `\n`·`*강조*` 같은 표식은 문구 그대로 ARB 에 옮긴다(JSON 에서는 `\n`). 작은따옴표는 ICU 에서 `''` 로 쓴다.

위 표의 줄을 위에서 아래로 처리한다. 이 폴더의 키 접두어는 ``onboarding` `character` `imageStyle` `goal` `pin`` 이다.

- [ ] **Step 5: 생성·분석·감사**

```bash
cd client && flutter gen-l10n && flutter analyze && dart run tool/l10n_ko_audit.dart --base 99b65ac0
```
Expected: `No issues found!`, `--- 조각 N개 중 기준 커밋에 없는 것 0개`.

- [ ] **Step 6: 검사기와 테스트**

```bash
cd client && dart run tool/check_hangul_literals.dart lib/features/onboarding
cd client && flutter test test/l10n/ $(grep -rlE "package:elum/features/onboarding/" test | sort)
git status --short client/test | grep -c png
```
Expected: 검사기 `0줄`(종료 0). 테스트 **PASS**. PNG 변경 `0`(골든·시안 PNG 는 `--update-goldens` 없이 그대로 통과해야 한다).

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add client/lib/features/onboarding/domain/image_style.dart client/lib/features/onboarding/domain/onboarding_profile.dart client/lib/features/onboarding/domain/character.dart client/lib/features/onboarding/domain/support_goal.dart client/lib/features/onboarding/presentation/image_style_screen.dart client/lib/features/onboarding/presentation/card_completion_screen.dart client/lib/features/onboarding/presentation/character_screen.dart client/lib/features/onboarding/presentation/name_screen.dart client/lib/features/onboarding/presentation/pin_screen.dart client/lib/features/onboarding/presentation/goals_screen.dart client/lib/features/onboarding/presentation/splash_screen.dart  client/lib/l10n client/test/l10n/onboarding_messages_ko_test.dart
```

## Task 16: link — 이룸이 휴대폰 연결 화면

**Files:**
- Modify: 아래 표의 6개 파일, `client/lib/l10n/app_ko.arb`(+ 생성물)
- Test: `client/test/l10n/link_messages_ko_test.dart`

**Interfaces:**
- Consumes: `appL10n`·`context.l10n` (Task 3), `monthDaySince`·`commonElumiName` (Task 11, 15)
- Produces: ARB 키 `linkCodeAskTitle(name)` `linkCodeEnterHint(name)` `linkDeviceNumbered(number)` `linkEnterGuide` `linkEnterGuidePath` … `LinkedDevice.sinceLabel`·`LinkRetryChip.label` 기본값의 **API 는 그대로**다.

대상:

| 파일 | 줄 수 | 줄 |
| --- | ---: | --- |
| `client/lib/features/link/domain/link_status.dart` | 1 | 11 |
| `client/lib/features/link/presentation/elumi_settings_screen.dart` | 14 | 51-53, 56-58, 84, 88, 110, 128, 143, 149, 160, 165 |
| `client/lib/features/link/presentation/link_status_screen.dart` | 15 | 53-54, 57, 62, 82-83, 95, 114, 144, 164, 171, 188, 204, 253, 283 |
| `client/lib/features/link/presentation/link_enter_screen.dart` | 12 | 81, 99, 101, 103, 105, 107, 150-151, 161, 172, 174, 184 |
| `client/lib/features/link/presentation/link_code_screen.dart` | 9 | 128, 180, 190, 204, 212, 235, 257, 259, 298 |
| `client/lib/features/link/presentation/widgets/link_code_text.dart` | 1 | 53 |
| **합계 6개 파일** | **52** | |

- [ ] **Step 1: 기준선을 센다**

Run: `cd client && dart run tool/check_hangul_literals.dart lib/features/link | tail -1`
Expected: `--- 사용자 노출 한글 리터럴 52줄`(종료 코드 1)

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`client/test/l10n/link_messages_ko_test.dart`

```dart
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/features/link/domain/link_status.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  test('이름이 들어가는 문구', () {
    expect(ko.linkCodeAskTitle('하늘이'), '하늘이의 휴대폰을\n연결할까요?');
    expect(ko.linkCodeEnterHint('하늘이'), '하늘이의 휴대폰에서 아래 코드를 입력하세요');
    expect(ko.linkDeviceNumbered(2), '이룸이 휴대폰 2');
  });

  test('코드 안내와 밑줄 친 길 — 밑줄 친 부분은 안내문 안에 있어야 한다', () {
    expect(
      ko.linkEnterGuide,
      '코드는 보호자 휴대폰의\n설정 → 이룸이 휴대폰 연결하기에 있어요',
    );
    expect(ko.linkEnterGuidePath, '설정 → 이룸이 휴대폰 연결하기');
    expect(ko.linkEnterGuide, contains(ko.linkEnterGuidePath));
  });

  test('연결된 날 — LinkedDevice.sinceLabel', () {
    final device = LinkedDevice(linkId: 'l1', linkedAt: DateTime(2026, 9, 18));
    expect(device.sinceLabel, '9월 18일부터');
    expect(const LinkedDevice(linkId: 'l2', linkedAt: null).sinceLabel, isNull);
  });
}
```

Run: `cd client && flutter test test/l10n/link_messages_ko_test.dart`
Expected: **FAIL** — 키가 없다.

- [ ] **Step 3: 특수 문구와 구조를 바꾼다**

`client/lib/l10n/app_ko.arb` 에 더한다.

```json
  "linkCodeAskTitle": "{name}의 휴대폰을\n연결할까요?",
  "@linkCodeAskTitle": {
    "description": "보호자 휴대폰의 연결 암호 화면 제목. name 은 이룸이 호칭",
    "placeholders": { "name": { "type": "String" } }
  },

  "linkCodeEnterHint": "{name}의 휴대폰에서 아래 코드를 입력하세요",
  "@linkCodeEnterHint": {
    "description": "연결 암호 화면의 설명. name 은 이룸이 호칭",
    "placeholders": { "name": { "type": "String" } }
  },

  "linkDeviceNumbered": "이룸이 휴대폰 {number}",
  "@linkDeviceNumbered": {
    "description": "연결된 휴대폰이 여러 대일 때 붙이는 번호 제목",
    "placeholders": { "number": { "type": "int" } }
  },

  "linkEnterGuide": "코드는 보호자 휴대폰의\n설정 → 이룸이 휴대폰 연결하기에 있어요",
  "@linkEnterGuide": { "description": "이룸이 휴대폰의 코드 입력 안내. linkEnterGuidePath 를 문장 안에 그대로 포함해야 밑줄이 그려진다" },

  "linkEnterGuidePath": "설정 → 이룸이 휴대폰 연결하기",
  "@linkEnterGuidePath": { "description": "linkEnterGuide 안에서 밑줄을 그을 부분. 안내문에 똑같이 들어 있어야 한다" },
```

`client/lib/features/link/domain/link_status.dart:9-12`

```dart
  /// 상태 화면의 `9월 18일부터`. 시각을 모르면 null — 줄째 그리지 않는다 (#363).
  String? get sinceLabel {
    final at = linkedAt;
    return at == null ? null : appL10n.monthDaySince(at);
  }
```
(`import '../../../core/l10n/current_l10n.dart';`·`date_labels.dart`)

`client/lib/features/link/presentation/widgets/link_code_text.dart:53` — 생성자 기본값(규칙 4)

```dart
class LinkRetryChip extends StatelessWidget {
  const LinkRetryChip({super.key, required this.onTap, this.label});

  final VoidCallback? onTap;

  /// 칩 글자. 비우면 `코드 다시 만들기`(시안 그대로)다.
  final String? label;
  // …build 에서 `label ?? context.l10n.linkRetryChipLabel` 로 푼다…
```

`client/lib/features/link/presentation/link_enter_screen.dart:150-151`(`_guide`·`_guidePath` 상수) — `build` 에서 푼다. `_submit` 은 `await` 뒤에서 문구를 쓰므로 맨 앞에서 잡는다.

```dart
  Future<void> _submit() async {
    final l10n = context.l10n; // await 뒤에서 context 를 쓰지 않으려고 미리 잡는다
    final code = _typed;
    if (!LinkCode.hasValidShape(code)) {
      _fail(l10n.linkEnterWrongCode);
      return;
    }
    // …(redeem 호출은 그대로)…
    switch (result.outcome) {
      case RedeemOutcome.linked:
        context.go(Routes.child);
      case RedeemOutcome.notFound:
        _fail(l10n.linkEnterWrongCode);
      case RedeemOutcome.expired:
        _fail(l10n.linkEnterExpired);
      case RedeemOutcome.tooManyAttempts:
        _fail(say(l10n.commonRetryLater, 'E-LINK-429'));
      case RedeemOutcome.offline:
        _fail(say(l10n.linkEnterOffline, 'E-NET'));
      case RedeemOutcome.failed:
        _fail(say(l10n.linkEnterFailed, 'E-LINK'));
    }
  }
```
(ko 값: `linkEnterWrongCode`=`암호가 맞지 않아요`, `linkEnterExpired`=`암호가 만료됐어요. 새 암호를 받아주세요`, `linkEnterOffline`=`연결하지 못했어요. 인터넷을 확인해주세요`, `linkEnterFailed`=`연결하지 못했어요. 다시 해주세요`, `commonRetryLater`=`잠시 후 다시 해주세요`(Task 12).)

`link_code_screen.dart:190` 의 이룸이 이름 대체어는 `context` 가 없는 getter 안이므로 `appL10n.commonElumiName`, 제목은 `context.l10n.linkCodeAskTitle(_elumiName)`.


나머지 단순 문구 중 **위 코드·테스트가 이름으로 부르는 것**도 같은 파일에 더한다(이름과 `ko` 값은 아래가 정한다. 이 폴더의 나머지 문구는 Step 4 에서 규칙대로 더한다).

```json
  "linkEnterWrongCode": "암호가 맞지 않아요",
  "@linkEnterWrongCode": { "description": "연결 암호 입력 실패(모양이 틀리거나 없는 암호)" },

  "linkEnterExpired": "암호가 만료됐어요. 새 암호를 받아주세요",
  "@linkEnterExpired": { "description": "연결 암호가 만료됐을 때" },

  "linkEnterOffline": "연결하지 못했어요. 인터넷을 확인해주세요",
  "@linkEnterOffline": { "description": "연결 중 오프라인일 때" },

  "linkEnterFailed": "연결하지 못했어요. 다시 해주세요",
  "@linkEnterFailed": { "description": "연결 중 그 밖의 실패" },

  "linkRetryChipLabel": "코드 다시 만들기",
  "@linkRetryChipLabel": { "description": "연결 암호 화면의 다시 만들기 칩(시안 그대로)" }
```

- [ ] **Step 4: 나머지 문구를 규칙대로 옮긴다**

**변환 규칙** (아래 대상 파일 전부에 같다. 한국어 문구는 한 글자도 바꾸지 않는다 — 감사기가 잡는다)

1. **위젯 안의 문구**: `Text('확인')` → `Text(context.l10n.commonConfirm)`. 키는 `app_ko.arb` 에 `"키": "확인"` 과 `"@키": { "description": "어디에 쓰이는 문구인지" }` 로 더한다. 같은 문구가 이미 있으면(`commonConfirm`·`commonCancel`·`commonClose`·`commonNext`·`commonRetry` 등) 키를 재사용한다. `const` 에 걸리면 가장 가까운 바깥 `const` 를 뗀다(analyze 가 위치를 알려준다). 파일 맨 위에 `core/l10n/l10n_context.dart`(`context.l10n`)·`core/l10n/current_l10n.dart`(`appL10n`) import 를 더한다.
2. **보간**: `'$name의 하루'` → ARB `"{name}의 하루"` 와 `"@키": { "placeholders": { "name": { "type": "String" } } }` → `context.l10n.키(name)`. 숫자는 `"type": "int"`.
3. **`String` 인자로 넘기는 문구**(`showFailure(title:, fallback:)`·`ElumDialogAction(label:)`): 호출 지점에서 `context.l10n` 으로 넘긴다. `await` 뒤에서 `context` 를 쓰면 `use_build_context_synchronously` 가 걸리므로 함수 맨 앞에서 `final l10n = context.l10n;` 로 잡아 둔다.
4. **상수·기본값**: 생성자 기본값(`this.label = '…'`)은 `String? label` 로 바꾸고 `build` 에서 `label ?? context.l10n.키` 로 푼다. `static const` 문구는, 다른 파일·테스트가 참조하면 `static String get` 으로 바꿔 `appL10n.키` 를 돌려주고(API 이름 유지), 같은 파일 안에서만 쓰면 `build` 에서 푼다. 상수를 `const` 로 참조하던 테스트는 한글 리터럴로 바꾼다.
5. **`context` 가 없는 층**(도메인 getter·enum 라벨·저장소 대체 문구): getter API 를 그대로 두고 값만 `appL10n.키` 로 돌려준다. 이런 getter 는 `context.l10n` 을 읽는 위젯의 `build` 안에서만 부른다(언어가 바뀔 때 같이 다시 그려진다).
6. **조사**: `'$name${name.objectParticle} …'` → ARB `"{name}{batchim, select, yes{을} other{를}} …"`(`batchim` 도 `String` 자리표시자) → `context.l10n.키(name, batchimOf(name))`. 코드가 조사 글자를 붙이지 않는다. `import 'package:elum/core/l10n/batchim.dart';` (프로젝트 내부는 상대 경로).
7. **단위·복수**: `'$n개'` → `"{count, plural, other{{count}개}}"`(ko 는 `other` 하나. 영어 등은 번역 단계에서 `one` 을 더한다).
8. **날짜**: `core/l10n/date_labels.dart` 의 `yearMonthDay`·`monthDaySince`·`resetAt` 을 쓴다.
9. `\n`·`*강조*` 같은 표식은 문구 그대로 ARB 에 옮긴다(JSON 에서는 `\n`). 작은따옴표는 ICU 에서 `''` 로 쓴다.

위 표의 줄을 위에서 아래로 처리한다. 이 폴더의 키 접두어는 ``link`` 이다.

- [ ] **Step 5: 생성·분석·감사**

```bash
cd client && flutter gen-l10n && flutter analyze && dart run tool/l10n_ko_audit.dart --base 99b65ac0
```
Expected: `No issues found!`, `--- 조각 N개 중 기준 커밋에 없는 것 0개`.

- [ ] **Step 6: 검사기와 테스트**

```bash
cd client && dart run tool/check_hangul_literals.dart lib/features/link
cd client && flutter test test/l10n/ $(grep -rlE "package:elum/features/link/" test | sort)
git status --short client/test | grep -c png
```
Expected: 검사기 `0줄`(종료 0). 테스트 **PASS**. PNG 변경 `0`(골든·시안 PNG 는 `--update-goldens` 없이 그대로 통과해야 한다).

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add client/lib/features/link/domain/link_status.dart client/lib/features/link/presentation/elumi_settings_screen.dart client/lib/features/link/presentation/link_status_screen.dart client/lib/features/link/presentation/link_enter_screen.dart client/lib/features/link/presentation/link_code_screen.dart client/lib/features/link/presentation/widgets/link_code_text.dart  client/lib/l10n client/test/l10n/link_messages_ko_test.dart
```

## Task 17: profile — 함께하는 보호자·초대 코드·이룸이 바꾸기

**Files:**
- Modify: 아래 표의 8개 파일, `client/lib/l10n/app_ko.arb`(+ 생성물)
- Test: `client/test/l10n/profile_messages_ko_test.dart`

**Interfaces:**
- Consumes: `appL10n`·`context.l10n` (Task 3), `batchimOf` (Task 11), `commonElumiName` (Task 15)
- Produces: ARB 키 `commonGuardianName`(`보호자`) `guardianKindGuardian` `guardianKindCaregiver` `inviteCodeAsk(name, batchim)` `inviteJoined(name, batchim)` `guardiansCaption(name)` `guardiansLeft(name)` `profileSwitchSelected(name)` `inviteShareMessage(minutes, url, code)` … `GuardianKind.label`·`Guardian.label`·`ProfileSummary.displayName`·`InviteLink.shareMessage` 의 **API 는 그대로**다.

대상:

| 파일 | 줄 수 | 줄 |
| --- | ---: | --- |
| `client/lib/features/profile/domain/invite_link.dart` | 4 | 178-179, 183-184 |
| `client/lib/features/profile/domain/guardian_member.dart` | 3 | 5-6, 53 |
| `client/lib/features/profile/domain/profile_summary.dart` | 1 | 33 |
| `client/lib/features/profile/presentation/invite_code_screen.dart` | 15 | 73, 123, 167-168, 176, 201, 206, 216-217, 225-226, 232, 252, 259, 266 |
| `client/lib/features/profile/presentation/profile_switch_screen.dart` | 5 | 46, 56, 72, 88, 127 |
| `client/lib/features/profile/presentation/invite_enter_screen.dart` | 23 | 147, 166, 214, 224, 226, 229, 231, 233, 235, 240, 247-248, 260, 304, 313, 328, 332-333, 349, 356, 363, 377, 416 |
| `client/lib/features/profile/presentation/guardian_edit_sheet.dart` | 4 | 92, 97, 103, 122 |
| `client/lib/features/profile/presentation/guardians_screen.dart` | 24 | 66, 69-70, 72-73, 89-90, 109, 130-131, 147, 160-161, 185, 192, 197, 207, 218, 221, 225, 231, 242-243, 309 |
| **합계 8개 파일** | **79** | |

**초대 공유 메시지(`InviteLink.shareMessage`)** 는 보호자가 다른 보호자에게 메신저로 보내는 글이라 **보내는 사람의 앱 언어**로 만들어진다. 받는 사람의 언어는 알 수 없다.

**기존 동작 그대로 두는 것**: `guardians_screen.dart:185` 의 `'$profileName를 함께 돌보는 사람이에요'` 는 조사를 `를` 로 **고정**해 받침 있는 이름에서 어색하다. `ko` 불변이 이 계획의 통과 조건이라 ARB 문구도 `를` 고정으로 옮긴다. 고치려면 시안·사용자 결정이 필요하다.

- [ ] **Step 1: 기준선을 센다**

Run: `cd client && dart run tool/check_hangul_literals.dart lib/features/profile | tail -1`
Expected: `--- 사용자 노출 한글 리터럴 79줄`(종료 코드 1)

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`client/test/l10n/profile_messages_ko_test.dart`

```dart
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/features/profile/domain/guardian_member.dart';
import 'package:elum/features/profile/domain/profile_summary.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  test('초대 문구의 조사 — 받침이 있으면 을, 없으면 를', () {
    expect(ko.inviteCodeAsk('민준', 'yes'), '받은 분이 민준을 함께 돌봐요');
    expect(ko.inviteCodeAsk('루미', 'no'), '받은 분이 루미를 함께 돌봐요');
    expect(ko.inviteJoined('민준', 'yes'), '민준을 함께 돌보게 됐어요');
    expect(ko.inviteJoined('루미', 'no'), '루미를 함께 돌보게 됐어요');
  });

  test('이름이 들어가는 문구', () {
    // 조사는 현재 동작 그대로 `를` 고정이다 — 받침 있는 이름도 같다
    expect(ko.guardiansCaption('하늘'), '하늘를 함께 돌보는 사람이에요');
    expect(ko.guardiansLeft('하늘'), '하늘에서 나왔어요');
    expect(ko.profileSwitchSelected('하늘'), '하늘, 지금 보는 이룸이');
  });

  test('초대 공유 메시지는 옛 문구와 줄바꿈까지 같다', () {
    expect(
      ko.inviteShareMessage(10, 'https://example.test/i/ABC', 'ABC DEF'),
      '이룸이를 함께 돌봐요. 아래 링크를 누르면 이룸 앱에 초대 코드가 채워져요.\n'
      '초대 코드는 10분 동안만 쓸 수 있어요.\n'
      '\n'
      'https://example.test/i/ABC\n'
      '\n'
      '링크가 열리지 않으면 앱에서 직접 넣어주세요.\n'
      '초대 코드 ABC DEF',
    );
  });

  test('이름이 비었을 때의 대체 호칭', () {
    expect(const ProfileSummary(id: 'p').displayName, '이룸이');
    expect(const ProfileSummary(id: 'p', nickname: '하늘').displayName, '하늘');
    expect(GuardianKind.guardian.label, '보호자');
    expect(GuardianKind.caregiver.label, '센터 선생님');
    expect(const Guardian(id: 'g', me: false).label, '보호자');
    expect(const Guardian(id: 'g', me: false, displayName: '엄마').label, '엄마');
  });
}
```

Run: `cd client && flutter test test/l10n/profile_messages_ko_test.dart`
Expected: **FAIL** — 키가 없다.

- [ ] **Step 3: 특수 문구와 구조를 바꾼다**

`client/lib/l10n/app_ko.arb` 에 더한다.

```json
  "commonGuardianName": "보호자",
  "@commonGuardianName": { "description": "이름이 없는 보호자를 부르는 대체 호칭" },

  "guardianKindGuardian": "보호자",
  "@guardianKindGuardian": { "description": "함께하는 사람의 구분 이름(가족·보호자)" },
  "guardianKindCaregiver": "센터 선생님",
  "@guardianKindCaregiver": { "description": "함께하는 사람의 구분 이름(센터·기관 선생님)" },

  "inviteCodeAsk": "받은 분이 {name}{batchim, select, yes{을} other{를}} 함께 돌봐요",
  "@inviteCodeAsk": {
    "description": "초대 코드 화면 설명. name 은 이룸이 호칭. batchim 은 한국어 조사 선택용(yes/no)이라 다른 언어는 쓰지 않는다",
    "placeholders": { "name": { "type": "String" }, "batchim": { "type": "String" } }
  },

  "inviteJoined": "{name}{batchim, select, yes{을} other{를}} 함께 돌보게 됐어요",
  "@inviteJoined": {
    "description": "초대 코드를 넣고 합류했을 때의 알림. name 은 이룸이 호칭",
    "placeholders": { "name": { "type": "String" }, "batchim": { "type": "String" } }
  },

  "guardiansCaption": "{name}를 함께 돌보는 사람이에요",
  "@guardiansCaption": {
    "description": "함께하는 사람 목록의 머리 설명. name 은 이룸이 호칭(한국어는 조사를 `를` 로 고정해 둔 현행 문구)",
    "placeholders": { "name": { "type": "String" } }
  },

  "guardiansLeft": "{name}에서 나왔어요",
  "@guardiansLeft": {
    "description": "함께 돌보기를 그만둔 뒤의 알림. name 은 이룸이 호칭",
    "placeholders": { "name": { "type": "String" } }
  },

  "profileSwitchSelected": "{name}, 지금 보는 이룸이",
  "@profileSwitchSelected": {
    "description": "이룸이 바꾸기 목록에서 지금 고른 줄을 낭독기가 읽는 문장",
    "placeholders": { "name": { "type": "String" } }
  },

  "inviteShareMessage": "이룸이를 함께 돌봐요. 아래 링크를 누르면 이룸 앱에 초대 코드가 채워져요.\n초대 코드는 {minutes, plural, other{{minutes}분}} 동안만 쓸 수 있어요.\n\n{url}\n\n링크가 열리지 않으면 앱에서 직접 넣어주세요.\n초대 코드 {code}",
  "@inviteShareMessage": {
    "description": "초대 링크를 메신저로 보낼 때의 글. 보내는 사람의 앱 언어로 만들어진다. url 은 링크, code 는 3-3 으로 끊은 초대 코드",
    "placeholders": {
      "minutes": { "type": "int" },
      "url": { "type": "String" },
      "code": { "type": "String" }
    }
  },
```

`client/lib/features/profile/domain/invite_link.dart:174-185`

```dart
  static String shareMessage(String code, {required Duration validFor}) {
    final normalized = _checked(code);
    // 올림에 가깝게: 발급 직후 599초를 `9분` 이라 하면 어색하다. 5초까지 봐준다 (실제보다 길게 말하지는 않는다).
    final minutes = math.max(1, (validFor.inSeconds + 5) ~/ 60);
    return appL10n.inviteShareMessage(
      minutes,
      shareUrl(normalized),
      LinkCode.grouped(normalized),
    );
  }
```
(`import '../../../core/l10n/current_l10n.dart';`)

`client/lib/features/profile/presentation/invite_code_screen.dart:217`, `invite_enter_screen.dart:214`

```dart
              description: context.l10n.inviteCodeAsk(_name, batchimOf(_name)),
```
```dart
      SnackBar(content: Text(l10n.inviteJoined(name, batchimOf(name)))),
```
(`invite_enter_screen` 의 알림은 `await` 뒤라 함수 맨 앞의 `final l10n = context.l10n;` 를 쓴다. 두 파일 모두 `import '../../../core/l10n/batchim.dart';`.) 이로써 lib 에서 `objectParticle` 호출은 `reward_character.dart`·`child_home_screen.dart`(Task 23)만 남는다.

`client/lib/features/profile/domain/guardian_member.dart`·`profile_summary.dart` — 구분 라벨과 대체 호칭은 `appL10n`(파일 맨 위에 `import '../../../core/l10n/current_l10n.dart';`).

```dart
// guardian_member.dart
enum GuardianKind {
  guardian('GUARDIAN'),
  caregiver('CAREGIVER');

  const GuardianKind(this.apiValue);

  final String apiValue;

  /// 표시용 구분 이름 — 앱 언어의 문구다.
  String get label => switch (this) {
    GuardianKind.guardian => appL10n.guardianKindGuardian,
    GuardianKind.caregiver => appL10n.guardianKindCaregiver,
  };
  // …(fromApiValue 는 그대로)…
```

`Guardian.label`(53행)은 한 줄만 바꾼다.

```dart
    return (name == null || name.isEmpty) ? appL10n.commonGuardianName : name;
```

```dart
// profile_summary.dart:33
    return (name == null || name.isEmpty) ? appL10n.commonElumiName : name;
```

- [ ] **Step 4: 나머지 문구를 규칙대로 옮긴다**

**변환 규칙** (아래 대상 파일 전부에 같다. 한국어 문구는 한 글자도 바꾸지 않는다 — 감사기가 잡는다)

1. **위젯 안의 문구**: `Text('확인')` → `Text(context.l10n.commonConfirm)`. 키는 `app_ko.arb` 에 `"키": "확인"` 과 `"@키": { "description": "어디에 쓰이는 문구인지" }` 로 더한다. 같은 문구가 이미 있으면(`commonConfirm`·`commonCancel`·`commonClose`·`commonNext`·`commonRetry` 등) 키를 재사용한다. `const` 에 걸리면 가장 가까운 바깥 `const` 를 뗀다(analyze 가 위치를 알려준다). 파일 맨 위에 `core/l10n/l10n_context.dart`(`context.l10n`)·`core/l10n/current_l10n.dart`(`appL10n`) import 를 더한다.
2. **보간**: `'$name의 하루'` → ARB `"{name}의 하루"` 와 `"@키": { "placeholders": { "name": { "type": "String" } } }` → `context.l10n.키(name)`. 숫자는 `"type": "int"`.
3. **`String` 인자로 넘기는 문구**(`showFailure(title:, fallback:)`·`ElumDialogAction(label:)`): 호출 지점에서 `context.l10n` 으로 넘긴다. `await` 뒤에서 `context` 를 쓰면 `use_build_context_synchronously` 가 걸리므로 함수 맨 앞에서 `final l10n = context.l10n;` 로 잡아 둔다.
4. **상수·기본값**: 생성자 기본값(`this.label = '…'`)은 `String? label` 로 바꾸고 `build` 에서 `label ?? context.l10n.키` 로 푼다. `static const` 문구는, 다른 파일·테스트가 참조하면 `static String get` 으로 바꿔 `appL10n.키` 를 돌려주고(API 이름 유지), 같은 파일 안에서만 쓰면 `build` 에서 푼다. 상수를 `const` 로 참조하던 테스트는 한글 리터럴로 바꾼다.
5. **`context` 가 없는 층**(도메인 getter·enum 라벨·저장소 대체 문구): getter API 를 그대로 두고 값만 `appL10n.키` 로 돌려준다. 이런 getter 는 `context.l10n` 을 읽는 위젯의 `build` 안에서만 부른다(언어가 바뀔 때 같이 다시 그려진다).
6. **조사**: `'$name${name.objectParticle} …'` → ARB `"{name}{batchim, select, yes{을} other{를}} …"`(`batchim` 도 `String` 자리표시자) → `context.l10n.키(name, batchimOf(name))`. 코드가 조사 글자를 붙이지 않는다. `import 'package:elum/core/l10n/batchim.dart';` (프로젝트 내부는 상대 경로).
7. **단위·복수**: `'$n개'` → `"{count, plural, other{{count}개}}"`(ko 는 `other` 하나. 영어 등은 번역 단계에서 `one` 을 더한다).
8. **날짜**: `core/l10n/date_labels.dart` 의 `yearMonthDay`·`monthDaySince`·`resetAt` 을 쓴다.
9. `\n`·`*강조*` 같은 표식은 문구 그대로 ARB 에 옮긴다(JSON 에서는 `\n`). 작은따옴표는 ICU 에서 `''` 로 쓴다.

위 표의 줄을 위에서 아래로 처리한다. 이 폴더의 키 접두어는 ``guardians` `invite` `profile`` 이다.

- [ ] **Step 5: 생성·분석·감사**

```bash
cd client && flutter gen-l10n && flutter analyze && dart run tool/l10n_ko_audit.dart --base 99b65ac0
```
Expected: `No issues found!`, `--- 조각 N개 중 기준 커밋에 없는 것 0개`.

- [ ] **Step 6: 검사기와 테스트**

```bash
cd client && dart run tool/check_hangul_literals.dart lib/features/profile
cd client && flutter test test/l10n/ $(grep -rlE "package:elum/features/profile/" test | sort)
git status --short client/test | grep -c png
```
Expected: 검사기 `0줄`(종료 0). 테스트 **PASS**. PNG 변경 `0`(골든·시안 PNG 는 `--update-goldens` 없이 그대로 통과해야 한다).

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add client/lib/features/profile/domain/invite_link.dart client/lib/features/profile/domain/guardian_member.dart client/lib/features/profile/domain/profile_summary.dart client/lib/features/profile/presentation/invite_code_screen.dart client/lib/features/profile/presentation/profile_switch_screen.dart client/lib/features/profile/presentation/invite_enter_screen.dart client/lib/features/profile/presentation/guardian_edit_sheet.dart client/lib/features/profile/presentation/guardians_screen.dart  client/lib/l10n client/test/l10n/profile_messages_ko_test.dart
```

## Task 18: credit — AI 크레딧·광고 보상 안내

**Files:**
- Modify: 아래 표의 3개 파일, `client/lib/l10n/app_ko.arb`(+ 생성물). (`ad_reward.dart`·`credit_repository.dart` 등의 `FormatException` 메시지는 개발자용이라 건너뛴다.)
- Test: `client/test/l10n/credit_messages_ko_test.dart`

**Interfaces:**
- Consumes: `appL10n`·`context.l10n` (Task 3), `resetAt`·`creditResetFallback` (Task 11)
- Produces: ARB 키 `creditBlockedBusy` `creditBlockedExhausted(reset)` `creditAdOffer(count)` `creditReceivedTitle(count)` `creditReceivedTitleNoCount` `creditAdWatchMore` `adRewardPreparing` `adRewardConfirming` `adRewardLoadFailed` `adRewardNotWatched` `adRewardSlow` `adRewardDailyLimit` `adRewardCheckAccount` `adRewardUnavailable` `adRewardUnavailableRetry` `adRewardFailed` … `CreditSummary.resetLabel` 의 **API 는 그대로**다.

대상:

| 파일 | 줄 수 | 줄 |
| --- | ---: | --- |
| `client/lib/features/credit/application/ad_reward_flow.dart` | 11 | 114, 121, 160, 170, 172-174, 186, 190, 194, 198 |
| `client/lib/features/credit/domain/credit_summary.dart` | 4 | 123-126 |
| `client/lib/features/credit/presentation/credit_blocked_dialog.dart` | 10 | 41-42, 45, 48, 52, 57, 99, 110, 144-145 |
| **합계 3개 파일** | **25** | |

**서버가 준 문구가 이기는 규칙은 그대로다.** `ad_reward_flow.dart` 의 `failure.serverMessage ?? failure.hint ?? fallback` 에서 `fallback` 만 번역 문구가 된다.

- [ ] **Step 1: 기준선을 센다**

Run: `cd client && dart run tool/check_hangul_literals.dart lib/features/credit | tail -1`
Expected: `--- 사용자 노출 한글 리터럴 25줄`(종료 코드 1)

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`client/test/l10n/credit_messages_ko_test.dart`

```dart
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/features/credit/domain/credit_summary.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/credit_fixtures.dart';

void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  test('홈 막기 팝업', () {
    expect(ko.creditBlockedBusy, '이미 일과를 만들고 있어요.\n다 만든 뒤에 새 일과를 만들 수 있어요');
    expect(
      ko.creditBlockedExhausted('9월 28일(월) 0시'),
      '이번 주 크레딧을 모두 사용했어요.\n9월 28일(월) 0시부터 다시 만들 수 있어요',
    );
    expect(ko.creditAdOffer(1), '광고를 끝까지 보면 크레딧 1개를 받아요');
    expect(ko.creditAdWatchMore, '광고 보고 더 만들기');
  });

  test('지급 알림', () {
    expect(ko.creditReceivedTitle(5), '크레딧 5개를 받았어요');
    expect(ko.creditReceivedTitleNoCount, '크레딧을 받았어요');
  });

  test('광고 보상 실패 안내 여덟 가지', () {
    expect(ko.adRewardLoadFailed, '지금은 광고를 불러올 수 없어요.\n잠시 후 다시 해주세요');
    expect(ko.adRewardNotWatched, '광고를 끝까지 봐야 크레딧을 받을 수 있어요.\n처음부터 다시 해주세요');
    expect(ko.adRewardSlow, '크레딧 확인이 늦어지고 있어요.\n잠시 후 설정에서 확인해주세요');
    expect(ko.adRewardDailyLimit, '오늘은 광고로 받을 수 있는 크레딧을 모두 받았어요.\n내일 다시 해주세요');
    expect(ko.adRewardCheckAccount, '지금은 광고로 크레딧을 받을 수 없어요.\n계정 상태를 확인해주세요');
    expect(ko.adRewardUnavailable, '지금은 광고로 크레딧을 받을 수 없어요.');
    expect(ko.adRewardUnavailableRetry, '지금은 광고로 크레딧을 받을 수 없어요.\n잠시 후 다시 해주세요');
    expect(ko.adRewardFailed, '크레딧을 받지 못했어요.\n잠시 후 다시 해주세요');
    expect(ko.adRewardPreparing, '광고를 준비하고 있어요');
    expect(ko.adRewardConfirming, '크레딧을 확인하고 있어요');
  });

  test('초기화 시각은 날짜 라벨 헬퍼를 거쳐도 옛 문구와 같다', () {
    expect(CreditSummary.fromJson(creditJson()).resetLabel, '9월 28일(월) 0시');
  });
}
```

Run: `cd client && flutter test test/l10n/credit_messages_ko_test.dart`
Expected: **FAIL** — 키가 없다.

- [ ] **Step 3: 특수 문구와 구조를 바꾼다**

`client/lib/l10n/app_ko.arb` 에 더한다.

```json
  "creditBlockedBusy": "이미 일과를 만들고 있어요.\n다 만든 뒤에 새 일과를 만들 수 있어요",
  "@creditBlockedBusy": { "description": "AI 일과를 만드는 중에 새로 만들려 할 때의 팝업 문장" },

  "creditBlockedExhausted": "이번 주 크레딧을 모두 사용했어요.\n{reset}부터 다시 만들 수 있어요",
  "@creditBlockedExhausted": {
    "description": "이번 주 크레딧을 다 써서 막힌 팝업 문장. reset 은 다시 채워지는 시각(예: 9월 28일(월) 0시)",
    "placeholders": { "reset": { "type": "String" } }
  },

  "creditAdOffer": "{count, plural, other{광고를 끝까지 보면 크레딧 {count}개를 받아요}}",
  "@creditAdOffer": {
    "description": "광고 보고 크레딧을 받는 제안 문장. count 는 광고 한 번에 받는 크레딧 수",
    "placeholders": { "count": { "type": "int" } }
  },

  "creditReceivedTitle": "{count, plural, other{크레딧 {count}개를 받았어요}}",
  "@creditReceivedTitle": {
    "description": "광고 시청 뒤 크레딧을 받았다는 팝업 제목. count 는 받은 수",
    "placeholders": { "count": { "type": "int" } }
  },

  "creditReceivedTitleNoCount": "크레딧을 받았어요",
  "@creditReceivedTitleNoCount": { "description": "받은 수를 모를 때의 팝업 제목" },

  "creditAdWatchMore": "광고 보고 더 만들기",
  "@creditAdWatchMore": { "description": "크레딧이 없을 때 광고를 보러 가는 버튼" },

  "adRewardPreparing": "광고를 준비하고 있어요",
  "@adRewardPreparing": { "description": "광고를 불러오는 동안의 대기 팝업" },
  "adRewardConfirming": "크레딧을 확인하고 있어요",
  "@adRewardConfirming": { "description": "광고를 본 뒤 서버 지급을 기다리는 동안의 대기 팝업" },

  "adRewardLoadFailed": "지금은 광고를 불러올 수 없어요.\n잠시 후 다시 해주세요",
  "@adRewardLoadFailed": { "description": "광고 로드 실패 안내" },
  "adRewardNotWatched": "광고를 끝까지 봐야 크레딧을 받을 수 있어요.\n처음부터 다시 해주세요",
  "@adRewardNotWatched": { "description": "광고를 중간에 닫았을 때의 안내" },
  "adRewardSlow": "크레딧 확인이 늦어지고 있어요.\n잠시 후 설정에서 확인해주세요",
  "@adRewardSlow": { "description": "시청은 끝났는데 지급 확인이 오지 않을 때의 안내" },
  "adRewardDailyLimit": "오늘은 광고로 받을 수 있는 크레딧을 모두 받았어요.\n내일 다시 해주세요",
  "@adRewardDailyLimit": { "description": "하루 한도를 다 받았을 때의 안내" },
  "adRewardCheckAccount": "지금은 광고로 크레딧을 받을 수 없어요.\n계정 상태를 확인해주세요",
  "@adRewardCheckAccount": { "description": "계정이 동결돼 받을 수 없을 때의 안내" },
  "adRewardUnavailable": "지금은 광고로 크레딧을 받을 수 없어요.",
  "@adRewardUnavailable": { "description": "광고 보상 기능이 꺼져 있을 때의 안내" },
  "adRewardUnavailableRetry": "지금은 광고로 크레딧을 받을 수 없어요.\n잠시 후 다시 해주세요",
  "@adRewardUnavailableRetry": { "description": "세션을 못 만든 알 수 없는 이유의 안내" },
  "adRewardFailed": "크레딧을 받지 못했어요.\n잠시 후 다시 해주세요",
  "@adRewardFailed": { "description": "서버가 지급하지 않은 그 밖의 이유의 안내" },
```

`client/lib/features/credit/domain/credit_summary.dart:121-127`

```dart
  /// `9월 28일(월) 0시` — 초기화 줄과 홈 막기 팝업이 함께 쓴다.
  String get resetLabel {
    final at = nextResetAt;
    if (at == null) return appL10n.creditResetFallback;
    return appL10n.resetAt(at);
  }
```
(`import '../../../core/l10n/current_l10n.dart';`·`date_labels.dart`)

`client/lib/features/credit/application/ad_reward_flow.dart` — `context` 가 없는 층이라 `appL10n`(규칙 5). `const AdRewardResult.failed(AdRewardFailure(...))` 의 `const` 를 뗀다.

```dart
      case RewardedAdEnd.loadFailed:
        return AdRewardResult.failed(
          AdRewardFailure(sentence: appL10n.adRewardLoadFailed, code: 'E-AD-LOAD'),
        );
      case RewardedAdEnd.dismissed:
        return AdRewardResult.failed(
          AdRewardFailure(sentence: appL10n.adRewardNotWatched, code: 'E-AD-SKIP'),
        );
```
```dart
  AdRewardFailure _sessionFailure(AppFailure failure) {
    final fallback = switch (failure.server?.code) {
      ServerErrorCode.adRewardDailyLimit => appL10n.adRewardDailyLimit,
      ServerErrorCode.adRewardAccountFrozen => appL10n.adRewardCheckAccount,
      ServerErrorCode.adRewardDisabled => appL10n.adRewardUnavailable,
      _ => appL10n.adRewardUnavailableRetry,
    };
    return AdRewardFailure(
      // 서버 문구가 이기는 규칙(#347)은 그대로다
      sentence: failure.serverMessage ?? failure.hint ?? fallback,
      code: failure.badgeOr('E-AD-SESSION'),
    );
  }
```
`_rejectedFailure` 의 다섯 문구(`DAILY_LIMIT`→`adRewardDailyLimit`, `FROZEN`→`adRewardCheckAccount`, `DISABLED`→`adRewardUnavailable`, 그 밖→`adRewardFailed`)와 `E-AD-WAIT`(`adRewardSlow`)도 같은 모양이다.

`client/lib/features/credit/presentation/credit_blocked_dialog.dart` — `await` 가 여러 번이라 함수 맨 앞에서 문구를 잡는다.

```dart
  final l10n = context.l10n; // await 뒤에서 context 를 읽지 않으려고 미리 잡는다
  // …(flow.offer() await)…
  final wantsAd = await showElumDialog<bool>(
    context: context,
    icon: ElumDialogIcon.alert,
    title: generating
        ? l10n.creditBlockedBusy
        : l10n.creditBlockedExhausted(blocked.resetLabel),
    message: offer == null ? null : l10n.creditAdOffer(offer.creditsPerView),
    actions: offer == null
        ? [ElumDialogAction<bool>(label: l10n.commonConfirm, tone: ElumDialogTone.danger)]
        : [
            ElumDialogAction<bool>(
              label: l10n.commonClose,
              value: false,
              tone: ElumDialogTone.neutral,
            ),
            ElumDialogAction<bool>(
              label: l10n.creditAdWatchMore,
              value: true,
              centerLines: true,
            ),
          ],
  );
```
지급 알림 제목은 `n > 0 ? l10n.creditReceivedTitle(n) : l10n.creditReceivedTitleNoCount`, 실패 팝업 버튼은 `l10n.commonConfirm`, 대기 팝업은 `AdRewardStage.preparing => context.l10n.adRewardPreparing`·`confirming => context.l10n.adRewardConfirming`.

- [ ] **Step 4: 나머지 문구를 규칙대로 옮긴다**

**변환 규칙** (아래 대상 파일 전부에 같다. 한국어 문구는 한 글자도 바꾸지 않는다 — 감사기가 잡는다)

1. **위젯 안의 문구**: `Text('확인')` → `Text(context.l10n.commonConfirm)`. 키는 `app_ko.arb` 에 `"키": "확인"` 과 `"@키": { "description": "어디에 쓰이는 문구인지" }` 로 더한다. 같은 문구가 이미 있으면(`commonConfirm`·`commonCancel`·`commonClose`·`commonNext`·`commonRetry` 등) 키를 재사용한다. `const` 에 걸리면 가장 가까운 바깥 `const` 를 뗀다(analyze 가 위치를 알려준다). 파일 맨 위에 `core/l10n/l10n_context.dart`(`context.l10n`)·`core/l10n/current_l10n.dart`(`appL10n`) import 를 더한다.
2. **보간**: `'$name의 하루'` → ARB `"{name}의 하루"` 와 `"@키": { "placeholders": { "name": { "type": "String" } } }` → `context.l10n.키(name)`. 숫자는 `"type": "int"`.
3. **`String` 인자로 넘기는 문구**(`showFailure(title:, fallback:)`·`ElumDialogAction(label:)`): 호출 지점에서 `context.l10n` 으로 넘긴다. `await` 뒤에서 `context` 를 쓰면 `use_build_context_synchronously` 가 걸리므로 함수 맨 앞에서 `final l10n = context.l10n;` 로 잡아 둔다.
4. **상수·기본값**: 생성자 기본값(`this.label = '…'`)은 `String? label` 로 바꾸고 `build` 에서 `label ?? context.l10n.키` 로 푼다. `static const` 문구는, 다른 파일·테스트가 참조하면 `static String get` 으로 바꿔 `appL10n.키` 를 돌려주고(API 이름 유지), 같은 파일 안에서만 쓰면 `build` 에서 푼다. 상수를 `const` 로 참조하던 테스트는 한글 리터럴로 바꾼다.
5. **`context` 가 없는 층**(도메인 getter·enum 라벨·저장소 대체 문구): getter API 를 그대로 두고 값만 `appL10n.키` 로 돌려준다. 이런 getter 는 `context.l10n` 을 읽는 위젯의 `build` 안에서만 부른다(언어가 바뀔 때 같이 다시 그려진다).
6. **조사**: `'$name${name.objectParticle} …'` → ARB `"{name}{batchim, select, yes{을} other{를}} …"`(`batchim` 도 `String` 자리표시자) → `context.l10n.키(name, batchimOf(name))`. 코드가 조사 글자를 붙이지 않는다. `import 'package:elum/core/l10n/batchim.dart';` (프로젝트 내부는 상대 경로).
7. **단위·복수**: `'$n개'` → `"{count, plural, other{{count}개}}"`(ko 는 `other` 하나. 영어 등은 번역 단계에서 `one` 을 더한다).
8. **날짜**: `core/l10n/date_labels.dart` 의 `yearMonthDay`·`monthDaySince`·`resetAt` 을 쓴다.
9. `\n`·`*강조*` 같은 표식은 문구 그대로 ARB 에 옮긴다(JSON 에서는 `\n`). 작은따옴표는 ICU 에서 `''` 로 쓴다.

위 표의 줄을 위에서 아래로 처리한다. 이 폴더의 키 접두어는 ``credit` `adReward`` 이다.

- [ ] **Step 5: 생성·분석·감사**

```bash
cd client && flutter gen-l10n && flutter analyze && dart run tool/l10n_ko_audit.dart --base 99b65ac0
```
Expected: `No issues found!`, `--- 조각 N개 중 기준 커밋에 없는 것 0개`.

- [ ] **Step 6: 검사기와 테스트**

```bash
cd client && dart run tool/check_hangul_literals.dart lib/features/credit
cd client && flutter test test/l10n/ $(grep -rlE "package:elum/features/credit/" test | sort)
git status --short client/test | grep -c png
```
Expected: 검사기 `0줄`(종료 0). 테스트 **PASS**. PNG 변경 `0`(골든·시안 PNG 는 `--update-goldens` 없이 그대로 통과해야 한다).

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add client/lib/features/credit/application/ad_reward_flow.dart client/lib/features/credit/domain/credit_summary.dart client/lib/features/credit/presentation/credit_blocked_dialog.dart  client/lib/l10n client/test/l10n/credit_messages_ko_test.dart
```

## Task 19: notice — 공지 팝업

**Files:**
- Modify: 아래 표의 3개 파일, `client/lib/l10n/app_ko.arb`(+ 생성물)
- Modify(상수 참조 테스트): `client/test/notice_popup_test.dart:616`
- Test: `client/test/l10n/notice_messages_ko_test.dart`

**Interfaces:**
- Consumes: `appL10n`·`context.l10n` (Task 3)
- Produces: ARB 키 `noticeHideWeek` `noticeHideDays(days)` `noticeLinkOpenFailed(code)` `noticeCloseBarrier` … `String noticeHideLabel(int days)` 의 **시그니처는 그대로**다.

공지 본문·제목·버튼 문구는 서버가 준다(`app_notice` — 번역 행은 하위 계획 4). 이 Task 는 앱이 직접 가진 문구 4줄만 옮긴다.

대상:

| 파일 | 줄 수 | 줄 |
| --- | ---: | --- |
| `client/lib/features/notice/domain/app_notice.dart` | 1 | 195 |
| `client/lib/features/notice/presentation/notice_popup.dart` | 2 | 170, 183 |
| `client/lib/features/notice/presentation/show_notice_popup.dart` | 1 | 55 |
| **합계 3개 파일** | **4** | |

- [ ] **Step 1: 기준선을 센다**

Run: `cd client && dart run tool/check_hangul_literals.dart lib/features/notice | tail -1`
Expected: `--- 사용자 노출 한글 리터럴 4줄`(종료 코드 1)

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`client/test/l10n/notice_messages_ko_test.dart`

```dart
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/features/notice/domain/app_notice.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  test('보지 않기 문구 — 기본 일수면 일주일간, 아니면 N일간', () {
    expect(noticeHideLabel(NoticeFeed.defaultHideDays), '일주일간 보지 않기');
    expect(noticeHideLabel(3), '3일간 보지 않기');
    expect(ko.noticeHideWeek, '일주일간 보지 않기');
    expect(ko.noticeHideDays(30), '30일간 보지 않기');
  });

  test('링크 실패와 배경 막', () {
    expect(ko.noticeLinkOpenFailed('E-NOTICE-LINK'), '링크를 열지 못했어요 (E-NOTICE-LINK)');
    expect(ko.noticeCloseBarrier, '공지 닫기');
  });
}
```

Run: `cd client && flutter test test/l10n/notice_messages_ko_test.dart`
Expected: **FAIL** — 키가 없다.

- [ ] **Step 3: 특수 문구와 구조를 바꾼다**

`client/lib/l10n/app_ko.arb` 에 더한다.

```json
  "noticeHideWeek": "일주일간 보지 않기",
  "@noticeHideWeek": { "description": "공지 팝업 체크박스. 숨기는 기간이 기본(7일)일 때" },

  "noticeHideDays": "{days, plural, other{{days}일간 보지 않기}}",
  "@noticeHideDays": {
    "description": "공지 팝업 체크박스. 숨기는 기간이 기본이 아닐 때. days 는 일수",
    "placeholders": { "days": { "type": "int" } }
  },

  "noticeLinkOpenFailed": "링크를 열지 못했어요 ({code})",
  "@noticeLinkOpenFailed": {
    "description": "공지의 링크 버튼이 외부 브라우저를 못 열었을 때. 괄호 안은 추적용 에러 코드(번역하지 않는다)",
    "placeholders": { "code": { "type": "String" } }
  },

  "noticeCloseBarrier": "공지 닫기",
  "@noticeCloseBarrier": { "description": "공지 팝업 바깥 배경 막을 낭독기가 읽는 이름" },
```

`client/lib/features/notice/domain/app_notice.dart:194-195` — 시그니처 그대로, `context` 없는 함수라 `appL10n`(규칙 5)

```dart
/// `보지 않기` 문구. 일수는 관리자 설정 하나(`NOTICE_HIDE_DAYS`)라 모든 공지가 같다.
String noticeHideLabel(int days) => days == NoticeFeed.defaultHideDays
    ? appL10n.noticeHideWeek
    : appL10n.noticeHideDays(days);
```
(`import '../../../core/l10n/current_l10n.dart';`)

`client/lib/features/notice/presentation/show_notice_popup.dart:55,75` — 상수를 없애고 `context` 에서 읽는다.

```dart
    barrierLabel: context.l10n.noticeCloseBarrier,
```
(55행의 `const noticeBarrierLabel = '공지 닫기';` 와 위 주석을 지운다.) 테스트 `client/test/notice_popup_test.dart:616` 은 `find.bySemanticsLabel('공지 닫기')` 로 바꾼다.

`client/lib/features/notice/presentation/notice_popup.dart:170,183` — `context.l10n.noticeLinkOpenFailed(NoticePopupCard.linkFailureCode)`, 닫기 버튼 `label: context.l10n.commonClose`.

- [ ] **Step 4: 나머지 문구를 규칙대로 옮긴다**

**변환 규칙** (아래 대상 파일 전부에 같다. 한국어 문구는 한 글자도 바꾸지 않는다 — 감사기가 잡는다)

1. **위젯 안의 문구**: `Text('확인')` → `Text(context.l10n.commonConfirm)`. 키는 `app_ko.arb` 에 `"키": "확인"` 과 `"@키": { "description": "어디에 쓰이는 문구인지" }` 로 더한다. 같은 문구가 이미 있으면(`commonConfirm`·`commonCancel`·`commonClose`·`commonNext`·`commonRetry` 등) 키를 재사용한다. `const` 에 걸리면 가장 가까운 바깥 `const` 를 뗀다(analyze 가 위치를 알려준다). 파일 맨 위에 `core/l10n/l10n_context.dart`(`context.l10n`)·`core/l10n/current_l10n.dart`(`appL10n`) import 를 더한다.
2. **보간**: `'$name의 하루'` → ARB `"{name}의 하루"` 와 `"@키": { "placeholders": { "name": { "type": "String" } } }` → `context.l10n.키(name)`. 숫자는 `"type": "int"`.
3. **`String` 인자로 넘기는 문구**(`showFailure(title:, fallback:)`·`ElumDialogAction(label:)`): 호출 지점에서 `context.l10n` 으로 넘긴다. `await` 뒤에서 `context` 를 쓰면 `use_build_context_synchronously` 가 걸리므로 함수 맨 앞에서 `final l10n = context.l10n;` 로 잡아 둔다.
4. **상수·기본값**: 생성자 기본값(`this.label = '…'`)은 `String? label` 로 바꾸고 `build` 에서 `label ?? context.l10n.키` 로 푼다. `static const` 문구는, 다른 파일·테스트가 참조하면 `static String get` 으로 바꿔 `appL10n.키` 를 돌려주고(API 이름 유지), 같은 파일 안에서만 쓰면 `build` 에서 푼다. 상수를 `const` 로 참조하던 테스트는 한글 리터럴로 바꾼다.
5. **`context` 가 없는 층**(도메인 getter·enum 라벨·저장소 대체 문구): getter API 를 그대로 두고 값만 `appL10n.키` 로 돌려준다. 이런 getter 는 `context.l10n` 을 읽는 위젯의 `build` 안에서만 부른다(언어가 바뀔 때 같이 다시 그려진다).
6. **조사**: `'$name${name.objectParticle} …'` → ARB `"{name}{batchim, select, yes{을} other{를}} …"`(`batchim` 도 `String` 자리표시자) → `context.l10n.키(name, batchimOf(name))`. 코드가 조사 글자를 붙이지 않는다. `import 'package:elum/core/l10n/batchim.dart';` (프로젝트 내부는 상대 경로).
7. **단위·복수**: `'$n개'` → `"{count, plural, other{{count}개}}"`(ko 는 `other` 하나. 영어 등은 번역 단계에서 `one` 을 더한다).
8. **날짜**: `core/l10n/date_labels.dart` 의 `yearMonthDay`·`monthDaySince`·`resetAt` 을 쓴다.
9. `\n`·`*강조*` 같은 표식은 문구 그대로 ARB 에 옮긴다(JSON 에서는 `\n`). 작은따옴표는 ICU 에서 `''` 로 쓴다.

위 표의 줄을 위에서 아래로 처리한다. 이 폴더의 키 접두어는 ``notice`` 이다.

- [ ] **Step 5: 생성·분석·감사**

```bash
cd client && flutter gen-l10n && flutter analyze && dart run tool/l10n_ko_audit.dart --base 99b65ac0
```
Expected: `No issues found!`, `--- 조각 N개 중 기준 커밋에 없는 것 0개`.

- [ ] **Step 6: 검사기와 테스트**

```bash
cd client && dart run tool/check_hangul_literals.dart lib/features/notice
cd client && flutter test test/l10n/ $(grep -rlE "package:elum/features/notice/" test | sort)
git status --short client/test | grep -c png
```
Expected: 검사기 `0줄`(종료 0). 테스트 **PASS**. PNG 변경 `0`(골든·시안 PNG 는 `--update-goldens` 없이 그대로 통과해야 한다).

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add client/lib/features/notice/domain/app_notice.dart client/lib/features/notice/presentation/notice_popup.dart client/lib/features/notice/presentation/show_notice_popup.dart  client/lib/l10n client/test/l10n/notice_messages_ko_test.dart client/test/notice_popup_test.dart
```

## Task 20: guardian 도메인·데이터 — 사진 실패 문구·로딩 단계·추천 대체 목록

**Files:**
- Modify: 아래 표의 3개 파일, `client/lib/l10n/app_ko.arb`(+ 생성물)
- Test: `client/test/l10n/guardian_domain_messages_ko_test.dart`

**Interfaces:**
- Consumes: `appL10n` (Task 3), `commonRetryLater` (Task 12)
- Produces: ARB 키 `cardPhotoTooLarge` `cardPhotoWrongType` `cardPhotoUnreadable` `cardPhotoPickFailed` `routineLoadingPrepareTitle` `routineLoadingGenerateTitle` `routineStage*` `suggestion{Rainy,Hospital,Trip,NewPlace,AfterSchool}{Text,Prompt}` … `PhotoFailure.message`·`RoutineLoadingKind.title`·`RoutineStage.label`·`RoutineSuggestion.fallback` 의 **읽는 쪽 API 는 그대로**다.

이 폴더는 `const` 데이터에 한국어가 박혀 있다. 한글 인자를 **열쇠**로 바꾸고 읽을 때 앱 언어로 푼다.

대상:

| 파일 | 줄 수 | 줄 |
| --- | ---: | --- |
| `client/lib/features/guardian/data/card_photo.dart` | 5 | 84, 90, 96, 103, 120 |
| `client/lib/features/guardian/domain/routine_stage.dart` | 8 | 25, 28-30, 36, 39-41 |
| `client/lib/features/guardian/domain/routine_suggestion.dart` | 10 | 69-70, 74-75, 79-80, 84-85, 91-92 |
| **합계 3개 파일** | **23** | |

`routine_repository.dart` 의 한글(로그·예외 문구·로컬 마스킹 정규식)과 `demo_cards.dart`·`dlp_screen.dart`(어디서도 쓰지 않음)는 번역 대상이 아니다 — 검사기가 건너뛴다(근거는 Task 9 의 목록).

- [ ] **Step 1: 기준선을 센다**

Run: `cd client && dart run tool/check_hangul_literals.dart lib/features/guardian/data lib/features/guardian/domain lib/features/guardian/application | tail -1`
Expected: `--- 사용자 노출 한글 리터럴 23줄`(종료 코드 1)

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`client/test/l10n/guardian_domain_messages_ko_test.dart`

```dart
import 'package:elum/features/guardian/data/card_photo.dart';
import 'package:elum/features/guardian/domain/routine_stage.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

/// const 데이터의 한글을 열쇠로 바꿨어도 읽는 쪽 결과가 옛 문구와 같다.
void main() {
  test('사진 실패 문구 — const 인스턴스가 읽을 때 푼다', () {
    expect(PhotoFailure.size.message, '사진이 너무 커요. 다른 사진을 골라 주세요');
    expect(PhotoFailure.type.message, 'JPG나 PNG 사진만 올릴 수 있어요');
    expect(PhotoFailure.unreadable.message, '사진을 읽지 못했어요. 다른 사진을 골라 주세요');
    expect(PhotoFailure.pick.message, '사진을 가져오지 못했어요. 다시 해주세요');
    expect(PhotoFailure.size.code, 'E-PHOTO-SIZE');
  });

  test('로딩 화면 제목과 체크리스트', () {
    expect(RoutineLoadingKind.prepare.title, '루미가 내용을\n정리하고 있어요');
    expect(RoutineLoadingKind.generate.title, '루미가 행동카드를\n만들고 있어요');
    expect(RoutineLoadingKind.prepare.stages.map((s) => s.label).toList(), [
      '적어 주신 상황을 살펴보고 있어요',
      '꼭 필요한 내용만 정리해요',
      '추가 질문을 생각하고 있어요',
    ]);
    expect(RoutineLoadingKind.generate.stages.map((s) => s.label).toList(), [
      '오늘의 일과를 읽고 있어요',
      '중요한 준비물을 찾고 있어요',
      '순서를 정리하고 있어요',
    ]);
    expect(RoutineLoadingKind.prepare.stages.map((s) => s.percent).toList(), [15, 40, 65]);
  });

  test('서버가 죽었을 때의 추천 대체 목록 다섯', () {
    final fallback = RoutineSuggestion.fallback;
    expect(fallback.map((s) => s.text).toList(), [
      '비 오는 날 등교',
      '병원 방문 준비',
      '체험학습 준비',
      '새로운 장소 방문',
      '여름방학 방과후 수업 준비',
    ]);
    expect(fallback.first.icon, '☔️');
    expect(fallback.first.prompt, '비 오는 날 우산 챙겨서 학교 가는 준비를 하고 싶어요');
    expect(fallback[1].prompt, '이룸이와 함께 병원에 가야 하는데 무서워하지 않게 준비하고 싶어요');
  });
}
```

Run: `cd client && flutter test test/l10n/guardian_domain_messages_ko_test.dart`
Expected: 현재는 **PASS 하는 줄이 많다**(문구가 아직 코드에 있어서). 이 테스트는 구조를 바꾸는 동안의 **회귀 고정**이다 — 아래 Step 3~4 후에도 같은 값으로 통과해야 한다. 실패를 먼저 확인할 것은 검사기(Step 1)다.

- [ ] **Step 3: 구조를 바꾼다**

`client/lib/features/guardian/data/card_photo.dart:71-123` — 문구를 만들 때가 아니라 **읽을 때** 푼다. `const` 인스턴스(`PhotoFailure.size` 등)는 `const` 호출처가 여럿이라(`const PhotoUploadResult.failed(PhotoFailure.size)`) 그대로 두려고, 문구 자리에 **함수 참조**(상수로 쓸 수 있다)를 넣는다.

```dart
class PhotoFailure {
  const PhotoFailure({
    required this.code,
    required String Function() messageOf,
    required this.kind,
  }) : _messageOf = messageOf;

  final String code;
  final PhotoFailureKind kind;
  final String Function() _messageOf;

  /// 사용자에게 보일 문구 — 앱 언어로 **읽을 때** 푼다.
  String get message => _messageOf();

  static String _tooLarge() => appL10n.cardPhotoTooLarge;
  static String _wrongType() => appL10n.cardPhotoWrongType;
  static String _unreadable() => appL10n.cardPhotoUnreadable;
  static String _pickFailed() => appL10n.cardPhotoPickFailed;

  static const size = PhotoFailure(
    code: 'E-PHOTO-SIZE',
    messageOf: _tooLarge,
    kind: PhotoFailureKind.pickAnother,
  );

  static const type = PhotoFailure(
    code: 'E-PHOTO-TYPE',
    messageOf: _wrongType,
    kind: PhotoFailureKind.pickAnother,
  );

  static const unreadable = PhotoFailure(
    code: 'E-PHOTO-READ',
    messageOf: _unreadable,
    kind: PhotoFailureKind.pickAnother,
  );

  /// 사진 앱을 여는 것부터 실패했다 — 권한 거부·취소가 아닌 그 밖의 경우.
  static const pick = PhotoFailure(
    code: 'E-PHOTO-PICK',
    messageOf: _pickFailed,
    kind: PhotoFailureKind.pickAnother,
  );

  factory PhotoFailure.from(AppFailure f) {
    final status = f.server?.statusCode;
    final kind = switch (status) {
      400 => PhotoFailureKind.pickAnother,
      401 || 403 || 404 => PhotoFailureKind.dismissOnly,
      _ => PhotoFailureKind.retrySame,
    };
    // 문구는 서버 것이 이긴다(이미 해요체). 서버에 못 닿았으면 [AppFailure.hint] 가 말한다.
    final text = f.serverMessage ?? f.hint ?? appL10n.commonRetryLater;
    return PhotoFailure(
      code: f.badgeOr('E-PHOTO'),
      messageOf: () => text,
      kind: kind,
    );
  }
}
```
(`import '../../../core/l10n/current_l10n.dart';`)

`client/lib/features/guardian/domain/routine_stage.dart` — 제목과 체크리스트 문구를 열쇠로 바꾼다.

```dart
import '../../../core/l10n/current_l10n.dart';

enum RoutineLoadingKind {
  /// 262:4569 — 추가 질문 준비
  prepare(
    lumiSide: LumiSide.left,
    stages: [
      RoutineStage(text: RoutineStageText.reviewSituation, percent: 15, hold: _holdLong),
      RoutineStage(text: RoutineStageText.tidyEssentials, percent: 40, hold: _holdShort),
      RoutineStage(text: RoutineStageText.thinkQuestions, percent: 65, hold: _holdLong),
    ],
  ),

  /// 262:4703 — 행동카드 생성
  generate(
    lumiSide: LumiSide.right,
    stages: [
      RoutineStage(text: RoutineStageText.readRoutine, percent: 70, hold: _holdLong),
      RoutineStage(text: RoutineStageText.findItems, percent: 80, hold: _holdShort),
      RoutineStage(text: RoutineStageText.orderSteps, percent: 90, hold: _holdLong),
    ],
  );

  const RoutineLoadingKind({required this.stages, required this.lumiSide});

  /// 체크리스트 3줄
  final List<RoutineStage> stages;

  /// 루미가 나오는 방향 (Figma `Group 26` x좌표)
  final LumiSide lumiSide;

  /// 화면 제목 (Figma 원문 — 줄바꿈 위치까지 그대로) — 앱 언어의 문구다.
  String get title => switch (this) {
    RoutineLoadingKind.prepare => appL10n.routineLoadingPrepareTitle,
    RoutineLoadingKind.generate => appL10n.routineLoadingGenerateTitle,
  };
}

/// 체크리스트 문구의 열쇠 — 문구는 ARB 에 있고 여기서는 어느 문구인지만 안다.
enum RoutineStageText {
  reviewSituation,
  tidyEssentials,
  thinkQuestions,
  readRoutine,
  findItems,
  orderSteps,
}

class RoutineStage {
  const RoutineStage({
    required this.text,
    required this.percent,
    required this.hold,
  });

  final RoutineStageText text;

  /// 화면에 보이는 문구 (Figma 원문) — 앱 언어의 문구다.
  String get label => switch (text) {
    RoutineStageText.reviewSituation => appL10n.routineStageReviewSituation,
    RoutineStageText.tidyEssentials => appL10n.routineStageTidyEssentials,
    RoutineStageText.thinkQuestions => appL10n.routineStageThinkQuestions,
    RoutineStageText.readRoutine => appL10n.routineStageReadRoutine,
    RoutineStageText.findItems => appL10n.routineStageFindItems,
    RoutineStageText.orderSteps => appL10n.routineStageOrderSteps,
  };
  // …(percent·hold 필드와 주석은 그대로)…
```

`client/lib/features/guardian/domain/routine_suggestion.dart:62-100` — `const` 목록을 getter 로 바꾼다(`RoutineSuggestion.fallback` 을 쓰는 곳은 목록을 읽기만 한다).

```dart
  /// 서버가 죽었을 때 쓰는 대체 목록. 앱 언어의 문구로 **부를 때마다** 만든다.
  ///
  /// **API가 붙어도 지우지 않는다.** 추천이 비면 홈 화면 한 블록이 통째로 사라져 빈 화면처럼
  /// 보인다. 데모는 어떤 실패에서도 진행되어야 한다(docs 원칙 6번).
  static List<RoutineSuggestion> get fallback => [
    RoutineSuggestion(
      icon: '☔️',
      text: appL10n.suggestionRainyText,
      prompt: appL10n.suggestionRainyPrompt,
    ),
    RoutineSuggestion(
      icon: '🏥',
      text: appL10n.suggestionHospitalText,
      prompt: appL10n.suggestionHospitalPrompt,
    ),
    RoutineSuggestion(
      icon: '🌱',
      text: appL10n.suggestionTripText,
      prompt: appL10n.suggestionTripPrompt,
    ),
    RoutineSuggestion(
      icon: '🚗',
      text: appL10n.suggestionNewPlaceText,
      prompt: appL10n.suggestionNewPlacePrompt,
    ),
    // 다섯 번째 — 시안(`238:1643`)이 그린 마지막 칩이다 (#297).
    RoutineSuggestion(
      icon: '🎒',
      text: appL10n.suggestionAfterSchoolText,
      prompt: appL10n.suggestionAfterSchoolPrompt,
    ),
  ];
```
ko 값은 위 테스트가 적은 문구와 같다(`suggestionRainyText`=`비 오는 날 등교` …).


나머지 단순 문구 중 **위 코드·테스트가 이름으로 부르는 것**도 같은 파일에 더한다(이름과 `ko` 값은 아래가 정한다. 이 폴더의 나머지 문구는 Step 4 에서 규칙대로 더한다).

```json
  "cardPhotoTooLarge": "사진이 너무 커요. 다른 사진을 골라 주세요",
  "@cardPhotoTooLarge": { "description": "카드 사진 업로드 실패 — 크기" },

  "cardPhotoWrongType": "JPG나 PNG 사진만 올릴 수 있어요",
  "@cardPhotoWrongType": { "description": "카드 사진 업로드 실패 — 형식" },

  "cardPhotoUnreadable": "사진을 읽지 못했어요. 다른 사진을 골라 주세요",
  "@cardPhotoUnreadable": { "description": "카드 사진 업로드 실패 — 읽기" },

  "cardPhotoPickFailed": "사진을 가져오지 못했어요. 다시 해주세요",
  "@cardPhotoPickFailed": { "description": "카드 사진 고르기 실패" },

  "routineLoadingPrepareTitle": "루미가 내용을\n정리하고 있어요",
  "@routineLoadingPrepareTitle": { "description": "추가 질문 준비 로딩의 제목(줄바꿈 위치는 시안대로)" },

  "routineLoadingGenerateTitle": "루미가 행동카드를\n만들고 있어요",
  "@routineLoadingGenerateTitle": { "description": "행동카드 생성 로딩의 제목(줄바꿈 위치는 시안대로)" },

  "routineStageReviewSituation": "적어 주신 상황을 살펴보고 있어요",
  "@routineStageReviewSituation": { "description": "준비 로딩 체크리스트 1" },

  "routineStageTidyEssentials": "꼭 필요한 내용만 정리해요",
  "@routineStageTidyEssentials": { "description": "준비 로딩 체크리스트 2" },

  "routineStageThinkQuestions": "추가 질문을 생각하고 있어요",
  "@routineStageThinkQuestions": { "description": "준비 로딩 체크리스트 3" },

  "routineStageReadRoutine": "오늘의 일과를 읽고 있어요",
  "@routineStageReadRoutine": { "description": "생성 로딩 체크리스트 1" },

  "routineStageFindItems": "중요한 준비물을 찾고 있어요",
  "@routineStageFindItems": { "description": "생성 로딩 체크리스트 2" },

  "routineStageOrderSteps": "순서를 정리하고 있어요",
  "@routineStageOrderSteps": { "description": "생성 로딩 체크리스트 3" },

  "suggestionRainyText": "비 오는 날 등교",
  "@suggestionRainyText": { "description": "서버가 죽었을 때의 추천 칩 1 글" },

  "suggestionRainyPrompt": "비 오는 날 우산 챙겨서 학교 가는 준비를 하고 싶어요",
  "@suggestionRainyPrompt": { "description": "추천 칩 1 이 입력창에 채우는 문장" },

  "suggestionHospitalText": "병원 방문 준비",
  "@suggestionHospitalText": { "description": "추천 칩 2 글" },

  "suggestionHospitalPrompt": "이룸이와 함께 병원에 가야 하는데 무서워하지 않게 준비하고 싶어요",
  "@suggestionHospitalPrompt": { "description": "추천 칩 2 가 입력창에 채우는 문장" },

  "suggestionTripText": "체험학습 준비",
  "@suggestionTripText": { "description": "추천 칩 3 글" },

  "suggestionTripPrompt": "체험학습 가는 날 아침에 챙길 것들을 순서대로 알려주고 싶어요",
  "@suggestionTripPrompt": { "description": "추천 칩 3 이 입력창에 채우는 문장" },

  "suggestionNewPlaceText": "새로운 장소 방문",
  "@suggestionNewPlaceText": { "description": "추천 칩 4 글" },

  "suggestionNewPlacePrompt": "처음 가보는 장소에 가기 전에 이룸이가 마음의 준비를 하게 돕고 싶어요",
  "@suggestionNewPlacePrompt": { "description": "추천 칩 4 가 입력창에 채우는 문장" },

  "suggestionAfterSchoolText": "여름방학 방과후 수업 준비",
  "@suggestionAfterSchoolText": { "description": "추천 칩 5 글" },

  "suggestionAfterSchoolPrompt": "방학 중 방과후 수업에 갈 준비를 순서대로 알려주고 싶어요",
  "@suggestionAfterSchoolPrompt": { "description": "추천 칩 5 가 입력창에 채우는 문장" }
```

- [ ] **Step 4: 나머지 문구를 규칙대로 옮긴다**

**변환 규칙** (아래 대상 파일 전부에 같다. 한국어 문구는 한 글자도 바꾸지 않는다 — 감사기가 잡는다)

1. **위젯 안의 문구**: `Text('확인')` → `Text(context.l10n.commonConfirm)`. 키는 `app_ko.arb` 에 `"키": "확인"` 과 `"@키": { "description": "어디에 쓰이는 문구인지" }` 로 더한다. 같은 문구가 이미 있으면(`commonConfirm`·`commonCancel`·`commonClose`·`commonNext`·`commonRetry` 등) 키를 재사용한다. `const` 에 걸리면 가장 가까운 바깥 `const` 를 뗀다(analyze 가 위치를 알려준다). 파일 맨 위에 `core/l10n/l10n_context.dart`(`context.l10n`)·`core/l10n/current_l10n.dart`(`appL10n`) import 를 더한다.
2. **보간**: `'$name의 하루'` → ARB `"{name}의 하루"` 와 `"@키": { "placeholders": { "name": { "type": "String" } } }` → `context.l10n.키(name)`. 숫자는 `"type": "int"`.
3. **`String` 인자로 넘기는 문구**(`showFailure(title:, fallback:)`·`ElumDialogAction(label:)`): 호출 지점에서 `context.l10n` 으로 넘긴다. `await` 뒤에서 `context` 를 쓰면 `use_build_context_synchronously` 가 걸리므로 함수 맨 앞에서 `final l10n = context.l10n;` 로 잡아 둔다.
4. **상수·기본값**: 생성자 기본값(`this.label = '…'`)은 `String? label` 로 바꾸고 `build` 에서 `label ?? context.l10n.키` 로 푼다. `static const` 문구는, 다른 파일·테스트가 참조하면 `static String get` 으로 바꿔 `appL10n.키` 를 돌려주고(API 이름 유지), 같은 파일 안에서만 쓰면 `build` 에서 푼다. 상수를 `const` 로 참조하던 테스트는 한글 리터럴로 바꾼다.
5. **`context` 가 없는 층**(도메인 getter·enum 라벨·저장소 대체 문구): getter API 를 그대로 두고 값만 `appL10n.키` 로 돌려준다. 이런 getter 는 `context.l10n` 을 읽는 위젯의 `build` 안에서만 부른다(언어가 바뀔 때 같이 다시 그려진다).
6. **조사**: `'$name${name.objectParticle} …'` → ARB `"{name}{batchim, select, yes{을} other{를}} …"`(`batchim` 도 `String` 자리표시자) → `context.l10n.키(name, batchimOf(name))`. 코드가 조사 글자를 붙이지 않는다. `import 'package:elum/core/l10n/batchim.dart';` (프로젝트 내부는 상대 경로).
7. **단위·복수**: `'$n개'` → `"{count, plural, other{{count}개}}"`(ko 는 `other` 하나. 영어 등은 번역 단계에서 `one` 을 더한다).
8. **날짜**: `core/l10n/date_labels.dart` 의 `yearMonthDay`·`monthDaySince`·`resetAt` 을 쓴다.
9. `\n`·`*강조*` 같은 표식은 문구 그대로 ARB 에 옮긴다(JSON 에서는 `\n`). 작은따옴표는 ICU 에서 `''` 로 쓴다.

위 표의 줄을 위에서 아래로 처리한다. 이 폴더의 키 접두어는 ``cardPhoto` `routineLoading` `routineStage` `suggestion`` 이다.

- [ ] **Step 5: 생성·분석·감사**

```bash
cd client && flutter gen-l10n && flutter analyze && dart run tool/l10n_ko_audit.dart --base 99b65ac0
```
Expected: `No issues found!`, `--- 조각 N개 중 기준 커밋에 없는 것 0개`.

- [ ] **Step 6: 검사기와 테스트**

```bash
cd client && dart run tool/check_hangul_literals.dart lib/features/guardian/data lib/features/guardian/domain lib/features/guardian/application
cd client && flutter test test/l10n/ $(grep -rlE "package:elum/features/guardian/(data|domain|application)/|package:elum/shared/models/routine" test | sort)
git status --short client/test | grep -c png
```
Expected: 검사기 `0줄`(종료 0). 테스트 **PASS**. PNG 변경 `0`(골든·시안 PNG 는 `--update-goldens` 없이 그대로 통과해야 한다).

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add client/lib/features/guardian/data/card_photo.dart client/lib/features/guardian/domain/routine_stage.dart client/lib/features/guardian/domain/routine_suggestion.dart  client/lib/l10n client/test/l10n/guardian_domain_messages_ko_test.dart
```

## Task 21: guardian 화면 — 홈·설정·일과 만들기 흐름·카드 검토

**Files:**
- Modify: 아래 표의 10개 파일, `client/lib/l10n/app_ko.arb`(+ 생성물). (`dlp_screen.dart` 는 어디서도 열지 않는 화면이라 건너뛴다.)
- Test: `client/test/l10n/guardian_screens_messages_ko_test.dart`

**Interfaces:**
- Consumes: `context.l10n`·`appL10n` (Task 3), 공용 키(`commonConfirm`·`commonCancel`·`commonNext`·`commonRetryLater`·`commonRetry`)
- Produces: ARB 키 `guardianHomeGreeting(name)` `routineLoadingPercent(percent)` `rewardWhyTitle` `rewardWhyMessage` `questionClearLabel(label)` … `RewardSetupScreen.whyMessage` 의 **API 는 그대로**(정적 getter).

대상:

| 파일 | 줄 수 | 줄 |
| --- | ---: | --- |
| `client/lib/features/guardian/presentation/guardian_home_screen.dart` | 6 | 220, 227, 368, 381, 396, 401 |
| `client/lib/features/guardian/presentation/pin_change_screen.dart` | 15 | 133-134, 167-168, 182, 188, 191-192, 194, 197-198, 201, 221, 225, 247 |
| `client/lib/features/guardian/presentation/reward_setup_screen.dart` | 12 | 57-59, 144-145, 185, 223, 313, 319, 386, 404, 440 |
| `client/lib/features/guardian/presentation/image_style_settings_screen.dart` | 4 | 64, 73-74, 104 |
| `client/lib/features/guardian/presentation/routine_loading_screen.dart` | 7 | 277, 279-280, 357, 681, 687, 689 |
| `client/lib/features/guardian/presentation/draft_routines_screen.dart` | 13 | 70, 88, 112, 141, 145, 149, 166-167, 225, 257, 286, 316, 324 |
| `client/lib/features/guardian/presentation/card_review_screen.dart` | 12 | 111, 115, 119, 156-157, 176-177, 218-219, 245-246, 345 |
| `client/lib/features/guardian/presentation/routine_input_screen.dart` | 4 | 267, 273, 371, 406 |
| `client/lib/features/guardian/presentation/guardian_settings_screen.dart` | 21 | 54, 57, 61, 76, 82, 85, 89, 106-107, 144, 169, 175, 180, 191, 212, 214, 244-245, 277, 296, 311 |
| `client/lib/features/guardian/presentation/question_screen.dart` | 5 | 113, 274, 353, 367, 442 |
| **합계 10개 파일** | **99** | |

- [ ] **Step 1: 기준선을 센다**

Run: `cd client && dart run tool/check_hangul_literals.dart lib/features/guardian/presentation/guardian_home_screen.dart lib/features/guardian/presentation/pin_change_screen.dart lib/features/guardian/presentation/reward_setup_screen.dart lib/features/guardian/presentation/image_style_settings_screen.dart lib/features/guardian/presentation/routine_loading_screen.dart lib/features/guardian/presentation/draft_routines_screen.dart lib/features/guardian/presentation/card_review_screen.dart lib/features/guardian/presentation/routine_input_screen.dart lib/features/guardian/presentation/guardian_settings_screen.dart lib/features/guardian/presentation/question_screen.dart | tail -1`
Expected: 표의 합계 `99줄`(종료 코드 1)

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`client/test/l10n/guardian_screens_messages_ko_test.dart`

```dart
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/features/guardian/presentation/reward_setup_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  test('홈 인사말 — 줄바꿈 위치까지 시안 그대로', () {
    expect(ko.guardianHomeGreeting('하늘이'), '안녕하세요,\n하늘이 보호자님 👋🏻');
  });

  test('로딩 진행률', () {
    expect(ko.routineLoadingPercent(40), '40% 진행됐어요');
  });

  test('보상이 왜 필요한가요 — 정적 getter 도 같은 문구', () {
    expect(ko.rewardWhyTitle, '보상이 왜 필요한가요?');
    expect(
      RewardSetupScreen.whyMessage,
      '일과를 마친 뒤 기다리는 것이 있으면 이룸이가 끝까지 해낼 힘이 생겨요.\n'
      '한 달 뒤 선물보다 오늘 바로 줄 수 있는 작은 것이 더 잘 통해요.\n'
      '정하지 않아도 일과는 만들 수 있어요.',
    );
  });

  test('추가 질문 칩 지우기 낭독 문구', () {
    expect(ko.questionClearLabel('우산'), '우산 지우기');
  });
}
```

Run: `cd client && flutter test test/l10n/guardian_screens_messages_ko_test.dart`
Expected: **FAIL** — 키가 없다.

- [ ] **Step 3: 특수 문구와 구조를 바꾼다**

`client/lib/l10n/app_ko.arb` 에 더한다.

```json
  "guardianHomeGreeting": "안녕하세요,\n{name} 보호자님 👋🏻",
  "@guardianHomeGreeting": {
    "description": "보호자 홈의 인사말(Figma 문구, 줄바꿈 위치도 디자인이 정한 대로). name 은 이룸이 호칭",
    "placeholders": { "name": { "type": "String" } }
  },

  "routineLoadingPercent": "{percent}% 진행됐어요",
  "@routineLoadingPercent": {
    "description": "일과 만들기 로딩의 진행률을 낭독기가 읽는 문장",
    "placeholders": { "percent": { "type": "int" } }
  },

  "rewardWhyTitle": "보상이 왜 필요한가요?",
  "@rewardWhyTitle": { "description": "보상 설명 팝업 제목이자 도움말 버튼 이름" },

  "rewardWhyMessage": "일과를 마친 뒤 기다리는 것이 있으면 이룸이가 끝까지 해낼 힘이 생겨요.\n한 달 뒤 선물보다 오늘 바로 줄 수 있는 작은 것이 더 잘 통해요.\n정하지 않아도 일과는 만들 수 있어요.",
  "@rewardWhyMessage": { "description": "보상이 왜 필요한지 설명하는 팝업 본문(세 문장, 줄바꿈 유지)" },

  "questionClearLabel": "{label} 지우기",
  "@questionClearLabel": {
    "description": "추가 질문에서 고른 칩의 X 버튼을 낭독기가 읽는 이름. label 은 칩 글자",
    "placeholders": { "label": { "type": "String" } }
  },
```

`client/lib/features/guardian/presentation/reward_setup_screen.dart:56-59` — 다른 파일·테스트가 참조하는 정적 상수라 **정적 getter** 로(규칙 4).

```dart
  /// `보상이 왜 필요한가요?` 팝업 본문 (#380 결정 3 · 개발 문구 — 디자인이 나오면 교체).
  static String get whyMessage => appL10n.rewardWhyMessage;
```
`_explain()`(185행)의 `title: '보상이 왜 필요한가요?'` 는 `context.l10n.rewardWhyTitle`, 386·404행도 같다.

`client/lib/features/guardian/presentation/routine_loading_screen.dart:277-281, 357, 681-689`

```dart
          title: isCreditBlockingCode(flow.errorCode)
              ? context.l10n.routineLoadingBlockedTitle
              : switch (widget.kind) {
                  RoutineLoadingKind.prepare => context.l10n.routineLoadingPrepareFailed,
                  RoutineLoadingKind.generate => context.l10n.routineLoadingGenerateFailed,
                },
```
(`routineLoadingBlockedTitle`=`지금은 만들 수 없어요`, `routineLoadingPrepareFailed`=`질문을 준비하지 못했어요`, `routineLoadingGenerateFailed`=`카드를 만들지 못했어요`. 357행 `context.l10n.routineLoadingPercent(value.round())`. 681행 `errorHint ?? context.l10n.commonRetryLater`, 버튼은 `routineLoadingRetry`=`다시 하기`·`routineLoadingHome`=`홈으로`.)

`client/lib/features/guardian/presentation/guardian_home_screen.dart:396`

```dart
            context.l10n.guardianHomeGreeting(childName),
```

`client/lib/features/guardian/presentation/question_screen.dart:442`

```dart
                    label: context.l10n.questionClearLabel(label),
```

`client/lib/features/guardian/presentation/pin_change_screen.dart:186-201` — 단계별 제목·설명 튜플은 `build` 안이라 `context.l10n` 키로 바꾼다. 같은 설명 `보호자모드로 변경할 때 사용하는 암호예요` 는 키 하나(`pinModeHint`)를 세 곳이 쓴다.


나머지 단순 문구 중 **위 코드·테스트가 이름으로 부르는 것**도 같은 파일에 더한다(이름과 `ko` 값은 아래가 정한다. 이 폴더의 나머지 문구는 Step 4 에서 규칙대로 더한다).

```json
  "routineLoadingBlockedTitle": "지금은 만들 수 없어요",
  "@routineLoadingBlockedTitle": { "description": "크레딧 때문에 막혔을 때의 로딩 실패 제목" },

  "routineLoadingPrepareFailed": "질문을 준비하지 못했어요",
  "@routineLoadingPrepareFailed": { "description": "준비 로딩 실패 제목" },

  "routineLoadingGenerateFailed": "카드를 만들지 못했어요",
  "@routineLoadingGenerateFailed": { "description": "생성 로딩 실패 제목" },

  "routineLoadingRetry": "다시 하기",
  "@routineLoadingRetry": { "description": "로딩 실패 화면의 다시 하기 버튼" },

  "routineLoadingHome": "홈으로",
  "@routineLoadingHome": { "description": "로딩 실패 화면의 홈 버튼" }
```

- [ ] **Step 4: 나머지 문구를 규칙대로 옮긴다**

**변환 규칙** (아래 대상 파일 전부에 같다. 한국어 문구는 한 글자도 바꾸지 않는다 — 감사기가 잡는다)

1. **위젯 안의 문구**: `Text('확인')` → `Text(context.l10n.commonConfirm)`. 키는 `app_ko.arb` 에 `"키": "확인"` 과 `"@키": { "description": "어디에 쓰이는 문구인지" }` 로 더한다. 같은 문구가 이미 있으면(`commonConfirm`·`commonCancel`·`commonClose`·`commonNext`·`commonRetry` 등) 키를 재사용한다. `const` 에 걸리면 가장 가까운 바깥 `const` 를 뗀다(analyze 가 위치를 알려준다). 파일 맨 위에 `core/l10n/l10n_context.dart`(`context.l10n`)·`core/l10n/current_l10n.dart`(`appL10n`) import 를 더한다.
2. **보간**: `'$name의 하루'` → ARB `"{name}의 하루"` 와 `"@키": { "placeholders": { "name": { "type": "String" } } }` → `context.l10n.키(name)`. 숫자는 `"type": "int"`.
3. **`String` 인자로 넘기는 문구**(`showFailure(title:, fallback:)`·`ElumDialogAction(label:)`): 호출 지점에서 `context.l10n` 으로 넘긴다. `await` 뒤에서 `context` 를 쓰면 `use_build_context_synchronously` 가 걸리므로 함수 맨 앞에서 `final l10n = context.l10n;` 로 잡아 둔다.
4. **상수·기본값**: 생성자 기본값(`this.label = '…'`)은 `String? label` 로 바꾸고 `build` 에서 `label ?? context.l10n.키` 로 푼다. `static const` 문구는, 다른 파일·테스트가 참조하면 `static String get` 으로 바꿔 `appL10n.키` 를 돌려주고(API 이름 유지), 같은 파일 안에서만 쓰면 `build` 에서 푼다. 상수를 `const` 로 참조하던 테스트는 한글 리터럴로 바꾼다.
5. **`context` 가 없는 층**(도메인 getter·enum 라벨·저장소 대체 문구): getter API 를 그대로 두고 값만 `appL10n.키` 로 돌려준다. 이런 getter 는 `context.l10n` 을 읽는 위젯의 `build` 안에서만 부른다(언어가 바뀔 때 같이 다시 그려진다).
6. **조사**: `'$name${name.objectParticle} …'` → ARB `"{name}{batchim, select, yes{을} other{를}} …"`(`batchim` 도 `String` 자리표시자) → `context.l10n.키(name, batchimOf(name))`. 코드가 조사 글자를 붙이지 않는다. `import 'package:elum/core/l10n/batchim.dart';` (프로젝트 내부는 상대 경로).
7. **단위·복수**: `'$n개'` → `"{count, plural, other{{count}개}}"`(ko 는 `other` 하나. 영어 등은 번역 단계에서 `one` 을 더한다).
8. **날짜**: `core/l10n/date_labels.dart` 의 `yearMonthDay`·`monthDaySince`·`resetAt` 을 쓴다.
9. `\n`·`*강조*` 같은 표식은 문구 그대로 ARB 에 옮긴다(JSON 에서는 `\n`). 작은따옴표는 ICU 에서 `''` 로 쓴다.

위 표의 줄을 위에서 아래로 처리한다. 이 폴더의 키 접두어는 ``guardianHome` `guardianSettings` `routine` `card` `reward` `question` `pin`` 이다.

- [ ] **Step 5: 생성·분석·감사**

```bash
cd client && flutter gen-l10n && flutter analyze && dart run tool/l10n_ko_audit.dart --base 99b65ac0
```
Expected: `No issues found!`, `--- 조각 N개 중 기준 커밋에 없는 것 0개`.

- [ ] **Step 6: 검사기와 테스트**

```bash
cd client && dart run tool/check_hangul_literals.dart lib/features/guardian/presentation/guardian_home_screen.dart lib/features/guardian/presentation/pin_change_screen.dart lib/features/guardian/presentation/reward_setup_screen.dart lib/features/guardian/presentation/image_style_settings_screen.dart lib/features/guardian/presentation/routine_loading_screen.dart lib/features/guardian/presentation/draft_routines_screen.dart lib/features/guardian/presentation/card_review_screen.dart lib/features/guardian/presentation/routine_input_screen.dart lib/features/guardian/presentation/guardian_settings_screen.dart lib/features/guardian/presentation/question_screen.dart
cd client && flutter test test/l10n/ $(grep -rlE "package:elum/features/guardian/presentation/[a-z_]*screen|package:elum/features/guardian/application/" test | sort)
git status --short client/test | grep -c png
```
Expected: 검사기 `0줄`(종료 0). 테스트 **PASS**. PNG 변경 `0`(골든·시안 PNG 는 `--update-goldens` 없이 그대로 통과해야 한다).

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add client/lib/features/guardian/presentation/guardian_home_screen.dart client/lib/features/guardian/presentation/pin_change_screen.dart client/lib/features/guardian/presentation/reward_setup_screen.dart client/lib/features/guardian/presentation/image_style_settings_screen.dart client/lib/features/guardian/presentation/routine_loading_screen.dart client/lib/features/guardian/presentation/draft_routines_screen.dart client/lib/features/guardian/presentation/card_review_screen.dart client/lib/features/guardian/presentation/routine_input_screen.dart client/lib/features/guardian/presentation/guardian_settings_screen.dart client/lib/features/guardian/presentation/question_screen.dart  client/lib/l10n client/test/l10n/guardian_screens_messages_ko_test.dart
```

## Task 22: guardian 위젯 — 카드·일과 시트·크레딧 카드·코치마크

**Files:**
- Modify: 아래 표의 20개 파일, `client/lib/l10n/app_ko.arb`(+ 생성물), `client/tool/l10n_ko_audit_accepted.txt`(붙여 쓴 문자열 경계 조각 1줄)
- Test: `client/test/l10n/guardian_widgets_messages_ko_test.dart`

**Interfaces:**
- Consumes: `context.l10n`·`appL10n` (Task 3), 공용 키
- Produces: ARB 키 `cardReviewMade(count)` `creditAmountLeft(available, weekly)` `creditAmountRest(weekly)` `creditCostTitle` `creditCostLine(textCost, imageCost)` `creditCostKeepGoing` `creditWeeklyRefill` `aiCreditResetLine(reset)` `todayRoutineCopied(title)` `homeCoachCreate` `homeCoachSwipe` `homeCoachSwitch` `cardMoveForward` `cardMoveBackward` … `AiCreditInfo.title`·`message(CreditSummary)` 의 **API 는 그대로**.

대상:

| 파일 | 줄 수 | 줄 |
| --- | ---: | --- |
| `client/lib/features/guardian/presentation/widgets/create_routine_button.dart` | 1 | 132 |
| `client/lib/features/guardian/presentation/widgets/default_card_art.dart` | 2 | 58, 77 |
| `client/lib/features/guardian/presentation/widgets/action_card_view.dart` | 2 | 147, 473 |
| `client/lib/features/guardian/presentation/widgets/routine_swipe_actions.dart` | 2 | 27, 239 |
| `client/lib/features/guardian/presentation/widgets/recommended_routine_strip.dart` | 1 | 69 |
| `client/lib/features/guardian/presentation/widgets/card_photo_permission_screen.dart` | 7 | 58, 64, 86, 93-94, 115-116 |
| `client/lib/features/guardian/presentation/widgets/card_review_parts.dart` | 11 | 29, 79, 89, 131, 177, 185, 191, 284, 295, 323, 332 |
| `client/lib/features/guardian/presentation/widgets/routine_flow_scaffold.dart` | 10 | 327, 358, 373, 444, 449, 481, 483-484, 486-487 |
| `client/lib/features/guardian/presentation/widgets/routine_summary_tile.dart` | 2 | 198, 241 |
| `client/lib/features/guardian/presentation/widgets/card_photo_source_sheet.dart` | 4 | 64, 69, 74, 80 |
| `client/lib/features/guardian/presentation/widgets/card_photo_block.dart` | 8 | 172, 176, 284, 305, 370, 399, 420, 445 |
| `client/lib/features/guardian/presentation/widgets/step_card_viewer.dart` | 4 | 50, 116-117, 162 |
| `client/lib/features/guardian/presentation/widgets/ai_credit_card.dart` | 6 | 85, 91, 128, 133, 153, 165 |
| `client/lib/features/guardian/presentation/widgets/card_edit_sheet.dart` | 6 | 218, 242, 254, 263, 275, 287 |
| `client/lib/features/guardian/presentation/widgets/routine_detail_sheet.dart` | 5 | 117-118, 288, 539, 729 |
| `client/lib/features/guardian/presentation/widgets/card_review_reorder_list.dart` | 2 | 511, 514 |
| `client/lib/features/guardian/presentation/widgets/today_routine_section.dart` | 15 | 160-161, 172, 176, 180, 191-192, 239, 381-382, 389, 405, 474, 481, 505 |
| `client/lib/features/guardian/presentation/widgets/reward_chip.dart` | 1 | 136 |
| `client/lib/features/guardian/presentation/widgets/ai_credit_summary_view.dart` | 14 | 37, 41, 45-46, 49, 56, 68, 86, 144, 148-151, 167 |
| `client/lib/features/guardian/presentation/widgets/home_coach_mark.dart` | 3 | 54, 69, 92 |
| **합계 20개 파일** | **106** | |

- [ ] **Step 1: 기준선을 센다**

Run: `cd client && dart run tool/check_hangul_literals.dart lib/features/guardian/presentation/widgets/create_routine_button.dart lib/features/guardian/presentation/widgets/default_card_art.dart lib/features/guardian/presentation/widgets/action_card_view.dart lib/features/guardian/presentation/widgets/routine_swipe_actions.dart lib/features/guardian/presentation/widgets/recommended_routine_strip.dart lib/features/guardian/presentation/widgets/card_photo_permission_screen.dart lib/features/guardian/presentation/widgets/card_review_parts.dart lib/features/guardian/presentation/widgets/routine_flow_scaffold.dart lib/features/guardian/presentation/widgets/routine_summary_tile.dart lib/features/guardian/presentation/widgets/card_photo_source_sheet.dart lib/features/guardian/presentation/widgets/card_photo_block.dart lib/features/guardian/presentation/widgets/step_card_viewer.dart lib/features/guardian/presentation/widgets/ai_credit_card.dart lib/features/guardian/presentation/widgets/card_edit_sheet.dart lib/features/guardian/presentation/widgets/routine_detail_sheet.dart lib/features/guardian/presentation/widgets/card_review_reorder_list.dart lib/features/guardian/presentation/widgets/today_routine_section.dart lib/features/guardian/presentation/widgets/reward_chip.dart lib/features/guardian/presentation/widgets/ai_credit_summary_view.dart lib/features/guardian/presentation/widgets/home_coach_mark.dart | tail -1`
Expected: 표의 합계 `106줄`(종료 코드 1)

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`client/test/l10n/guardian_widgets_messages_ko_test.dart`

```dart
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 단위·복수·보간을 ARB 가 넘겨받아도 `ko` 문구가 옛 조립과 같다.
void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  test('카드 검토 머리 — 만든 카드 수', () {
    expect(ko.cardReviewMade(5), '카드 5개를 만들었어요');
  });

  test('AI 크레딧 카드의 숫자 줄', () {
    expect(ko.creditAmountLeft(72, 100), '72 / 100 크레딧 남음');
    // 큰 숫자만 따로 강조하므로 나머지 조각은 앞에 공백이 있다
    expect(ko.creditAmountRest(100), ' / 100 크레딧 남음');
    expect(ko.aiCreditResetLine('9월 28일(월) 0시'), '9월 28일(월) 0시에 다시 채워져요');
  });

  test('AI 크레딧 안내 팝업 — 서버 단가를 문장에 넣는다', () {
    expect(ko.creditCostTitle, 'AI 크레딧은 이렇게 줄어요');
    expect(
      ko.creditCostLine(1, 2),
      '일과 글을 만들 때 1개, 그림이 완성된 카드 1장마다 2개씩 써요.',
    );
    expect(ko.creditCostKeepGoing, '크레딧이 남아 있을 때 시작한 일과는 그림이 많아도 끝까지 만들어져요.');
    expect(ko.creditWeeklyRefill, '매주 월요일 0시에 다시 채워져요.');
  });

  test('오늘 일과에 담았어요 — 조사는 옛 문구 그대로 을(를)', () {
    expect(ko.todayRoutineCopied('비 오는 날 등교'), '비 오는 날 등교을(를) 오늘 일과에 담았어요');
  });

  test('홈 코치마크 문구 — 강조 표식과 줄바꿈 유지', () {
    expect(ko.homeCoachCreate, '이룸이가 수행할 *새로운\n일과를 만들 수 있어요*');
    expect(ko.homeCoachSwipe, '일과를 *왼쪽으로 스와이프*하면\n*수정하거나 삭제*할 수 있어요');
    expect(ko.homeCoachSwitch, '캐릭터 아이콘을 누르면\n*이룸이모드로 바꿀 수 있어요*');
  });

  test('순서 옮기기 낭독 동작', () {
    expect(ko.cardMoveForward, '앞으로 옮기기');
    expect(ko.cardMoveBackward, '뒤로 옮기기');
  });
}
```

Run: `cd client && flutter test test/l10n/guardian_widgets_messages_ko_test.dart`
Expected: **FAIL** — 키가 없다.

- [ ] **Step 3: 특수 문구와 구조를 바꾼다**

`client/lib/l10n/app_ko.arb` 에 더한다.

```json
  "cardReviewMade": "{count, plural, other{카드 {count}개를 만들었어요}}",
  "@cardReviewMade": {
    "description": "카드 검토 화면 머리. count 는 만들어진 카드 수",
    "placeholders": { "count": { "type": "int" } }
  },

  "creditAmountLeft": "{available} / {weekly} 크레딧 남음",
  "@creditAmountLeft": {
    "description": "AI 크레딧 카드의 낭독용 숫자 줄. available 은 남은 수, weekly 는 주간 지급량",
    "placeholders": { "available": { "type": "int" }, "weekly": { "type": "int" } }
  },

  "creditAmountRest": " / {weekly} 크레딧 남음",
  "@creditAmountRest": {
    "description": "AI 크레딧 카드에서 큰 숫자(남은 수) 뒤에 이어 붙는 작은 글자. 앞의 공백을 유지한다",
    "placeholders": { "weekly": { "type": "int" } }
  },

  "aiCreditResetLine": "{reset}에 다시 채워져요",
  "@aiCreditResetLine": {
    "description": "AI 크레딧이 다시 채워지는 시각 줄. reset 은 시각 문구(예: 9월 28일(월) 0시)",
    "placeholders": { "reset": { "type": "String" } }
  },

  "creditCostTitle": "AI 크레딧은 이렇게 줄어요",
  "@creditCostTitle": { "description": "AI 크레딧 안내 팝업 제목" },

  "creditCostLine": "일과 글을 만들 때 {textCost, plural, other{{textCost}개}}, 그림이 완성된 카드 1장마다 {imageCost, plural, other{{imageCost}개}}씩 써요.",
  "@creditCostLine": {
    "description": "AI 크레딧 단가 안내. textCost 는 일과 글 단가, imageCost 는 카드 그림 한 장 단가(서버 값)",
    "placeholders": { "textCost": { "type": "int" }, "imageCost": { "type": "int" } }
  },

  "creditCostKeepGoing": "크레딧이 남아 있을 때 시작한 일과는 그림이 많아도 끝까지 만들어져요.",
  "@creditCostKeepGoing": { "description": "AI 크레딧 안내 팝업의 둘째 문장" },

  "creditWeeklyRefill": "매주 월요일 0시에 다시 채워져요.",
  "@creditWeeklyRefill": { "description": "AI 크레딧 안내 팝업의 셋째 문장" },

  "todayRoutineCopied": "{title}을(를) 오늘 일과에 담았어요",
  "@todayRoutineCopied": {
    "description": "지난 일과를 오늘 일과로 복제한 뒤의 알림. title 은 일과 제목(조사는 받침을 모르므로 을(를) 로 쓴다)",
    "placeholders": { "title": { "type": "String" } }
  },

  "homeCoachCreate": "이룸이가 수행할 *새로운\n일과를 만들 수 있어요*",
  "@homeCoachCreate": { "description": "홈 코치마크 1단계. *로 감싼 부분이 강조된다" },
  "homeCoachSwipe": "일과를 *왼쪽으로 스와이프*하면\n*수정하거나 삭제*할 수 있어요",
  "@homeCoachSwipe": { "description": "홈 코치마크 2단계. *로 감싼 부분이 강조된다" },
  "homeCoachSwitch": "캐릭터 아이콘을 누르면\n*이룸이모드로 바꿀 수 있어요*",
  "@homeCoachSwitch": { "description": "홈 코치마크 3단계. *로 감싼 부분이 강조된다" },

  "cardMoveForward": "앞으로 옮기기",
  "@cardMoveForward": { "description": "카드 순서 바꾸기에서 낭독기 사용자가 쓰는 동작 이름" },
  "cardMoveBackward": "뒤로 옮기기",
  "@cardMoveBackward": { "description": "카드 순서 바꾸기에서 낭독기 사용자가 쓰는 동작 이름" },
```

원본이 문자열 두 개를 이어 쓴 곳(`ai_credit_summary_view.dart:148-149` 의 `'…때 ${…}개, ' '그림이 완성된…'`)은 감사기가 두 리터럴의 경계를 가로지르는 조각 `, 그림이 완성된 카드 1장마다` 를 못 찾는다. 눈으로 원본과 같음을 확인한 뒤 `client/tool/l10n_ko_audit_accepted.txt` 에 그 조각을 한 줄 더한다.

```text
, 그림이 완성된 카드 1장마다
```

`client/lib/features/guardian/presentation/widgets/ai_credit_summary_view.dart:37,49,86,144-151` — 정적 `title`·`message` 는 다른 파일이 참조하므로 정적 getter/함수로(규칙 4). `build` 안의 줄은 `context.l10n` 이다.

```dart
  static String get title => appL10n.creditCostTitle;

  /// 서버 단가로 적는다 — 운영에서 단가를 바꾸면 문구도 따라간다.
  static String message(CreditSummary s) => [
    appL10n.creditCostLine(s.routineTextCost, s.cardImageCost),
    appL10n.creditCostKeepGoing,
    appL10n.creditWeeklyRefill,
  ].join('\n');
```
```dart
    final amount = context.l10n.creditAmountLeft(s.available, s.weeklyGrant);
    // …
    final reset = context.l10n.aiCreditResetLine(s.resetLabel);
```
86행은 `text: context.l10n.creditAmountRest(s.weeklyGrant)`.

`client/lib/features/guardian/presentation/widgets/home_coach_mark.dart:54,69,92` — `_stepFor(step, context)` 가 이미 `context` 를 받는다.

```dart
          message: context.l10n.homeCoachCreate,
```
(`homeCoachSwipe`·`homeCoachSwitch` 도 같다.)

`client/lib/features/guardian/presentation/widgets/card_review_reorder_list.dart:508-515` — 낭독 동작 키는 `const` 가 아니게 된다.

```dart
      final l10n = context.l10n;
      child = Semantics(
        customSemanticsActions: {
          if (index > 0)
            CustomSemanticsAction(label: l10n.cardMoveForward): () => _nudge(index, -1),
          if (index < widget.cards.length - 1)
            CustomSemanticsAction(label: l10n.cardMoveBackward): () => _nudge(index, 1),
        },
        child: child,
      );
```

`client/lib/features/guardian/presentation/widgets/today_routine_section.dart:389` — `await` 뒤이므로 함수 앞에서 문구를 잡아 둔 `l10n` 을 쓴다(규칙 3).

```dart
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.todayRoutineCopied(copy.value!.displayTitle))),
    );
```

`client/lib/features/guardian/presentation/widgets/card_review_parts.dart:29` — `Text(context.l10n.cardReviewMade(count))`.

- [ ] **Step 4: 나머지 문구를 규칙대로 옮긴다**

**변환 규칙** (아래 대상 파일 전부에 같다. 한국어 문구는 한 글자도 바꾸지 않는다 — 감사기가 잡는다)

1. **위젯 안의 문구**: `Text('확인')` → `Text(context.l10n.commonConfirm)`. 키는 `app_ko.arb` 에 `"키": "확인"` 과 `"@키": { "description": "어디에 쓰이는 문구인지" }` 로 더한다. 같은 문구가 이미 있으면(`commonConfirm`·`commonCancel`·`commonClose`·`commonNext`·`commonRetry` 등) 키를 재사용한다. `const` 에 걸리면 가장 가까운 바깥 `const` 를 뗀다(analyze 가 위치를 알려준다). 파일 맨 위에 `core/l10n/l10n_context.dart`(`context.l10n`)·`core/l10n/current_l10n.dart`(`appL10n`) import 를 더한다.
2. **보간**: `'$name의 하루'` → ARB `"{name}의 하루"` 와 `"@키": { "placeholders": { "name": { "type": "String" } } }` → `context.l10n.키(name)`. 숫자는 `"type": "int"`.
3. **`String` 인자로 넘기는 문구**(`showFailure(title:, fallback:)`·`ElumDialogAction(label:)`): 호출 지점에서 `context.l10n` 으로 넘긴다. `await` 뒤에서 `context` 를 쓰면 `use_build_context_synchronously` 가 걸리므로 함수 맨 앞에서 `final l10n = context.l10n;` 로 잡아 둔다.
4. **상수·기본값**: 생성자 기본값(`this.label = '…'`)은 `String? label` 로 바꾸고 `build` 에서 `label ?? context.l10n.키` 로 푼다. `static const` 문구는, 다른 파일·테스트가 참조하면 `static String get` 으로 바꿔 `appL10n.키` 를 돌려주고(API 이름 유지), 같은 파일 안에서만 쓰면 `build` 에서 푼다. 상수를 `const` 로 참조하던 테스트는 한글 리터럴로 바꾼다.
5. **`context` 가 없는 층**(도메인 getter·enum 라벨·저장소 대체 문구): getter API 를 그대로 두고 값만 `appL10n.키` 로 돌려준다. 이런 getter 는 `context.l10n` 을 읽는 위젯의 `build` 안에서만 부른다(언어가 바뀔 때 같이 다시 그려진다).
6. **조사**: `'$name${name.objectParticle} …'` → ARB `"{name}{batchim, select, yes{을} other{를}} …"`(`batchim` 도 `String` 자리표시자) → `context.l10n.키(name, batchimOf(name))`. 코드가 조사 글자를 붙이지 않는다. `import 'package:elum/core/l10n/batchim.dart';` (프로젝트 내부는 상대 경로).
7. **단위·복수**: `'$n개'` → `"{count, plural, other{{count}개}}"`(ko 는 `other` 하나. 영어 등은 번역 단계에서 `one` 을 더한다).
8. **날짜**: `core/l10n/date_labels.dart` 의 `yearMonthDay`·`monthDaySince`·`resetAt` 을 쓴다.
9. `\n`·`*강조*` 같은 표식은 문구 그대로 ARB 에 옮긴다(JSON 에서는 `\n`). 작은따옴표는 ICU 에서 `''` 로 쓴다.

위 표의 줄을 위에서 아래로 처리한다. 이 폴더의 키 접두어는 ``guardianHome` `card` `credit` `routine` `reward` `homeCoach`` 이다.

- [ ] **Step 5: 생성·분석·감사**

```bash
cd client && flutter gen-l10n && flutter analyze && dart run tool/l10n_ko_audit.dart --base 99b65ac0
```
Expected: `No issues found!`, `--- 조각 N개 중 기준 커밋에 없는 것 0개`.

- [ ] **Step 6: 검사기와 테스트**

```bash
cd client && dart run tool/check_hangul_literals.dart lib/features/guardian
cd client && flutter test test/l10n/ $(grep -rlE "package:elum/features/guardian/" test | sort)
git status --short client/test | grep -c png
```
Expected: 검사기 `0줄`(종료 0). 테스트 **PASS**. PNG 변경 `0`(골든·시안 PNG 는 `--update-goldens` 없이 그대로 통과해야 한다).

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add client/lib/features/guardian/presentation/widgets/create_routine_button.dart client/lib/features/guardian/presentation/widgets/default_card_art.dart client/lib/features/guardian/presentation/widgets/action_card_view.dart client/lib/features/guardian/presentation/widgets/routine_swipe_actions.dart client/lib/features/guardian/presentation/widgets/recommended_routine_strip.dart client/lib/features/guardian/presentation/widgets/card_photo_permission_screen.dart client/lib/features/guardian/presentation/widgets/card_review_parts.dart client/lib/features/guardian/presentation/widgets/routine_flow_scaffold.dart client/lib/features/guardian/presentation/widgets/routine_summary_tile.dart client/lib/features/guardian/presentation/widgets/card_photo_source_sheet.dart client/lib/features/guardian/presentation/widgets/card_photo_block.dart client/lib/features/guardian/presentation/widgets/step_card_viewer.dart client/lib/features/guardian/presentation/widgets/ai_credit_card.dart client/lib/features/guardian/presentation/widgets/card_edit_sheet.dart client/lib/features/guardian/presentation/widgets/routine_detail_sheet.dart client/lib/features/guardian/presentation/widgets/card_review_reorder_list.dart client/lib/features/guardian/presentation/widgets/today_routine_section.dart client/lib/features/guardian/presentation/widgets/reward_chip.dart client/lib/features/guardian/presentation/widgets/ai_credit_summary_view.dart client/lib/features/guardian/presentation/widgets/home_coach_mark.dart  client/lib/l10n client/test/l10n/guardian_widgets_messages_ko_test.dart client/tool/l10n_ko_audit_accepted.txt
```

## Task 23: child — 이룸이 홈·카드 상세·별·보상·모드 전환

**Files:**
- Modify: 아래 표의 8개 파일, `client/lib/l10n/app_ko.arb`(+ 생성물)
- Test: `client/test/l10n/child_messages_ko_test.dart`

**Interfaces:**
- Consumes: `context.l10n`·`appL10n` (Task 3), `batchimOf` (Task 11), `commonElumiName` (Task 15)
- Produces: ARB 키 `childHomeGreeting(name, batchim)` `childHomeEmptyTitle(name)` `childHomeEmptyHint` `childHomeEmptyHintDevice` `childStarsEarned(count)` `childStarsSemantics(count)` `childCardPagerLabel(total, index)` `rewardLumiTitle` `rewardLumiMessage(name)` `rewardLumiButton` `rewardPopoTitle` `rewardPopoMessage(name)` `rewardPopoButton` `rewardRuruTitle` `rewardRuruMessage(name, batchim)` `rewardRuruButton` `modeSwitchToChild` `modeSwitchToGuardian` … `RewardCharacter.title`·`buttonLabel`·`messageFor(childName)`, `ModeSwitchTarget.description` 의 **API 는 그대로**다.

이 Task 가 끝나면 lib 의 `KoreanParticle` 호출이 0곳이 된다(Task 26 에서 `grep` 으로 확인).

대상:

| 파일 | 줄 수 | 줄 |
| --- | ---: | --- |
| `client/lib/features/child/domain/reward_character.dart` | 10 | 20-22, 27-29, 34-36, 58 |
| `client/lib/features/child/presentation/routine_done_screen.dart` | 2 | 66, 96 |
| `client/lib/features/child/presentation/child_stars_screen.dart` | 1 | 119 |
| `client/lib/features/child/presentation/child_routine_detail_screen.dart` | 3 | 131-132, 456 |
| `client/lib/features/child/presentation/child_home_screen.dart` | 7 | 118, 185, 215, 233, 379, 472, 478 |
| `client/lib/features/child/presentation/mode_switch_screen.dart` | 10 | 69-70, 163, 181, 183-184, 197, 208, 237-238 |
| `client/lib/features/child/presentation/widgets/child_card_pager.dart` | 1 | 115 |
| `client/lib/features/child/presentation/widgets/reward_banner.dart` | 1 | 77 |
| **합계 8개 파일** | **35** | |

- [ ] **Step 1: 기준선을 센다**

Run: `cd client && dart run tool/check_hangul_literals.dart lib/features/child | tail -1`
Expected: `--- 사용자 노출 한글 리터럴 35줄`(종료 코드 1)

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`client/test/l10n/child_messages_ko_test.dart`

```dart
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/features/child/domain/reward_character.dart';
import 'package:elum/features/child/presentation/mode_switch_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  test('이룸이 홈 인사말 — 받침에 따라 이/가', () {
    expect(ko.childHomeGreeting('민준', 'yes'), '오늘 민준이\n할 일들이에요. 힘내봐요!');
    expect(ko.childHomeGreeting('루미', 'no'), '오늘 루미가\n할 일들이에요. 힘내봐요!');
    expect(ko.childHomeEmptyTitle('하늘'), '아직 하늘의\n일과가 없어요');
    expect(ko.childHomeEmptyHint, '보호자 화면에서 일과를 만들 수 있어요');
    expect(ko.childHomeEmptyHintDevice, '보호자 모드에서 일과를 만들 수 있어요');
  });

  test('별 화면의 개수 문구', () {
    expect(ko.childStarsEarned(7), '7개의 별을 얻었어요\n할 일을 해내고 별을 더 찾아봐요!');
    expect(ko.childStarsSemantics(7), '별 7개 모았어요');
  });

  test('카드 페이저 낭독 문구', () {
    expect(ko.childCardPagerLabel(5, 2), '카드 5장 중 2번째');
  });

  test('보상 화면 — 캐릭터마다 제목·문구·버튼이 다르다', () {
    expect(RewardCharacter.lumi.title, '축하해요!');
    expect(RewardCharacter.lumi.buttonLabel, '오예!');
    expect(RewardCharacter.lumi.messageFor('하늘'), '할 일을 해내서 루미가\n하늘에게 별을 가져왔어요');
    expect(RewardCharacter.popo.title, '잘했어요!');
    expect(RewardCharacter.popo.buttonLabel, '좋아요!');
    expect(RewardCharacter.popo.messageFor('하늘'), '포포가 하늘에게\n축하의 선물로 큰 별을 가져왔어요');
    expect(RewardCharacter.ruru.title, '멋져요!');
    expect(RewardCharacter.ruru.buttonLabel, '신난다!');
    // 조사는 받침에 따라 — 루루만 이름이 주어로 나온다
    expect(RewardCharacter.ruru.messageFor('민준'), '민준이 할 일을 해내서\n루루가 선물을 가져왔다고 해요');
    expect(RewardCharacter.ruru.messageFor('루미'), '루미가 할 일을 해내서\n루루가 선물을 가져왔다고 해요');
  });

  test('이름이 비면 이룸이로 대신한다', () {
    expect(RewardCharacter.ruru.messageFor('  '), '이룸이가 할 일을 해내서\n루루가 선물을 가져왔다고 해요');
  });

  test('모드 전환 안내', () {
    expect(ModeSwitchTarget.child.description, '암호를 입력하면 이룸이 화면으로 바뀌어요');
    expect(ModeSwitchTarget.guardian.description, '암호를 입력하면 보호자 화면으로 바뀌어요');
  });
}
```

Run: `cd client && flutter test test/l10n/child_messages_ko_test.dart`
Expected: **FAIL** — 키가 없다.

- [ ] **Step 3: 특수 문구와 구조를 바꾼다**

`client/lib/l10n/app_ko.arb` 에 더한다.

```json
  "childHomeGreeting": "오늘 {name}{batchim, select, yes{이} other{가}}\n할 일들이에요. 힘내봐요!",
  "@childHomeGreeting": {
    "description": "이룸이 홈 인사말(시안 문구, 줄바꿈 위치 유지). name 은 이룸이 호칭. batchim 은 한국어 조사 선택용(yes/no)이라 다른 언어는 쓰지 않는다",
    "placeholders": { "name": { "type": "String" }, "batchim": { "type": "String" } }
  },

  "childHomeEmptyTitle": "아직 {name}의\n일과가 없어요",
  "@childHomeEmptyTitle": {
    "description": "이룸이 홈에 일과가 하나도 없을 때의 제목. name 은 이룸이 호칭",
    "placeholders": { "name": { "type": "String" } }
  },

  "childHomeEmptyHint": "보호자 화면에서 일과를 만들 수 있어요",
  "@childHomeEmptyHint": { "description": "일과가 없을 때의 안내(보호자 폰에서 보는 이룸이 화면)" },
  "childHomeEmptyHintDevice": "보호자 모드에서 일과를 만들 수 있어요",
  "@childHomeEmptyHintDevice": { "description": "일과가 없을 때의 안내(이룸이 전용 휴대폰)" },

  "childStarsEarned": "{count, plural, other{{count}개의 별을 얻었어요\n할 일을 해내고 별을 더 찾아봐요!}}",
  "@childStarsEarned": {
    "description": "별 화면 문구. count 는 모은 별 수",
    "placeholders": { "count": { "type": "int" } }
  },

  "childStarsSemantics": "{count, plural, other{별 {count}개 모았어요}}",
  "@childStarsSemantics": {
    "description": "이룸이 홈 별 표시를 낭독기가 읽는 문장. count 는 모은 별 수",
    "placeholders": { "count": { "type": "int" } }
  },

  "childCardPagerLabel": "카드 {total}장 중 {index}번째",
  "@childCardPagerLabel": {
    "description": "카드 넘기기 영역을 낭독기가 읽는 문장. total 은 전체 장수, index 는 지금 몇 번째(1부터)",
    "placeholders": { "total": { "type": "int" }, "index": { "type": "int" } }
  },

  "rewardLumiTitle": "축하해요!",
  "@rewardLumiTitle": { "description": "보상 화면(루미) 큰 제목" },
  "rewardLumiMessage": "할 일을 해내서 루미가\n{name}에게 별을 가져왔어요",
  "@rewardLumiMessage": {
    "description": "보상 화면(루미) 두 줄 설명. name 은 이룸이 호칭",
    "placeholders": { "name": { "type": "String" } }
  },
  "rewardLumiButton": "오예!",
  "@rewardLumiButton": { "description": "보상 화면(루미) 하단 버튼" },

  "rewardPopoTitle": "잘했어요!",
  "@rewardPopoTitle": { "description": "보상 화면(포포) 큰 제목" },
  "rewardPopoMessage": "포포가 {name}에게\n축하의 선물로 큰 별을 가져왔어요",
  "@rewardPopoMessage": {
    "description": "보상 화면(포포) 두 줄 설명. name 은 이룸이 호칭",
    "placeholders": { "name": { "type": "String" } }
  },
  "rewardPopoButton": "좋아요!",
  "@rewardPopoButton": { "description": "보상 화면(포포) 하단 버튼" },

  "rewardRuruTitle": "멋져요!",
  "@rewardRuruTitle": { "description": "보상 화면(루루) 큰 제목. 루루만 별이 아니라 선물을 가져온다" },
  "rewardRuruMessage": "{name}{batchim, select, yes{이} other{가}} 할 일을 해내서\n루루가 선물을 가져왔다고 해요",
  "@rewardRuruMessage": {
    "description": "보상 화면(루루) 두 줄 설명. name 은 이룸이 호칭. batchim 은 한국어 조사 선택용(yes/no)이라 다른 언어는 쓰지 않는다",
    "placeholders": { "name": { "type": "String" }, "batchim": { "type": "String" } }
  },
  "rewardRuruButton": "신난다!",
  "@rewardRuruButton": { "description": "보상 화면(루루) 하단 버튼" },

  "modeSwitchToChild": "암호를 입력하면 이룸이 화면으로 바뀌어요",
  "@modeSwitchToChild": { "description": "보호자 → 이룸이 화면 전환의 암호 안내" },
  "modeSwitchToGuardian": "암호를 입력하면 보호자 화면으로 바뀌어요",
  "@modeSwitchToGuardian": { "description": "이룸이 → 보호자 화면 전환의 암호 안내" },
```

`client/lib/features/child/domain/reward_character.dart` — 문구 템플릿(`{name}`·`{josa}` 치환)을 없애고 ARB 를 부른다. `korean_particle.dart` import 를 `batchim.dart`·`current_l10n.dart` 로 바꾼다.

```dart
import 'dart:math';

import '../../../core/l10n/batchim.dart';
import '../../../core/l10n/current_l10n.dart';

enum RewardCharacter {
  /// 서비스 AI이자 병아리. 온보딩 선택지에는 없다.
  lumi,

  /// 여우
  popo,

  /// 고양이
  ruru;

  /// 큰 제목 (30/w800)
  String get title => switch (this) {
    RewardCharacter.lumi => appL10n.rewardLumiTitle,
    RewardCharacter.popo => appL10n.rewardPopoTitle,
    RewardCharacter.ruru => appL10n.rewardRuruTitle,
  };

  /// 하단 버튼 문구 (22/w800). 루미·포포는 `오예!`·`좋아요!`, 루루는 `신난다!` (Figma 343:4434).
  String get buttonLabel => switch (this) {
    RewardCharacter.lumi => appL10n.rewardLumiButton,
    RewardCharacter.popo => appL10n.rewardPopoButton,
    RewardCharacter.ruru => appL10n.rewardRuruButton,
  };

  /// 이룸이 이름을 넣은 설명 문구.
  ///
  /// 이름이 비면 조사만 남아 어색해지므로 대체어를 쓴다
  /// (`가 할 일을 해내서` → `이룸이가 할 일을 해내서`).
  /// 한국어 조사는 받침에 따라 갈린다 — 판정값만 넘기고 글자는 문구가 정한다.
  String messageFor(String childName) {
    final name = childName.trim().isEmpty
        ? appL10n.commonElumiName
        : childName.trim();
    return switch (this) {
      RewardCharacter.lumi => appL10n.rewardLumiMessage(name),
      RewardCharacter.popo => appL10n.rewardPopoMessage(name),
      RewardCharacter.ruru => appL10n.rewardRuruMessage(name, batchimOf(name)),
    };
  }

  /// 무작위로 하나 고른다. [random]을 받는 이유는 테스트에서 결과를 고정하기 위함이다.
  static RewardCharacter pick([Random? random]) {
    final r = random ?? Random();
    return values[r.nextInt(values.length)];
  }
}
```
(Figma 노드 주석·캐릭터 설명 주석은 원본 그대로 옮긴다.)

`client/lib/features/child/presentation/mode_switch_screen.dart:231-247`(`ModeSwitchTarget`) — 생성자의 한글 인자를 빼고 getter 로.

```dart
enum ModeSwitchTarget {
  // 시안(`309:2837`)은 `암호를 입력하면 보호자 화면으로 전환돼요`다. `입력하면`은 시안을 따르고,
  // 끝은 **능동형**으로 둔다 — 피동형(`전환돼요`)은 루트 CLAUDE.md 말투 규칙이 금지한다.
  child(Routes.child),
  guardian(Routes.guardian);

  const ModeSwitchTarget(this.route);

  final String route;

  /// 암호 안내 문구 — 앱 언어의 문구다.
  String get description => switch (this) {
    ModeSwitchTarget.child => appL10n.modeSwitchToChild,
    ModeSwitchTarget.guardian => appL10n.modeSwitchToGuardian,
  };
  // …(fromName 은 그대로)…
```

`client/lib/features/child/presentation/child_home_screen.dart:118,185,472,478`, `child_stars_screen.dart:119`, `widgets/child_card_pager.dart:115`

```dart
// child_home_screen.dart:118
                          context.l10n.childHomeGreeting(childName, batchimOf(childName)),
// child_home_screen.dart:185
    semanticLabel: context.l10n.childStarsSemantics(stars),
// child_home_screen.dart:472
            context.l10n.childHomeEmptyTitle(childName),
// child_home_screen.dart:478
            isElumiDevice ? context.l10n.childHomeEmptyHintDevice : context.l10n.childHomeEmptyHint,
// child_stars_screen.dart:119
                context.l10n.childStarsEarned(stars),
// child_card_pager.dart:115
      label: context.l10n.childCardPagerLabel(cards.length, currentIndex + 1),
```
(`child_home_screen.dart` 는 `import '../../../core/l10n/batchim.dart';` 와 `l10n_context.dart` 를 더한다.)

- [ ] **Step 4: 나머지 문구를 규칙대로 옮긴다**

**변환 규칙** (아래 대상 파일 전부에 같다. 한국어 문구는 한 글자도 바꾸지 않는다 — 감사기가 잡는다)

1. **위젯 안의 문구**: `Text('확인')` → `Text(context.l10n.commonConfirm)`. 키는 `app_ko.arb` 에 `"키": "확인"` 과 `"@키": { "description": "어디에 쓰이는 문구인지" }` 로 더한다. 같은 문구가 이미 있으면(`commonConfirm`·`commonCancel`·`commonClose`·`commonNext`·`commonRetry` 등) 키를 재사용한다. `const` 에 걸리면 가장 가까운 바깥 `const` 를 뗀다(analyze 가 위치를 알려준다). 파일 맨 위에 `core/l10n/l10n_context.dart`(`context.l10n`)·`core/l10n/current_l10n.dart`(`appL10n`) import 를 더한다.
2. **보간**: `'$name의 하루'` → ARB `"{name}의 하루"` 와 `"@키": { "placeholders": { "name": { "type": "String" } } }` → `context.l10n.키(name)`. 숫자는 `"type": "int"`.
3. **`String` 인자로 넘기는 문구**(`showFailure(title:, fallback:)`·`ElumDialogAction(label:)`): 호출 지점에서 `context.l10n` 으로 넘긴다. `await` 뒤에서 `context` 를 쓰면 `use_build_context_synchronously` 가 걸리므로 함수 맨 앞에서 `final l10n = context.l10n;` 로 잡아 둔다.
4. **상수·기본값**: 생성자 기본값(`this.label = '…'`)은 `String? label` 로 바꾸고 `build` 에서 `label ?? context.l10n.키` 로 푼다. `static const` 문구는, 다른 파일·테스트가 참조하면 `static String get` 으로 바꿔 `appL10n.키` 를 돌려주고(API 이름 유지), 같은 파일 안에서만 쓰면 `build` 에서 푼다. 상수를 `const` 로 참조하던 테스트는 한글 리터럴로 바꾼다.
5. **`context` 가 없는 층**(도메인 getter·enum 라벨·저장소 대체 문구): getter API 를 그대로 두고 값만 `appL10n.키` 로 돌려준다. 이런 getter 는 `context.l10n` 을 읽는 위젯의 `build` 안에서만 부른다(언어가 바뀔 때 같이 다시 그려진다).
6. **조사**: `'$name${name.objectParticle} …'` → ARB `"{name}{batchim, select, yes{을} other{를}} …"`(`batchim` 도 `String` 자리표시자) → `context.l10n.키(name, batchimOf(name))`. 코드가 조사 글자를 붙이지 않는다. `import 'package:elum/core/l10n/batchim.dart';` (프로젝트 내부는 상대 경로).
7. **단위·복수**: `'$n개'` → `"{count, plural, other{{count}개}}"`(ko 는 `other` 하나. 영어 등은 번역 단계에서 `one` 을 더한다).
8. **날짜**: `core/l10n/date_labels.dart` 의 `yearMonthDay`·`monthDaySince`·`resetAt` 을 쓴다.
9. `\n`·`*강조*` 같은 표식은 문구 그대로 ARB 에 옮긴다(JSON 에서는 `\n`). 작은따옴표는 ICU 에서 `''` 로 쓴다.

위 표의 줄을 위에서 아래로 처리한다. 이 폴더의 키 접두어는 ``child` `reward` `modeSwitch`` 이다.

- [ ] **Step 5: 생성·분석·감사**

```bash
cd client && flutter gen-l10n && flutter analyze && dart run tool/l10n_ko_audit.dart --base 99b65ac0
```
Expected: `No issues found!`, `--- 조각 N개 중 기준 커밋에 없는 것 0개`.

- [ ] **Step 6: 검사기와 테스트**

```bash
cd client && dart run tool/check_hangul_literals.dart lib/features/child
cd client && flutter test test/l10n/ $(grep -rlE "package:elum/features/child/" test | sort)
git status --short client/test | grep -c png
```
Expected: 검사기 `0줄`(종료 0). 테스트 **PASS**. PNG 변경 `0`(골든·시안 PNG 는 `--update-goldens` 없이 그대로 통과해야 한다).

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add client/lib/features/child/domain/reward_character.dart client/lib/features/child/presentation/routine_done_screen.dart client/lib/features/child/presentation/child_stars_screen.dart client/lib/features/child/presentation/child_routine_detail_screen.dart client/lib/features/child/presentation/child_home_screen.dart client/lib/features/child/presentation/mode_switch_screen.dart client/lib/features/child/presentation/widgets/child_card_pager.dart client/lib/features/child/presentation/widgets/reward_banner.dart  client/lib/l10n client/test/l10n/child_messages_ko_test.dart
```

---

# 3단계 — 일과 언어와 마무리 (Task 24~26)

## Task 24: 일과 언어 — 카드 글·음성이 일과의 `language` 를 따른다

**Files:**
- Create: `client/lib/core/l10n/content_locale.dart`
- Modify: `client/lib/shared/models/routine.dart` — 필드(76행 `creatorName` 아래), `toJson`(157~171행), `fromJson`(173~201행). 재생성: `client/lib/shared/models/routine.freezed.dart`
- Modify: `client/lib/features/child/data/speech_service.dart` — 인터페이스(15행), `DeviceSpeech`(27~66행), `RemoteSpeech.speak`(99행), `FallbackSpeech.speak`(158~163행)
- Modify: `client/lib/features/guardian/presentation/widgets/action_card_view.dart` — 생성자(26~36행)와 `build` 의 반환 위젯
- Modify(`language` 를 넘기는 곳): `client/lib/features/child/presentation/widgets/child_card_pager.dart`(생성자·`ActionCardView` 호출 194행), `client/lib/features/child/presentation/child_routine_detail_screen.dart`(`ChildCardPager` 호출 312행, `_speak` 118행), `client/lib/features/guardian/presentation/card_review_screen.dart`(`ActionCardView` 호출 379행, `_speak` 143행), `client/lib/features/guardian/presentation/widgets/card_review_reorder_list.dart`(생성자, `ActionCardView` 호출 538·581행), `client/lib/features/guardian/presentation/widgets/step_card_viewer.dart`(생성자·`show`·`ActionCardView` 호출 144행·`_speak` 108행), `client/lib/features/guardian/presentation/widgets/routine_detail_sheet.dart`(`StepCardViewer.show` 호출 231행)
- Modify(테스트 대역 7곳의 `speak` 시그니처): `client/test/card_review_badge_test.dart:147`, `client/test/card_review_redesign_test.dart:1354`, `client/test/child_card_peek_test.dart:555`, `client/test/card_review_delete_confirm_test.dart:150`, `client/test/step_card_viewer_test.dart:202`, `client/test/speech_service_test.dart:110`, `client/test/photo/card_edit_sheet_photo_test.dart:329`
- Test: `client/test/l10n/routine_language_test.dart`, `client/test/l10n/content_locale_test.dart`, `client/test/l10n/speech_language_test.dart`, `client/test/l10n/content_language_flow_test.dart`

**Interfaces:**
- Consumes: 서버 `RoutineResponse.language`(`"ko"` 같은 코드 문자열, 마스터 C5 — 계획 2 가 내려준다. 없으면 `ko`)
- Produces:
  - `Routine.language` (`@Default('ko') String`), `toJson`·`fromJson` 에 `language`
  - `String normalizeContentLanguage(Object? value)` — 다섯 코드 밖이면 `'ko'`; `Locale contentLocaleOf(String? language)`; `class ContentLocale extends StatelessWidget { const ContentLocale({super.key, required String? language, required Widget child}); }`
  - `Future<bool> SpeechService.speak(String text, {String language = 'ko'})` — **하위 계획 3 이 이 인자를 받아 기기 음성 대체·서버 음성 언어를 마무리한다.** 이 계획은 `DeviceSpeech` 가 기기 TTS 언어를 일과 언어로 맞추는 것까지다. `RemoteSpeech` 는 아직 `language` 를 무시한다(서버 음성은 한국어 `F1` 고정).

**왜 일과가 언어를 들고 있는가(스펙 4.2).** 이룸이 휴대폰은 버튼·메뉴를 **자기 OS 언어**로, 카드 글과 음성을 **일과 언어**로 보여준다. 일과를 만든 보호자 휴대폰의 언어가 곧 일과 언어라서 두 휴대폰의 언어가 다를 수 있다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`client/test/l10n/routine_language_test.dart`

```dart
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_test/flutter_test.dart';

/// 일과의 언어(마스터 C5): 서버 `RoutineResponse.language`. 없으면 `ko`.
void main() {
  test('필드가 없는 옛 응답은 ko 다 — 기존 일과가 전부 한국어 일과다', () {
    expect(Routine.fromJson({'id': 'r1'}).language, 'ko');
    expect(const Routine(id: 'r1').language, 'ko');
  });

  test('서버가 준 언어 코드를 읽는다', () {
    for (final code in ['ko', 'en', 'ja', 'zh', 'es']) {
      expect(Routine.fromJson({'id': 'r1', 'language': code}).language, code);
    }
  });

  test('모르는 값·깨진 값은 ko 다 — 화면이 죽지 않는다', () {
    expect(Routine.fromJson({'id': 'r1', 'language': 'fr'}).language, 'ko');
    expect(Routine.fromJson({'id': 'r1', 'language': 'zh-Hans'}).language, 'ko');
    expect(Routine.fromJson({'id': 'r1', 'language': 7}).language, 'ko');
    expect(Routine.fromJson({'id': 'r1', 'language': null}).language, 'ko');
  });

  test('오프라인 캐시 왕복에서 언어가 남는다', () {
    final restored = Routine.fromJson(
      const Routine(id: 'r1', language: 'ja').toJson(),
    );
    expect(restored.language, 'ja');
  });
}
```

`client/test/l10n/content_locale_test.dart`

```dart
import 'package:elum/core/l10n/content_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_with_locale.dart';

void main() {
  group('normalizeContentLanguage', () {
    test('다섯 코드만 통과하고 나머지는 ko', () {
      for (final code in ['ko', 'en', 'ja', 'zh', 'es']) {
        expect(normalizeContentLanguage(code), code);
      }
      expect(normalizeContentLanguage('fr'), 'ko');
      expect(normalizeContentLanguage(''), 'ko');
      expect(normalizeContentLanguage(null), 'ko');
      expect(normalizeContentLanguage(3), 'ko');
    });
  });

  group('contentLocaleOf', () {
    test('코드를 Locale 로 — 중국어는 간체', () {
      expect(contentLocaleOf('ja'), const Locale('ja'));
      expect(
        contentLocaleOf('zh'),
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      );
      expect(contentLocaleOf(null), const Locale('ko'));
      expect(contentLocaleOf('fr'), const Locale('ko'));
    });
  });

  group('ContentLocale', () {
    testWidgets('아래 글자의 언어를 일과 언어로 싣는다 — 화면 언어와 달라도', (tester) async {
      // 화면 언어는 es, 일과 언어는 ja
      await pumpWithLocale(
        tester,
        const Scaffold(
          body: ContentLocale(language: 'ja', child: Text('こんにちは')),
        ),
        locale: const Locale('es'),
      );

      final style = DefaultTextStyle.of(tester.element(find.text('こんにちは'))).style;
      expect(style.locale, const Locale('ja'));
    });

    testWidgets('모르는 값이면 ko', (tester) async {
      await pumpWithLocale(
        tester,
        const Scaffold(body: ContentLocale(language: null, child: Text('가'))),
      );

      final style = DefaultTextStyle.of(tester.element(find.text('가'))).style;
      expect(style.locale, const Locale('ko'));
    });
  });
}
```

`client/test/l10n/speech_language_test.dart`

```dart
import 'package:elum/features/child/data/speech_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_test/flutter_test.dart';

/// 음성도 일과 언어를 따른다 (Review Focus). 기기 TTS 언어를 일과 언어로 맞춘다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ttsLocaleOf', () {
    test('일과 언어 → 기기 TTS 언어 태그', () {
      expect(ttsLocaleOf('ko'), 'ko-KR');
      expect(ttsLocaleOf('en'), 'en-US');
      expect(ttsLocaleOf('ja'), 'ja-JP');
      expect(ttsLocaleOf('zh'), 'zh-CN');
      expect(ttsLocaleOf('es'), 'es-ES');
      expect(ttsLocaleOf('fr'), 'ko-KR');
    });
  });

  group('DeviceSpeech', () {
    test('기본은 한국어 — 기존 동작', () async {
      final tts = _FakeTts();
      expect(await DeviceSpeech(tts: tts).speak('옷을 입어요'), isTrue);
      expect(tts.languages, ['ko-KR']);
      expect(tts.spoken, ['옷을 입어요']);
    });

    test('일과 언어로 기기 음성을 맞춘다', () async {
      final tts = _FakeTts();
      final speech = DeviceSpeech(tts: tts);

      await speech.speak('服を着ます', language: 'ja');

      expect(tts.languages, ['ja-JP']);
    });

    test('언어가 바뀐 때만 다시 맞춘다', () async {
      final tts = _FakeTts();
      final speech = DeviceSpeech(tts: tts);

      await speech.speak('a', language: 'en');
      await speech.speak('b', language: 'en');
      await speech.speak('c', language: 'es');

      expect(tts.languages, ['en-US', 'es-ES']);
      expect(tts.rateCalls, 1, reason: '속도는 한 번만 맞춘다');
    });
  });

  group('FallbackSpeech', () {
    test('언어를 기기·서버 양쪽에 그대로 넘긴다', () async {
      final device = _LangSpeech(succeeds: false);
      final remote = _LangSpeech(succeeds: true);

      await FallbackSpeech(device: device, remote: remote).speak('x', language: 'ja');

      expect(device.languages, ['ja']);
      expect(remote.languages, ['ja']);
    });
  });
}

class _FakeTts extends FlutterTts {
  final languages = <String>[];
  final spoken = <String>[];
  var rateCalls = 0;

  @override
  Future<dynamic> setLanguage(String language) async {
    languages.add(language);
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    rateCalls++;
    return 1;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spoken.add(text);
    return 1;
  }

  @override
  Future<dynamic> stop() async => 1;
}

class _LangSpeech implements SpeechService {
  _LangSpeech({required this.succeeds});

  final bool succeeds;
  final languages = <String>[];

  @override
  Future<bool> speak(String text, {String language = 'ko'}) async {
    languages.add(language);
    return succeeds;
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
```

`client/test/l10n/content_language_flow_test.dart` — 이룸이 휴대폰의 화면 언어(`en`)와 일과 언어(`ja`)가 달라도 카드 글·음성이 일과 언어를 따른다.

```dart
import 'package:elum/core/l10n/app_l10n.dart';
import 'package:elum/core/l10n/content_locale.dart';
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/child/presentation/child_routine_detail_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/action_card_view.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/device_viewport.dart';
import '../helpers/fake_dio.dart';
import '../helpers/test_storage.dart';

/// 두 휴대폰의 언어가 다를 때: 버튼·메뉴는 **그 휴대폰의 화면 언어**, 카드 글과 음성은
/// **일과 언어**다 (스펙 4.2, Review Focus).
void main() {
  useFigmaViewport();

  const card = ActionCard(
    id: 'c1',
    title: '服を着ます',
    description: '学校に行く服を着ます',
    stepOrder: 1,
  );

  final spoken = <String>[];
  final languages = <String>[];

  Widget wrap({required String routineLanguage}) => ProviderScope(
    overrides: [
      offlineDioOverride(),
      testStorageOverride(onboardingCompleted: true),
      speechServiceProvider.overrideWithValue(_RecordingSpeech(spoken, languages)),
    ],
    child: ScreenUtilInit(
      designSize: const Size(393, 852),
      useInheritedMediaQuery: true,
      builder: (context, _) => MaterialApp.router(
        theme: AppTheme.light,
        // 이 휴대폰의 화면 언어는 영어다
        locale: const Locale('en'),
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: AppL10n.delegates,
        routerConfig: GoRouter(
          initialLocation: Routes.childRoutineDetail,
          routes: [
            GoRoute(
              path: Routes.childRoutineDetail,
              builder: (context, state) => ChildRoutineDetailScreen(
                routine: Routine(
                  id: 'local',
                  title: 'x',
                  status: 'CONFIRMED',
                  steps: const [card],
                  language: routineLanguage,
                ),
              ),
            ),
            GoRoute(
              path: Routes.childReward,
              builder: (context, state) => const Scaffold(body: Text('보상')),
            ),
          ],
        ),
      ),
    ),
  );

  setUp(() {
    spoken.clear();
    languages.clear();
  });

  testWidgets('화면 언어는 en, 카드 글은 일과 언어 ja 로 그려진다', (tester) async {
    await tester.pumpWidget(wrap(routineLanguage: 'ja'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // 화면 언어는 이 휴대폰의 것이다
    final screen = tester.element(find.byType(ChildRoutineDetailScreen));
    expect(screen.l10n.localeName, 'en');

    // 카드 글은 일과 언어다 — 한자 글리프·줄바꿈이 일과 언어를 따른다
    final style = DefaultTextStyle.of(
      tester.element(find.text('学校に行く服を着ます')),
    ).style;
    expect(style.locale, contentLocaleOf('ja'));
  });

  /// 카드의 스피커 버튼이 누르는 동작을 그대로 부른다. 낭독 문구(번역 대상)에 기대지 않는다.
  Future<void> tapSpeaker(WidgetTester tester) async {
    final view = tester.widget<ActionCardView>(find.byType(ActionCardView).first);
    view.onSpeak!();
    await tester.pump();
  }

  testWidgets('카드를 읽어 줄 때 일과 언어를 음성에 넘긴다', (tester) async {
    await tester.pumpWidget(wrap(routineLanguage: 'ja'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tapSpeaker(tester);

    expect(spoken, ['服を着ます. 学校に行く服を着ます']);
    expect(languages, ['ja'], reason: '화면 언어(en)가 아니라 일과 언어다');
  });

  testWidgets('일과에 언어가 없으면(옛 일과) ko 로 읽는다', (tester) async {
    await tester.pumpWidget(wrap(routineLanguage: 'ko'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tapSpeaker(tester);

    expect(languages, ['ko']);
  });
}

class _RecordingSpeech implements SpeechService {
  _RecordingSpeech(this.spoken, this.languages);

  final List<String> spoken;
  final List<String> languages;

  @override
  Future<bool> speak(String text, {String language = 'ko'}) async {
    spoken.add(text);
    languages.add(language);
    return true;
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
```

Run: `cd client && flutter test test/l10n/routine_language_test.dart test/l10n/content_locale_test.dart test/l10n/speech_language_test.dart test/l10n/content_language_flow_test.dart`
Expected: **FAIL** — `Routine.language`·`content_locale.dart`·`ttsLocaleOf`·`speak(language:)` 가 없다(컴파일 오류).

- [ ] **Step 2: `content_locale.dart` 를 만든다**

`client/lib/core/l10n/content_locale.dart`

```dart
import 'package:flutter/widgets.dart';

/// 일과 언어로 인정하는 코드 다섯 (마스터 C1·C5).
const _contentLanguages = {'ko', 'en', 'ja', 'zh', 'es'};

/// 서버가 준 일과 언어 값을 정리한다. **다섯 코드 밖이거나 깨진 값은 `ko`** 다 — 옛 일과·옛 서버 응답이
/// 전부 한국어 일과였고, 모르는 값 하나로 카드가 안 그려지면 안 된다.
String normalizeContentLanguage(Object? value) =>
    value is String && _contentLanguages.contains(value) ? value : 'ko';

/// 일과 언어 코드 → [Locale]. 모르는 값은 `ko`다.
Locale contentLocaleOf(String? language) => switch (language) {
  'en' => const Locale('en'),
  'ja' => const Locale('ja'),
  'zh' => const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  'es' => const Locale('es'),
  _ => const Locale('ko'),
};

/// 아래 글자를 일과 언어로 그린다.
///
/// 이룸이 휴대폰은 화면 문구를 **자기 OS 언어**로, 카드 글을 **일과 언어**로 보여준다 (스펙 4.2).
/// 두 언어가 다를 때 한자(일본어/중국어)의 글리프와 줄바꿈이 일과 언어를 따르도록 글자 스타일에
/// 언어를 싣는다.
///
/// 글줄을 **직접** 감싸야 한다 — 사이에 `Material` 이 있으면 기본 글자 스타일이 다시 정해져 값이 사라진다.
class ContentLocale extends StatelessWidget {
  const ContentLocale({super.key, required this.language, required this.child});

  /// 일과 언어 코드(`ko` `en` `ja` `zh` `es`). 모르는 값은 `ko`.
  final String? language;
  final Widget child;

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: TextStyle(locale: contentLocaleOf(language)),
    child: child,
  );
}
```

- [ ] **Step 3: `Routine.language` 를 더한다**

`client/lib/shared/models/routine.dart` — `creatorName`(76행) 아래에 필드를 더한다.

```dart
    /// 만든 사람이 이 이룸이 안에서 불리는 이름. 비어 있으면 null.
    String? creatorName,

    /// 이 일과의 콘텐츠 언어(`ko` `en` `ja` `zh` `es`) — 서버 `RoutineResponse.language` (마스터 C5).
    ///
    /// 일과를 만든 보호자 휴대폰의 화면 언어다. 이룸이 휴대폰은 카드 글과 음성을 화면 언어가 아니라
    /// **이 값**으로 보여준다. 옛 서버·옛 캐시에는 없다 — 그때는 모두 한국어 일과였으므로 `ko`.
    @Default('ko') String language,
  }) = _Routine;
```

`toJson`(157~171행)에 한 줄, `fromJson`(173~201행)에 한 줄을 더한다.

```dart
    if (creatorName != null) 'creatorName': creatorName,
    // 오프라인으로 이룸이 화면을 열어도 카드 글·음성이 일과 언어를 따르게 남긴다
    'language': language,
  };
```
```dart
      creatorName: json['creatorName']?.toString(),
      language: normalizeContentLanguage(json['language']),
    );
```
(`import '../../core/l10n/content_locale.dart';`) 그리고 Freezed 를 재생성한다.

```bash
cd client && dart run build_runner build --delete-conflicting-outputs
```
(`Failed to compile build script` 가 나면 `docs/troubleshooting.md` 의 `build_runner AOT 컴파일 실패` 를 먼저 읽는다 — `path_provider_foundation` 고정이 빠졌는지 본다.)

- [ ] **Step 4: `SpeechService.speak` 에 `language` 를 더한다**

`client/lib/features/child/data/speech_service.dart`

```dart
abstract interface class SpeechService {
  /// 읽어준다. **절대 throw하지 않는다** — 실패하면 false.
  ///
  /// [language] 는 읽을 글의 언어 — 일과 언어 코드(`ko` `en` `ja` `zh` `es`)다. 화면 언어가 아니다.
  Future<bool> speak(String text, {String language = 'ko'});

  /// 재생 중이면 멈춘다. 화면을 벗어날 때도 부른다.
  Future<void> stop();

  void dispose();
}

/// 일과 언어 → 기기 TTS 언어 태그. 모르는 값은 한국어다.
@visibleForTesting
String ttsLocaleOf(String language) => switch (language) {
  'en' => 'en-US',
  'ja' => 'ja-JP',
  'zh' => 'zh-CN',
  'es' => 'es-ES',
  _ => 'ko-KR',
};
```

`DeviceSpeech`(27~66행)

```dart
class DeviceSpeech implements SpeechService {
  DeviceSpeech({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  String? _configuredLanguage;
  var _rateSet = false;

  /// 아동이 듣기 편한 속도. 기본값(1.0)은 조금 빠르다.
  static const _rate = 0.45;

  @override
  Future<bool> speak(String text, {String language = 'ko'}) async {
    try {
      await _ensureConfigured(language);

      // 이전 재생이 남아 있으면 겹친다
      await _tts.stop();

      final result = await _tts.speak(text);
      // 플랫폼마다 1 또는 null을 준다. null도 성공으로 본다 — iOS가 그렇다.
      return result == null || result == 1;
    } catch (e) {
      debugPrint('[tts] 기기 음성 실패 → 서버로 넘어간다: $e');
      return false;
    }
  }

  /// 읽을 언어가 바뀐 때만 기기 음성을 다시 맞춘다 — 같은 기기에서 일과마다 언어가 다를 수 있다.
  Future<void> _ensureConfigured(String language) async {
    final tag = ttsLocaleOf(language);
    if (_configuredLanguage != tag) {
      await _tts.setLanguage(tag);
      _configuredLanguage = tag;
    }
    if (!_rateSet) {
      await _tts.setSpeechRate(_rate);
      _rateSet = true;
    }
  }
  // …(stop·dispose 는 그대로)…
```

`RemoteSpeech.speak`(99행)과 `FallbackSpeech.speak`(158~163행)

```dart
  @override
  Future<bool> speak(String text, {String language = 'ko'}) async {
    // 서버 음성(Supertonic `F1`)은 한국어 고정이다 — [language] 별 음성은 하위 계획 3 이 맡는다.
    // …(기존 본문 그대로)…
  }
```
```dart
  @override
  Future<bool> speak(String text, {String language = 'ko'}) async {
    if (text.trim().isEmpty) return false;

    if (await device.speak(text, language: language)) return true;
    return remote.speak(text, language: language);
  }
```

테스트 대역 7곳은 한 줄씩 고친다(`noSuchMethod` 대역 3곳은 그대로).

```bash
cd client && sed -i '' "s/Future<bool> speak(String text) async/Future<bool> speak(String text, {String language = 'ko'}) async/" test/card_review_badge_test.dart test/card_review_redesign_test.dart test/child_card_peek_test.dart test/card_review_delete_confirm_test.dart test/step_card_viewer_test.dart test/speech_service_test.dart test/photo/card_edit_sheet_photo_test.dart
grep -rn "Future<bool> speak(" test | grep -v "language"
```
Expected: 두 번째 명령이 **아무것도 찍지 않는다**(`test/l10n/` 의 새 대역은 이미 `language` 를 받는다).

- [ ] **Step 5: 카드 글에 일과 언어를 입히고 읽기에 넘긴다**

`client/lib/features/guardian/presentation/widgets/action_card_view.dart` — 생성자에 `language` 를 더하고 `build` 의 반환 위젯을 감싼다.

```dart
  const ActionCardView({
    super.key,
    required this.card,
    required this.index,
    this.routineId = '',
    this.language = 'ko',
    // …(나머지 인자 그대로)…
  });

  /// 카드 글의 언어 — 일과의 언어(`Routine.language`)다. 화면 언어와 다를 수 있다.
  final String language;
```
```dart
  @override
  Widget build(BuildContext context) {
    // …(기존 계산)…
    return ContentLocale(
      language: widget.language,
      child: /* 기존에 반환하던 위젯 */,
    );
  }
```
(`ContentLocale` 이 `Material` 보다 **위**에 있어야 한다. `ActionCardView` 안에 `Material` 이 있어 `content_language_flow_test` 의 글자 스타일 언어 검사가 `ko` 로 나오면, 제목·설명 `Text` 두 곳을 각각 `ContentLocale` 로 감싼다.)

`language` 를 일과에서 받아 넘기는 곳은 모두 같은 모양이다.

| 파일:줄 | 바꾸기 전 | 바꾼 뒤 |
| --- | --- | --- |
| `child_routine_detail_screen.dart:118` | `speech.speak('${card.displayTitle}. ${card.description}')` | `speech.speak('${card.displayTitle}. ${card.description}', language: _routine.language)` |
| `child_routine_detail_screen.dart:312` | `ChildCardPager(… routineId: routine.id, …)` | `ChildCardPager(… routineId: routine.id, language: routine.language, …)` |
| `child_card_pager.dart` 생성자·194행 | `ActionCardView(… routineId: routineId, …)` | 생성자에 `this.language = 'ko'`, `ActionCardView(… language: language, …)` |
| `card_review_screen.dart:143` | `speech.speak(…)` | `speech.speak(…, language: ref.read(routineFlowProvider).routine?.language ?? 'ko')` |
| `card_review_screen.dart:379` | `ActionCardView(… routineId: routineId, …)` | `ActionCardView(… routineId: routineId, language: routine?.language ?? 'ko', …)` |
| `card_review_reorder_list.dart` 생성자·538·581행 | `ActionCardView(… routineId: …)` | 생성자에 `this.language = 'ko'`, 두 `ActionCardView` 에 `language: widget.language`. 호출처(`card_review_screen.dart`)는 `language: routine?.language ?? 'ko'` |
| `step_card_viewer.dart` 생성자·`show`·144·108행 | `StepCardViewer.show(context, cards:, initialIndex:, routineId:)` | `show` 와 생성자에 `String language = 'ko'`, `ActionCardView(… language: widget.language)`, `speech.speak(…, language: widget.language)` |
| `routine_detail_sheet.dart:231` | `StepCardViewer.show(… routineId: widget.routine.id)` | `StepCardViewer.show(… routineId: widget.routine.id, language: widget.routine.language)` |

- [ ] **Step 6: 통과를 확인한다**

Run:
```bash
cd client && flutter test test/l10n/ test/speech_service_test.dart test/child_card_peek_test.dart test/step_card_viewer_test.dart test/routine_cache_test.dart test/reward_model_test.dart test/routine_creator_test.dart $(grep -rlE "ActionCardView|StepCardViewer|CardReview|ChildCardPager|ChildRoutineDetail" test | sort) && flutter analyze
```
Expected: **PASS**, `No issues found!`. 골든 PNG 변경 `git status --short client/test | grep -c png` → `0`.

- [ ] **Step 7: 커밋 (`/pro-commit`)**

```bash
git add client/lib/core/l10n/content_locale.dart client/lib/shared/models/routine.dart client/lib/shared/models/routine.freezed.dart client/lib/features/child/data/speech_service.dart client/lib/features/guardian/presentation/widgets/action_card_view.dart client/lib/features/child/presentation/widgets/child_card_pager.dart client/lib/features/child/presentation/child_routine_detail_screen.dart client/lib/features/guardian/presentation/card_review_screen.dart client/lib/features/guardian/presentation/widgets/card_review_reorder_list.dart client/lib/features/guardian/presentation/widgets/step_card_viewer.dart client/lib/features/guardian/presentation/widgets/routine_detail_sheet.dart client/test/card_review_badge_test.dart client/test/card_review_redesign_test.dart client/test/child_card_peek_test.dart client/test/card_review_delete_confirm_test.dart client/test/step_card_viewer_test.dart client/test/speech_service_test.dart client/test/photo/card_edit_sheet_photo_test.dart client/test/l10n/routine_language_test.dart client/test/l10n/content_locale_test.dart client/test/l10n/speech_language_test.dart client/test/l10n/content_language_flow_test.dart
```

## Task 25: 규칙 문서와 다른 계획에 넘기는 인터페이스

**Files:**
- Modify: `client/CLAUDE.md` — `### 필수` 목록(`## 코딩 규칙` 아래) 끝에 다국어 규칙 추가
- Modify: `docs/superpowers/plans/2026-10-02-i18n-0-master.md` — C4 표(`## 공통 계약` → `### C4. 클라이언트`)의 개발자 강제 행과 추가 이름

**Interfaces:**
- Consumes: Task 1~24 의 이름
- Produces: 새 화면·새 문구를 쓰는 사람이 따를 규칙, 하위 계획 3·4·5·6 이 쓸 클라이언트 이름 목록

- [ ] **Step 1: `client/CLAUDE.md` 에 규칙을 더한다**

`## 코딩 규칙` 의 `### 필수` 목록 끝에 더한다.

```markdown
- **사용자에게 보이는 문구는 코드에 한글(또는 어떤 언어든)로 쓰지 않는다.** `client/lib/l10n/app_ko.arb` 에
  키를 더하고 위젯은 `context.l10n.키`, `context` 가 없는 층(도메인 getter·저장소 대체 문구)은 `appL10n.키` 를
  쓴다(`core/l10n/`). 나머지 언어 ARB 는 번역 단계(하위 계획 5)에서 채우므로 **`app_ko.arb` 에만** 더한다.
  ARB 를 고치면 `cd client && flutter gen-l10n` 으로 생성 파일을 갱신하고 함께 커밋한다.
- **조사·단위·날짜를 코드로 조립하지 않는다.** 한국어 조사는 `{name}{batchim, select, yes{을} other{를}}` 에
  `batchimOf(name)` 을 넘기고, 개수는 ICU `plural`, 날짜는 `core/l10n/date_labels.dart` 를 쓴다.
- **로그·예외 메시지·정규식의 한글은 번역하지 않는다.** 줄 끝에 `// l10n-ignore: 이유` 를 단다.
  `cd client && dart run tool/check_hangul_literals.dart lib` 가 0줄이어야 한다.
- **`ko` 문구를 바꿀 때는 감사기를 돌린다**: `dart run tool/l10n_ko_audit.dart --base <옮기기 전 커밋>`.
```

- [ ] **Step 2: 마스터 C4 를 실제 구현에 맞춘다**

`docs/superpowers/plans/2026-10-02-i18n-0-master.md` 의 C4 표에서 개발자 강제 행을 고치고(Riverpod 3 에서 `StateProvider` 는 legacy), 아래 이름을 추가한다.

| 항목 | 이름 |
| --- | --- |
| 개발자 강제 | `client/lib/core/dev/dev_locale_override.dart` 의 `devLocaleOverrideProvider`(`NotifierProvider<DevLocaleOverrideNotifier, Locale?>`), 릴리스 빌드(`AppConfig.showDevTools == false`)에서는 무시 |
| 현재 언어 | `client/lib/core/l10n/effective_locale.dart` 의 `Locale effectiveAppLocale({Locale? devOverride})` |
| `context` 없는 문구 | `client/lib/core/l10n/current_l10n.dart` 의 `appL10n`, `syncAppL10n(context)` |
| 일과 언어 | `client/lib/core/l10n/content_locale.dart` 의 `normalizeContentLanguage`, `contentLocaleOf`, `ContentLocale` |
| 한국어 조사 판정 | `client/lib/core/l10n/batchim.dart` 의 `batchimOf(name)` → `yes`/`no`. ARB `batchim` 자리표시자는 `optionalPlaceholders` 로 다른 언어가 안 써도 된다 |
| 어절 표시 | `client/lib/core/text/keep_words.dart` 의 `usesWordJoiner(Locale?)` — `ko` 만 true (관리자 `notice-preview.js` 가 따라야 한다) |
| 음성 | `SpeechService.speak(String text, {String language = 'ko'})` |
| 테스트 | `client/test/helpers/pump_with_locale.dart` 의 `pumpWithLocale`, `client/test/l10n/arb_parity_test.dart` 의 `openedLocales`·`optionalPlaceholders` |

- [ ] **Step 3: 이 계획이 다른 계획에 넘기는 것을 확인한다**

| 받는 계획 | 넘기는 것 |
| --- | --- |
| 2 서버 | 클라이언트는 이미 `Accept-Language`(C1 형식)를 모든 요청에 싣는다. 서버가 `RoutineResponse.language` 를 내려주면 앱이 읽는다(없으면 `ko`). 이름·소개 등 **길이 제한은 서버가 코드 단위로 세는지 확인**해야 한다 — 앱은 글자(grapheme) 단위로 제한한다. |
| 3 AI·음성 | `SpeechService.speak(..., language:)` 가 일과 언어를 받는다. `DeviceSpeech` 는 기기 TTS 언어를 맞추기만 한다. 기기 음성이 그 언어를 못 읽을 때 서버 음성으로 대체, 서버 음성 언어별 목소리, 500자 제한 점검은 계획 3. 일과 생성 요청의 언어는 `Accept-Language` 로 서버가 정한다(요청 필드 없음). |
| 4 약관·공지 | `usesWordJoiner` 규칙을 `notice-preview.js` 의 `keepWords` 에 반영(`ko` 만 표시). `consent_documents.dart`(번들 기본값 `ko`·`en`)와 `consent_body.dart`(약관 본문 파서의 `제N조`·조사 정규식)는 이 계획이 건드리지 않았다. |
| 5 번역·품질 | `arb_parity_test.dart` 의 `openedLocales` 를 늘리고 CI(`PROJECT-FLUTTER-CI.yaml`)에 `flutter test test/l10n/` 를 연결한다. `pumpWithLocale` 로 넘침 검사를 전 화면에 확장한다(`overflow_pilot_test.dart` 참고). 용어 `이룸이`·캐릭터 이름 번역 여부, 번체 중국어 처리, 일본어·중국어 폰트 번들(결정 D3)은 계획 5. 번역을 채울 때 `plural` 은 `one` 을 더하고 `batchim` 은 쓰지 않는다. |
| 6 네이티브 | **iOS `CFBundleLocalizations`·Android 언어 선언이 있어야 `ko` 외 언어가 실기기에서 Dart 까지 온다.** 앱 이름 `naverClientName` 기본값(`이룸`)과 iOS 권한 문구 번역. |

- [ ] **Step 4: 커밋 (`/pro-commit`)**

```bash
git add client/CLAUDE.md docs/superpowers/plans/2026-10-02-i18n-0-master.md
```

## Task 26: 통과 조건 — 분석·전체 테스트·골든 0건·`ko` 불변

**Files:**
- (수정 없음. 실패하면 원인 파일을 고친다.)

**Interfaces:**
- Consumes: Task 1~25 전부
- Produces: 하위 계획 1 완료 판정

이 Task 가 통과하기 전에는 **완료라고 말하지 않는다.**

- [ ] **Step 1: 분석 0건**

Run: `cd client && flutter gen-l10n && flutter analyze`
Expected: `No issues found!`. `git status --short client/lib/l10n` 이 **비어 있다**(생성 파일이 ARB 와 맞다 — 다시 생성해도 바뀌지 않는다).

- [ ] **Step 2: 전체 테스트 — 기존 개수 이하로 줄지 않는다**

Run: `cd client && flutter test 2>&1 | tail -3`
Expected: `All tests passed!`, `+M` 에서 **M ≥ Task 1 Step 1 에서 적어 둔 N + 새로 만든 테스트 수**(기존 테스트를 지우거나 `skip` 하지 않았다. 단, Task 8 의 파일럿에서 넘침이 드러난 위젯은 `skip` 으로 돌렸을 수 있다 — 그 목록을 계획 5 로 넘겼는지 확인한다).

- [ ] **Step 3: 골든·시안 PNG 변경 0건**

```bash
git status --short client/test | grep -c "\.png"
git diff --stat 99b65ac0 -- 'client/test/goldens' 'client/test/figma' | tail -1
```
Expected: 첫 줄 `0`, 둘째 줄은 아무것도 안 나온다(PNG 가 하나도 안 바뀜). **`flutter test --update-goldens` 는 한 번도 쓰지 않았다.**

- [ ] **Step 4: 옮기지 않은 문구 0, `ko` 문구 감사 0**

```bash
cd client && dart run tool/check_hangul_literals.dart lib | tail -1
cd client && dart run tool/l10n_ko_audit.dart --base 99b65ac0 | tail -1
grep -rn "objectParticle\|subjectParticle\|topicParticle\|withParticle" client/lib | grep -v "client/lib/shared/utils/korean_particle.dart"
grep -rn "StateProvider" client/lib | head -1
```
Expected: `--- 사용자 노출 한글 리터럴 0줄`, `--- 조각 N개 중 기준 커밋에 없는 것 0개`, 세 번째·네 번째 명령은 **아무것도 안 나온다**(코드가 조사 글자를 붙이는 곳 0, `StateProvider` 없음).

- [ ] **Step 5: 개발자 도구로 언어 강제를 실제로 밟는다** (`/pro-launch`)

`ELUM_SHOW_DEV_TOOLS=true` 개발 빌드를 iOS 시뮬레이터에 띄워(`/pro-launch`) 개발자 도구 → `언어 강제` → `English` 를 고른 뒤 아무 API 가 나가게 하고, 개발자 도구의 로그 보기에서 요청 헤더에 `Accept-Language: en` 이 있는지 본다. `日本語` 를 고르면 `ja`, `简体中文` 은 `zh-Hans`. `휴대폰 언어 따르기` 로 풀면 시뮬레이터 언어가 나간다. 이 단계에서 **아직 번역이 비어 있어 화면 문구는 한국어 그대로**다(정상). 실기기의 OS 언어 전환은 계획 6 이후에야 확인할 수 있다.
Expected: 로그에 `Accept-Language` 가 강제한 값으로 찍힌다.

- [ ] **Step 6: 실패했을 때 — 어느 파일의 어느 문구가 달라졌는지 찾는 절차**

1. **테스트가 실패하면** 실패한 테스트 파일만 돌려 `Expected`/`Actual` 문자열을 본다: `cd client && flutter test <파일>`. 한글이 같아 보이는데 다르면 **공백·줄바꿈(`\n`)·전각 문자**를 의심한다.
2. **골든·시안 대조가 실패하면** 실패 출력이 알려 주는 `client/test/failures/*_maskedDiff.png` 를 열어 어긋난 덩어리의 화면 위치를 본다. 글자 줄바꿈 위치가 달라졌다면 ARB 의 `\n` 이 빠졌거나 공백이 바뀐 것이다. `--update-goldens` 로 덮지 않는다.
3. **옮기기 전에 있던 한글이 ARB 어디에도 없는지** 기준 커밋과 맞댄다.
   ```bash
   git diff -U0 99b65ac0 -- client/lib ':!client/lib/l10n' | grep -E '^-[^-].*[가-힣]' | sed 's/^-//'
   ```
   지워진 한글 줄 목록이 나온다. 각 줄이 `app_ko.arb` 의 어느 키가 됐는지 `grep -n '<문구 일부>' client/lib/l10n/app_ko.arb` 로 찾는다. 없으면 빠진 문구다.
4. **ARB 값이 원본과 다르면** `dart run tool/l10n_ko_audit.dart --base 99b65ac0` 가 `키: "조각"` 으로 바로 알려 준다.
5. **한 폴더만 의심되면** 그 폴더 Task 의 Step 6 테스트 목록(`grep -rlE "package:elum/features/<폴더>/" test`)만 다시 돌려 범위를 좁힌다.
6. 고친 뒤에는 Step 1부터 다시 돌린다 — 생성 파일(`flutter gen-l10n`)이 ARB 와 어긋난 채 커밋되지 않았는지도 Step 1 이 잡는다.

- [ ] **Step 7: 마지막 커밋과 이슈 기록 (`/pro-commit`, `/pro-github`)**

남은 변경이 있으면 경로를 명시해 커밋한다. 이슈 #521 에 이 계획의 완료와 **결정 D1~D7 의 사용자 답**을 댓글로 남긴다(`/pro-github`, 완료 보고서는 `/pro-report`). 푸시는 사용자가 요청할 때만 한다.

