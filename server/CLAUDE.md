# CLAUDE.md

이 파일은 `elum-server` 프로젝트에서 작업할 때 따라야 하는 규칙을 정의합니다. 상세 규칙은 `.claude/rules/*.md`를 참고하세요.

## 프로젝트 개요

24시간 해커톤용 이룸(ELUM) 서비스의 Spring Boot 백엔드. 보호자가 자연어로 입력한 일과를 AI가 아동 맞춤 행동 카드로 변환하는 서비스의 API 서버 + 관리자 페이지.

이 저장소(`elum`)는 `client/`(Flutter 프론트엔드)와 `server/`(본 백엔드)가 함께 있는 모노레포이며, 우리는 백엔드 담당으로서 **`server/` 내부 파일만** 열람·수정한다. `client/`와 레포 루트 파일은 작업 범위 밖이다.

## 핵심 원칙

- 동작 우선. 코드 퀄리티보다 24시간 내 완성을 우선한다.
- DDD 스타일 패키지 구조(`{domain}/core`, `{domain}/application`, `{domain}/infrastructure`)를 따른다.

## 반드시 지킬 것

- 모든 엔티티는 `BaseEntity` 상속, PK는 UUID 문자열
- 예외는 `CustomException` + `ErrorCode` + `GlobalExceptionHandler`만 사용
- `common`은 도메인 패키지를 import하지 않는다(필터 체인을 조립하는 `SecurityConfig`만 예외). 다른 도메인의 repository는 직접 쓰지 않고 그 도메인의 서비스를 거친다 — `ArchitectureRulesTest`가 막고, 이미 있는 사용은 `src/test/resources/architecture/cross-domain-repository-allowlist.txt`에 동결돼 있다
- admin 컨트롤러가 JSON을 돌려주면 `@JsonErrorResponse`를 붙여 `GlobalExceptionHandler` 범위에 넣는다. 새 도메인 패키지는 `basePackages`에 더한다
- 모든 REST 엔드포인트에 `@com.chuseok22.logging.annotation.LogMonitoring` 적용
- 모든 REST 엔드포인트는 `*ControllerDocs` 인터페이스로 Swagger 문서화
- REST API는 JWT(accessToken만, stateless), 관리자 페이지는 세션(formLogin)
- `.gitignore` 현재 상태 유지(force add 금지)
- request DTO(`dto/request` 패키지)에 `jakarta.validation.constraints` 계열 검증 어노테이션(`@NotBlank`, `@NotNull`, `@Size`, `@Pattern` 등)을 추가하지 않는다. 신규 DTO 작성 시에도 적용하지 않는다
- 새 `ErrorCode`를 만들면 `i18n/messages_ko.properties`에 문구를 함께 더한다. 빠지면 `ErrorMessagesStartupGuard`가 서버 기동을 막는다. 클라 `server_error_code.dart`에도 같은 이름으로 더한다(안 하면 앱의 동기화 시험이 실패한다). 사용자에게 가는 문장은 `ErrorCode`에 쓰지 않는다
- 서버가 만들어 내려주는 사용자 노출 문장(추천 일과·폴백 질문)은 코드가 아니라 `i18n/routine-phrases_*.properties`에 둔다. 이 파일을 채워야 관리자 `ENABLED_CONTENT_LOCALES`에서 그 언어를 켤 수 있다
- 일과 AI 출력은 아직 한국어 고정이고 `Routine.language`만 요청 언어로 저장된다. AI 출력 언어 지정이 배포되기 전에는 `ko` 외 언어를 켜지 않는다

## 배포 서버 로그 확인

배포된 백엔드는 Blue/Green 무중단 배포라 컨테이너가 `elum-back-blue`(8085) · `elum-back-green`(8086)
둘 중 하나로 떠 있다. 배포할 때마다 서로 바뀌므로 **둘 중 지금 떠 있는 쪽**으로 조회한다.
한쪽에서 로그가 안 나오면 다른 쪽을 조회한다.

```bash
# 전체 로그를 실시간으로 따라간다 (blue 또는 green)
curl -N "http://chuseok22.synology.me:8888/containers/elum-back-blue/logs?lines=all&follow=true"
curl -N "http://chuseok22.synology.me:8888/containers/elum-back-green/logs?lines=all&follow=true"

# 최근 로그만 보고 끝낸다 (follow 없이)
curl -s --max-time 20 "http://chuseok22.synology.me:8888/containers/elum-back-blue/logs?lines=500" | tail -50
curl -s --max-time 20 "http://chuseok22.synology.me:8888/containers/elum-back-green/logs?lines=500" | tail -50
```

**`lines`는 `500` · `1000` · `all` · 빈 값만 받는다.** 그 외 숫자를 넣으면
로그 대신 `잘못된 'lines' 파라미터 요청입니다`가 돌아온다.

`follow=true`는 스트림이라 스스로 끝나지 않는다. 특정 문구가 나올 때까지만 볼 거라면
`--max-time`으로 상한을 두거나 `grep -m 1`로 끊는다.

> 클라이언트에서 API가 실패할 때(4xx/5xx) **서버 코드를 추측하기 전에 이 로그를 먼저 본다.**
> 요청이 서버까지 왔는지, 어느 계층에서 터졌는지가 로그에 남는다.

## 상세 규칙

- `.claude/rules/00-project-overview.md` — 프로젝트 목적/스택/명령어
- `.claude/rules/10-architecture-and-boundaries.md` — 아키텍처/모듈 경계
- `.claude/rules/20-team-conventions.md` — 네이밍/코드 스타일/책임 분리
- `.claude/rules/30-testing-and-verification.md` — 검증 전략
- `.claude/rules/40-delivery-and-review.md` — 보고서/PR 규칙
