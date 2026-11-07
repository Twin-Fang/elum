# CLAUDE.md

이 파일은 `elum-server` 프로젝트에서 작업할 때 따라야 하는 규칙을 정의합니다.

## 프로젝트 개요

운영 중인 이룸(ELUM) 서비스의 Spring Boot 백엔드. 보호자가 자연어로 입력한 일과를 AI가 아동 맞춤 행동 카드로 변환하는 서비스의 API 서버 + 관리자 페이지.

이 저장소(`elum`)는 `client/`(Flutter 프론트엔드)와 `server/`(본 백엔드)가 함께 있는 모노레포이며, 우리는 백엔드 담당으로서 **`server/` 내부 파일만** 열람·수정한다. `client/`와 레포 루트 파일은 작업 범위 밖이다. 예외: 새 `ErrorCode`를 만들 때는 클라 `server_error_code.dart`도 같이 고친다(아래 "반드시 지킬 것").

## 핵심 원칙

- 운영 중인 서비스다. 동작을 지키면서 코드 품질도 함께 챙긴다.
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

배포된 백엔드는 내 NAS(SUH-PROJECT, `api.elum.suhsaechan.kr`)의 Traefik Blue/Green 무중단 배포라 컨테이너가 `elum-back-blue` · `elum-back-green`
둘 중 하나로 떠 있다 (2026-11-05 전환, #1104). 배포할 때마다 서로 바뀌므로 **둘 중 지금 떠 있는 쪽**으로 조회한다.

```bash
# 내 NAS 에서 (/pro-ssh 저장 이름 synology-nas, sudo 필요). 지금 떠 있는 쪽 확인 > 최근 로그
sudo docker ps --format '{{.Names}} {{.Status}}' | grep elum-back
sudo docker logs --tail 500 elum-back-blue 2>&1 | tail -50
sudo docker logs --since 10m elum-back-green 2>&1 | grep -E 'ERROR|WARN'

# 실시간으로 따라가며 재현 (스스로 끝나지 않는다: timeout 이나 grep -m 1 로 끊는다)
sudo docker logs -f --since 1m elum-back-blue 2>&1
```

관리자 화면 `https://api.elum.suhsaechan.kr/admin/logs` (서버 로그) 에서도 볼 수 있다.

> 클라이언트에서 API가 실패할 때(4xx/5xx) **서버 코드를 추측하기 전에 이 로그를 먼저 본다.**
> 요청이 서버까지 왔는지, 어느 계층에서 터졌는지가 로그에 남는다.

## 상세 규칙

- [`../docs/testing-guidelines.md`](../docs/testing-guidelines.md) — 테스트 설계 가이드라인 (무엇을 단언하는가·층 고르기·퇴역 규칙)
  - 운영 중인 서비스라 API 계약(JSON 필드·상태 코드·에러 코드)·인증·트랜잭션·AI 실패 대체는 반드시 테스트로 고정한다
  - 가짜(mock)가 돌려준 값을 그대로 단언하거나 `verify` 만 있고 결과 단언이 없는 테스트는 쓰지 않는다
  - `@WebMvcTest` 는 `@MockitoBean` 조합이 다르면 Spring 컨텍스트를 새로 띄운다. 같은 조합을 쓰는 클래스는 묶는다
