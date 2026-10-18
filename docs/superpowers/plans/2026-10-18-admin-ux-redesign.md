# 관리자 페이지 UX 재설계 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 관리자 페이지가 현재 적용 상태를 먼저 보여 주고, 모든 목록이 같은 검색·필터·정렬·페이지 규칙을 쓰며, DB 를 직접 열지 않고도 운영(요금제 부여·설정 변경)할 수 있게 한다.

**Architecture:** 서버 렌더링(Thymeleaf+daisyUI) 유지. 공통 기반(목록 정의 `AdminListDefinition`, 공통 fragment, 날짜 포맷, PAGE_SIZE 단일 원본)을 먼저 만들고 화면별 이슈가 그 위에 얹힌다. 설정 화면은 표 중심 + 상단 요약 + Free/Pro 비교.

**Tech Stack:** Spring Boot, Thymeleaf, daisyUI, 바닐라 JS, JPA, Flyway(추가 전용), JUnit/MockMvc.

**Spec:** docs/superpowers/specs/2026-10-18-admin-ux-redesign-design.md

## Global Constraints

- 기존 admin URL·세션 로그인·`/admin/**` 권한 유지. 쿼리 파라미터 추가만 한다.
- 목록 PAGE_SIZE 단일 원본 20 (모니터링 50은 상수로 명시), 기간 필터 기본값 최근 7일(모니터링·서버 로그).
- DB 마이그레이션은 Flyway 추가 전용만: 새 테이블 `subscription_history`, `prompt_history.changed_by`, 의견 처리 상태 컬럼. 기존 데이터 변경 금지.
- 모든 변경은 변경 전후·변경자·사유를 이력에 남긴다. 비밀값은 값 대신 `••••`.
- 새 JS 프레임워크·의존성 금지. `server/CLAUDE.md` 규칙 준수(`@LogMonitoring`, `*ControllerDocs`, `ErrorCode` + i18n + 클라 `server_error_code.dart`).
- 커밋 메시지에 Co-Authored-By 넣지 않는다. 파일 300줄 초과 지양, 500줄 초과 금지. 주석은 한국어 한 줄 요약 규칙.

## Review Focus

- 설정 이력이 한 번도 없는 키: "기본 설정 (변경 이력 없음)" 표시, 마지막 변경 열 정렬에서 맨 뒤.
- 검색어에 `%`·`_`·따옴표·빈 문자열: 쿼리가 깨지지 않고 빈 검색은 전체.
- 정렬 파라미터에 허용 목록 밖 값: 기본 정렬로 폴백(500 금지).
- 페이지 번호가 범위 밖·음수·숫자 아님: 첫/마지막 페이지로 보정.
- 요금제 부여를 같은 회원에 연속 두 번: 이력 2건, 마지막 상태 정확, 이력 없이 상태만 바뀌는 경우 없음.

---

### Task 1: 공통 기반 (이슈 ①, 먼저 머지)

**Files:**
- Create: `server/src/main/java/com/chuseok22/elumserver/admin/application/list/AdminListDefinition.java`, `AdminListQuery.java`, `AdminListDefaults.java`
- Create: `server/src/main/resources/templates/admin/fragments/admin-list.html` (fragments `pager`, `filterBar`, `table`, `lastChanged`)
- Create: `server/src/main/java/com/chuseok22/elumserver/admin/application/format/AdminDateFormatter.java` (Thymeleaf 노출 빈 `adminDate`)
- Modify: 각 서비스의 `PAGE_SIZE` 선언 4곳을 `AdminListDefaults.PAGE_SIZE` 로 치환
- Modify: `server/src/main/resources/static/admin/js/admin-ui.js` (필터 칩·정렬 헤더 공통 동작)
- Create/Modify: `ArchitectureRulesTest` (admin 서비스가 자체 `PAGE_SIZE` 를 선언하지 않음)
- Test: `AdminListQueryTest`, `AdminDateFormatterTest`, `AdminFragmentRenderTest`

