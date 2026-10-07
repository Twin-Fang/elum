# 재설치 인증과 휴대폰 잠금 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** 삭제 후 로그인, 기존 회원 복원, 오프라인 로컬 잠금의 일관성을 보장한다.
**Architecture:** 설치 식별자로 토큰 복원을 제한한다. 기존 회원 API를 복원 기준으로 사용하고 비밀암호 verifier는 휴대폰 secure storage에서 관리한다.
**Tech Stack:** Flutter/Dart, Swift, Kotlin, flutter_secure_storage, cryptography, Dio.
**Spec:** docs/superpowers/specs/2026-10-05-session-restoration-design.md

## Global Constraints

- 한국어 WHY 주석, 새 사용자 문구는 ARB, 기존 Naver URL callback 유지.
- 다른 세션 파일 변경 금지. 파일 삭제·직접 커밋·push 금지(부모가 projectops로 통합).
- 서버 PIN 동기화 금지. 오프라인 진행 큐 보존. 실기기 확인은 사용자 담당.

## Review Focus

- 설치 표식 읽기 오류는 신규 설치로 처리하지 않고 E-INSTALL 재시도.
- 실패한 토큰 삭제/쓰기 이후에도 예전 세션을 열지 않는다.
- 다른 계정 로그인이 로컬 PIN·프로필·오프라인 큐를 상속하지 않는다.
- PIN 부재/저장 실패는 보호자 잠금을 우회하지 못한다.
- 회원 조회 오류/토큰 갱신 오프라인은 신규 회원 판정이 아니다.

### Task 1: 설치 세션 경계

**Files:** main.dart, core/storage/token_store.dart, 새 installation_store.dart, AppDelegate.swift, MainActivity.kt, 설치 관련 test.
**Interfaces:** 설치 식별자 조회는 `Future<String>`이며 토큰 load 전에 수행. SecureTokenStore 생성자에 installationId를 전달할 수 있게 한다. 토큰 설치 불일치는 세션 부재이며 기존 token interface는 유지한다. 정상 업데이트는 설치 결합이 없는 레거시 토큰과 일관된 로컬 상태가 있으면 강제 로그아웃 없이 일회 이전한다. 로컬 상태 없는 재설치·이미 결합된 설치 불일치는 로그인. 기존 데이터 계정 경계는 Task 3이 소비할 수 있게 보존된 이전 회원 식별자와 설치 변경 정보를 LocalStorage에 전달하거나 문서화한다.
- [ ] keychain 잔존+새 설치, 같은 설치 재시작, 표식 오류, 저장 오류 테스트를 먼저 작성·실행한다.
- [ ] 네이티브 백업 제외 식별자 원자 저장과 Dart 토큰 결합·E-INSTALL 재시도 화면을 구현한다.
- [ ] 설치 단위 토큰/상태 실패 시 닫힘을 검증한다. `flutter test test/installation_session_test.dart`.
- [ ] 변경과 검증 결과를 작업 보고서에 기록하고 부모에게 제출한다. 커밋은 부모가 한다.

### Task 2: 로컬 비밀암호

**Files:** local_storage.dart, 새 guardian_lock_store.dart, PIN 변경/모드 전환 화면, profile_session.dart, dev_tools_overlay.dart, 잠금 관련 test.
**Interfaces:** LocalStorage에 `Future<bool> hasPin()`, `Future<bool> verifyPin(String pin)`를 제공하고 `setPin` 유지, 원문 읽기는 제거. 테스트용 메모리 구현도 동일 인터페이스. Task 1 설치 id에 결합한 verifier 사용. 잠금 생성 권한은 Task 3에서 로그인 후 생성 경로로 부여하므로 화면 전환 PIN 없는 경로에서는 로그인으로 이동.
- [ ] 오프라인 정답/오답, salt, 저장 실패, 5회 실패 제한, 앱 재실행 제한, 레거시 이전 테스트를 작성·실행한다.
- [ ] PBKDF2 600000 SHA256 256bit, secure record 저장·검증, 평문 이전, 계정 종료 PIN 초기화 구현.
- [ ] PIN 저장/조회 실패 안내, 누락 PIN 우회 금지, 프로필 전환 시 PIN 보존 구현.
- [ ] 관련 테스트와 analyze 후 보고서 제출. 커밋은 부모가 한다.

### Task 3: 로그인 복원 및 갱신

**Files:** auth_repository.dart, auth_interceptor.dart, login_screen.dart, 인증·세션 테스트.
**Interfaces:** Task 1 설치 경계와 Task 2 hasPin/verifyPin. 성공한 기존 보호자 로그인은 profile 저장/완료/guardian 역할 지정 후 PIN 부재일 때 생성 화면, 있으면 홈. 회원 조회 실패는 토큰 제거 후 실패 결과. 갱신 null은 토큰이 실제 제거되었을 때만 세션 만료 통지.
- [ ] 기존 다중 프로필 복원, 신규 회원, 회원 조회 5xx/오프라인/비정상 응답, 다른 회원 로컬 초기화, refresh 임시 실패·확정 401·세션 전환 테스트 작성·실행.
- [ ] 계정 식별자로 로컬 자료 격리, 회원 snapshot 복원, 새 로그인 PIN 설정, 늦은 refresh 응답 차단 구현.
- [ ] 기존 인증·라우팅·PIN·프로필·공유 진행 테스트 회귀검증 후 보고서 제출.

### 통합

- [ ] 독립 리뷰를 통해 명세·코드 품질 검증하고 발견 결함 수정.
- [ ] flutter analyze, 전체 flutter test 및 플랫폼 컴파일 확인.
- [ ] projectops 커밋·승인된 push·develop 통합·main 버전 병합·릴리스 PR 배포.
- [ ] 코드 검증 결과와 실기기 미확인 범위를 pro-report 댓글에 남기고 작업완료 라벨 처리.
