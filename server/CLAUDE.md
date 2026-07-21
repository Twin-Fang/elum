# CLAUDE.md

이 파일은 `elum-server` 프로젝트에서 작업할 때 따라야 하는 규칙을 정의합니다. 상세 규칙은 `.claude/rules/*.md`를 참고하세요.

## 프로젝트 개요

24시간 해커톤용 이룸(ELUM) 서비스의 Spring Boot 백엔드. 보호자가 자연어로 입력한 일과를 AI가 아동 맞춤 행동 카드로 변환하는 서비스의 API 서버 + 관리자 페이지.

이 저장소(`elum`)는 `client/`(Flutter 프론트엔드)와 `server/`(본 백엔드)가 함께 있는 모노레포이며, 우리는 백엔드 담당으로서 **`server/` 내부 파일만** 열람·수정한다. `client/`와 레포 루트 파일은 작업 범위 밖이다.

## 핵심 원칙

- 동작 우선. 코드 퀄리티보다 24시간 내 완성을 우선한다.
- 단위테스트는 작성 가능하다. 통합테스트, curl 기반 수동 테스트, DB 직접 접근은 금지한다.
- DDD 스타일 패키지 구조(`{domain}/core`, `{domain}/application`, `{domain}/infrastructure`)를 따른다.

## 반드시 지킬 것

- 모든 엔티티는 `BaseEntity` 상속, PK는 UUID 문자열
- 예외는 `CustomException` + `ErrorCode` + `GlobalExceptionHandler`만 사용
- 모든 REST 엔드포인트에 `@com.chuseok22.logging.annotation.LogMonitoring` 적용
- 모든 REST 엔드포인트는 `*ControllerDocs` 인터페이스로 Swagger 문서화
- REST API는 JWT(accessToken만, stateless), 관리자 페이지는 세션(formLogin)
- `application-*.yml` 수정 금지, `.gitignore` 현재 상태 유지(force add 금지)
- `application-*.yml` 직접 접근(열람 포함) 절대 금지 — 값이 필요하면 항상 사용자에게 확인
- DB 직접 접근 절대 금지 — 쿼리 실행, 접속 정보 확인, 스키마 조회 등 일체 금지. 필요한 정보는 항상 사용자에게 확인
- request DTO(`dto/request` 패키지)에 `jakarta.validation.constraints` 계열 검증 어노테이션(`@NotBlank`, `@NotNull`, `@Size`, `@Pattern` 등)을 추가하지 않는다. 신규 DTO 작성 시에도 적용하지 않는다

## 배포 서버 로그 확인

배포된 백엔드(`elum-back` 컨테이너)의 로그는 아래로 확인한다.

```bash
# 전체 로그를 실시간으로 따라간다
curl -N "http://chuseok22.synology.me:8888/containers/elum-back/logs?lines=all&follow=true"

# 최근 로그만 보고 끝낸다 (follow 없이)
curl -s --max-time 20 "http://chuseok22.synology.me:8888/containers/elum-back/logs?lines=500" | tail -50
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