**Interfaces:**
- Produces:
  - `record AdminListQuery(String q, Map<String,String> filters, String sort, int page)` + `static AdminListQuery of(String q, Map<String,String> filters, String sort, String page, AdminListDefinition def)` — 잘못된 sort/page 를 기본값으로 보정.
  - `record AdminListDefinition(List<Column> columns, List<String> searchFields, List<Filter> filters, String defaultSort)`; `Column(String key, String label, boolean isSortable)`; `Filter(String key, String label, List<Option> options)`.
  - `AdminListDefaults.PAGE_SIZE = 20`, `AdminListDefaults.DEFAULT_PERIOD_DAYS = 7`.
  - `AdminDateFormatter.format(LocalDateTime) -> String` ("yyyy-MM-dd HH:mm"), `null` 은 "-".
  - fragment 호출: `~{admin/fragments/admin-list :: pager(${page}, ${baseUrl})}`, `filterBar(${definition}, ${query})`, `lastChanged(${at}, ${by})`.

- [ ] **Step 1: 테스트 작성** — `AdminListQueryTest`: 잘못된 sort → defaultSort, page "abc"/-1/9999 → 1·1·마지막 보정, q 빈 문자열 → null.
- [ ] **Step 2: 실패 확인** — `./gradlew test --tests '*AdminListQueryTest'` → FAIL(클래스 없음).
- [ ] **Step 3: 구현** — 위 시그니처대로. 보정은 정의의 `columns` 중 `isSortable` 키만 허용.
- [ ] **Step 4: fragment·날짜 포맷·PAGE_SIZE 치환·규칙 테스트** — 기존 화면 3개 이상에 pager fragment 적용해 렌더 스모크(`AdminFragmentRenderTest`: 200 + 페이저 요소) 확인.
- [ ] **Step 5: 전체 테스트** — `./gradlew test` 통과.
- [ ] **Step 6: 커밋** (pro-commit, 이슈 번호 연결).

### Task 2: 시스템 설정 재설계 (이슈 ②)

**Files:**
- Create: `admin/application/service/SystemConfigOverviewService.java`
- Modify: `SystemConfigHistoryRepository` (키별 최신 행 group-by 쿼리 `findLatestPerKey()`), 설정 컨트롤러(`GET /admin/settings` 모델: `overview`, `planComparison`, `rows`; `GET /admin/settings/{key}/history`)
- Modify: `templates/admin/settings.html`, `static/admin/js/settings.js`
- Test: `SystemConfigOverviewServiceTest`, `AdminSettingsControllerTest`

**Interfaces:**
- Consumes: Task 1 의 `AdminListQuery`, fragment `lastChanged`, `adminDate`.
- Produces: `record SettingsOverview(int differsFromDefaultCount, List<Highlight> highlights, List<PlanRow> planComparison)`; `record SettingRow(String key, String label, String group, String currentValue, String defaultValue, boolean isDifferent, LocalDateTime lastChangedAt, String lastChangedBy, String lastReason)`.

- [ ] **Step 1: 테스트** — 이력 없는 키 → "기본 설정" 표시값·마지막 변경 null, Free 광고 제거 true 일 때 `isDifferent=true` 와 highlights 포함, 비밀값은 값 대신 "설정됨".
- [ ] **Step 2: 실패 확인 → 구현** — 요약(기본값과 다른 설정, 켜진 이벤트·점검, 핵심 토글), Free/Pro 비교, 표(최근 변경순 기본), 검색(이름·키·값·설명·그룹·변경자), 칩(전체/기본값과 다름/오늘 변경/그룹), 행 클릭 패널(수정+키별 이력), 저장 즉시 행 갱신, 날짜 선택기·불리언 토글.
- [ ] **Step 3: 변경 이력 화면** — 키·변경자·기간 필터 + 페이지, 20건 고정 제거.
- [ ] **Step 4: 실제 화면 확인** — 로컬 서버 기동, 데스크톱·모바일 폭 캡처.
- [ ] **Step 5: 커밋**.

### Task 3: 회원·요금제 운영 (이슈 ③)

**Files:**
- Create: Flyway `V{다음번호}__create_subscription_history.sql`, `SubscriptionHistory` 엔티티·리포지토리
- Modify: `SubscriptionService.grantPro/revokePro` (이력 기록: 변경자·전/후 요금제·기간·사유), 회원 목록(요금제 열·필터, 정렬 선택, 마지막 변경), 회원 상세(부여·회수 폼, 요금제 이력 표)
- Test: `SubscriptionServiceHistoryTest`, `MemberListQueryTest`

**Interfaces:**
- Consumes: Task 1.
- Produces: `SubscriptionService.grantPro(String memberId, int days, String reason, String actor)`, `revokePro(String memberId, String reason, String actor)`; `SubscriptionHistoryService.recent(String memberId, int limit)`.

- [ ] **Step 1: 테스트** — 연속 두 번 부여 → 이력 2건·마지막 상태 정확, 회수 → 이력에 전후 값, 요금제 필터·정렬 허용 키만.
- [ ] **Step 2: 구현 + 마이그레이션(추가 전용)**.
- [ ] **Step 3: 화면 확인·커밋**.

### Task 4: 일과 목록 (이슈 ④)

**Files:** 일과 목록 서비스·컨트롤러·`routines.html`, `routine-detail.html`
**Interfaces:** Consumes Task 1.
- [ ] 테스트(상태 필터·정렬 허용 키·검색 특수문자) → 구현(상태 필터, 정렬 선택, 회원 링크, 마지막 변경) → 화면 확인 → 커밋.

### Task 5: 공지·의견 (이슈 ⑤)

**Files:** 공지 서비스(전체 조회 → 검색·페이징), `notices.html`, 의견 엔티티·Flyway `V{다음번호}__add_feedback_status.sql`, `feedback.html`, 처리 상태 변경 동작
**Interfaces:** Consumes Task 1. Produces: `FeedbackStatus { NEW, IN_PROGRESS, DONE }`, `FeedbackService.changeStatus(String id, FeedbackStatus status, String actor)`.
- [ ] 테스트(공지 검색·페이징, 의견 상태 전이·필터, 기존 행 기본값 NEW) → 구현(추가 전용 마이그레이션) → 화면 확인 → 커밋.

### Task 6: 모니터링·로그·프롬프트·약관 표기 (이슈 ⑥)

**Files:** 모니터링(기간·회원 필터, 기본 7일), 서버 로그(공통 스타일·페이저), 프롬프트 이력 Flyway `V{다음번호}__add_prompt_history_changed_by.sql` + 표시, 시각 포맷 통일(약관·프롬프트)
**Interfaces:** Consumes Task 1.
- [ ] 테스트(기간 기본값 7일·범위 밖 날짜 보정, 프롬프트 수정자 기록) → 구현 → 화면 확인 → 커밋.

### Task 7: 대시보드·내비게이션·모바일·봉인 (이슈 ⑦)

**Files:** `dashboard.html`, `DashboardService`(요금제 분포, 지금 적용 중 설정 요약, 60초 캐시), `admin-layout.html`(사이드바 그룹: 운영/콘텐츠/시스템), 표 가로 스크롤 보강, 규칙 테스트(admin 목록이 `AdminListDefinition` 없이 추가되지 않음; 크레딧·서버 로그 예외 명시)
**Interfaces:** Consumes Tasks 1~6.
- [ ] 테스트(분포 집계, 캐시 60초 내 재호출 시 쿼리 1회) → 구현 → 전 화면 데스크톱·모바일 캡처 → 규칙 테스트 → 커밋.

## 실행 순서
Task 1 머지 후 Task 2~7. 메모리 때문에 동시에 2개까지(서버 Gradle 테스트가 무겁다). 각 Task = GitHub 이슈 1개 = PR 1개, 이슈마다 pro-report 와 라벨 완료처리.
