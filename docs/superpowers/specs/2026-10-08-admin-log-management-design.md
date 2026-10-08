# 관리자 서버 로그 관리 개편 설계

- 작성일: 2026-10-08
- 범위: `server/` (logback · 관리자 로그 화면) · `.github/workflows/PROJECT-SPRING-CICD.yaml`

## 1. 왜 하는가

운영에서 문제가 나면 바로 원인을 봐야 하는데 지금은 그게 안 된다.

- 관리자 "서버 로그" 화면은 **현재 파일의 끝 1000줄**만 2초 폴링으로 보여준다. 몇 시간 전 오류는 밀려나 있다.
- 롤링된 지난 로그(`.log.gz`)는 화면·API 어디서도 볼 수 없고, **파일째 받을 방법이 없다.**
- 운영 로그 레벨이 개발과 같아 `hibernate.type.descriptor: TRACE`가 SQL 바인딩을 줄마다 찍는다. 오류가 소음에 묻힌다.
- **Blue/Green 배포에서 두 컨테이너가 같은 NAS 폴더(`/app`)를 마운트해 같은 `logs/elum-server.log`에 쓴다.**
  - 배포 중 1~2분간 서로 다른 JVM이 한 파일에 쓰고 각자 롤링한다 → 롤링 시 줄이 엉뚱한 파일로 가거나 유실될 수 있다(구조상 위험, 운영 발생 여부는 미확인).
  - 컨테이너 안 PID가 항상 `1`이라 어느 색(blue/green) 로그인지 구분할 수 없다.
  - 헬스체크에 실패한 새 컨테이너는 `docker rm`되며 `docker logs`도 사라진다. 배포 실패 원인을 볼 곳이 없다.

참고: 이 서버는 log4j가 아니라 Spring Boot 기본 **logback**(`logback-spring.xml`)을 쓴다.

## 2. 목표 · 성공 기준

관리자 페이지 하나로 운영 로그를 **보고 · 찾고 · 받고 · 지우고 · 레벨을 바꾸고 · 배포 상태를 안다.**

- 지금 응답 중인 서버의 색·버전·시작 시각을 화면 맨 위에서 안다.
- blue/green 로그가 섞이지 않는다.
- 지난 로그(`.gz` 포함)를 파일째 다운로드하거나 레벨·키워드로 검색한다.
- 배포 이력(기동·준비완료·종료·실패)을 타임라인으로 본다.
- 재배포 없이 로거 레벨을 바꾼다.
- 최근 ERROR 건수가 사이드바·대시보드에 뜬다.

비목표: 외부 알림(Slack·메일), 로그 수집 시스템(ELK·Loki) 도입, 로그 마스킹.

## 3. 결정한 접근 — 색깔별 폴더 + 배포 이력 파일

검토한 안

| 안 | 내용 | 판단 |
|---|---|---|
| **A. 색깔별 폴더** | `logs/blue/`, `logs/green/` + `logs/deploy-history.log` | **채택.** 쓰는 파일이 분리돼 섞임이 근본 해결되고, 보관·용량은 logback이 그대로 관리 |
| B. 배포마다 새 폴더 | `logs/20261008-0912-green/` | 폴더가 무한히 늘고 logback 보관 정책이 폴더를 못 넘어 정리 스케줄러가 별도로 필요 |
| C. 한 파일 + `prudent` | 다중 JVM 쓰기 모드 | 크기 기준 롤링·압축과 함께 못 써서 탈락 |

A의 비용: 같은 색 폴더를 두 배포마다 재사용한다. 실패한 배포의 로그도 같은 파일에 이어 쌓이지만 기동 마커 줄과 배포 이력으로 구간을 구분한다.

## 4. 로그 구조

```
/app/logs/                       (NAS /volume1/project/elum/server/logs)
  blue/   elum.log  elum-error.log  elum.2026-10-08.0.log.gz  elum-error.2026-10-08.0.log.gz
  green/  elum.log  elum-error.log  ...
  local/  (로컬 실행 — ELUM_INSTANCE 미지정)
  deploy-history.log
  elum-server*.log(.gz)          (이전 형식 — 그대로 둔다. 화면에서 "이전 형식"으로 조회·다운로드·삭제)
```

### logback-spring.xml

- `LOG_DIR = ${ELUM_LOG_DIR:-logs}`, `INSTANCE = ${ELUM_INSTANCE:-local}`
- 줄 패턴: Spring Boot `FILE_LOG_PATTERN` 앞에 `[${INSTANCE}]`를 붙인다. 콘솔 패턴도 동일하게.
- `FILE` → `${LOG_DIR}/${INSTANCE}/elum.log`, SizeAndTimeBased, 10MB · 7일 · 1GB
- `ERROR_FILE` → `${LOG_DIR}/${INSTANCE}/elum-error.log`, `ThresholdFilter WARN`, 10MB · 30일 · 200MB
- `RECENT_ERRORS` → `RecentErrorAppender`(메모리, ERROR만)
- root INFO에 CONSOLE · FILE · ERROR_FILE · RECENT_ERRORS 연결

### application-prod.yml

- `logging.level.org.hibernate.type.descriptor: TRACE` 삭제.
- `DispatcherServlet: DEBUG`, `com.chuseok22: DEBUG`, `org.hibernate.SQL: INFO`는 유지(사용자 결정: TRACE만 끈다).

## 5. 인스턴스 인식 · 배포 이력

### 워크플로

`PROJECT-SPRING-CICD.yaml`의 `docker run`에 추가:

```
-e ELUM_INSTANCE=<blue|green>   # CONTAINER_NAME 이 -blue/-green 중 무엇인지에서 결정
-e ELUM_PORT=<8085|8086>
```

> 테스트 빌드·배포 워크플로는 main 기준으로 돈다. 워크플로 변경은 main 머지 후부터 적용된다.

### 버전

`build.gradle`에 `springBoot { buildInfo() }` → `BuildProperties`로 버전을 읽는다. 없으면(테스트 등) `unknown`.

### LogInstanceInfo (빈)

`instance`(ELUM_INSTANCE, 기본 `local`), `port`, `version`, `startedAt`(JVM 시작 시각). 반대 색은 `blue↔green`, `local`이면 없음.

### DeployHistoryRecorder

Spring 생명주기 이벤트마다 `logs/deploy-history.log`에 한 줄 append.

| 이벤트 | 기록 |
|---|---|
| `ApplicationStartedEvent` | `STARTED` |
| `ApplicationReadyEvent` | `READY` |
| `ContextClosedEvent` | `STOPPED` |

줄 형식(공백 구분): `2026-10-08T09:12:03+09:00 green v2.19.0 8086 READY`

- 줄이 작아 `O_APPEND`로 두 JVM이 동시에 써도 줄 단위로 안전하다.
- READY 기록 시 1000줄을 넘으면 최근 1000줄만 남기고 다시 쓴다.
- 기록 실패는 기동을 막지 않는다. WARN 로그만 남긴다.

### 배포 판정 (조회 시 계산)

같은 색의 STARTED부터 다음 STARTED 전까지를 한 배포로 묶는다.

| 상태 | 조건 |
|---|---|
| 실행 중 | READY 있음 · STOPPED 없음 · 현재 응답 중인 인스턴스와 같은 색·시작 시각 |
| 종료 | READY 후 STOPPED |
| 실패 | READY 없이 STOPPED, 또는 READY 없이 같은 색의 다음 STARTED/반대 색 READY가 온 경우 |
| 기동 중 | READY 없음 · 이후 이벤트 없음 |

## 6. 관리자 API

모두 `/admin/logs/**` — 관리자 세션 필요(기존 SecurityConfig). `@LogMonitoring`은 붙이지 않는다(로그 조회가 로그를 덮는다). JSON API는 GlobalExceptionHandler `assignableTypes`에 등록해 JSON 에러를 낸다.

| 메서드 · 경로 | 기능 |
|---|---|
| `GET /admin/logs/api/instance` | 현재 인스턴스 정보 + 반대 색 폴더 마지막 수정 시각 |
| `GET /admin/logs/api/tail?path=&offset=&lines=` | 기존 tail. `path` 기본값 `{내 색}/elum.log` |
| `GET /admin/logs/api/files` | 폴더별(내 색·반대 색·이전 형식) 파일 목록 · 폴더 합계 · 전체 용량. 각 파일에 `inUse` 표시 |
| `GET /admin/logs/download?path=` | 파일째 다운로드(`Content-Disposition: attachment`, 스트리밍). `.gz`는 그대로 |
| `GET /admin/logs/api/search?path=&level=&q=&limit=` | `.gz` 포함 검색. 타임스탬프로 시작하지 않는 줄은 앞 항목에 붙여 스택트레이스를 한 건으로 묶는다. 최신 순 최대 500건(기본 200) |
| `DELETE /admin/logs/api/files?path=` | 삭제. **내 색의 `elum.log`·`elum-error.log`는 거부(409)** |
| `GET /admin/logs/api/deploys` | 배포 이력(5절 판정 적용), 최신 순 |
| `GET /admin/logs/api/levels` | 주요 로거 + 런타임에 바꾼 로거의 설정 레벨·실효 레벨 |
| `PUT /admin/logs/api/levels` | `{logger, level}` — `TRACE/DEBUG/INFO/WARN/ERROR/OFF` 또는 `null`(yml 값으로 되돌림). 응답 중인 인스턴스에만 적용 |
| `GET /admin/logs/api/errors` | 최근 ERROR 50건(시각·로거·메시지 첫 줄·예외 클래스) · 24시간 건수 · 집계 시작 시각 |

주요 로거 목록: `ROOT`, `com.chuseok22`, `org.springframework.web.servlet.DispatcherServlet`, `org.hibernate.SQL`, `org.hibernate.orm.jdbc.bind`.

### 경로 보안 (LogPathResolver)

- `path`는 `{blue|green|local}/{파일명}` 또는 이전 형식 `{파일명}`만 허용.
- 파일명 패턴: `^elum(-error)?(\.\d{4}-\d{2}-\d{2}\.\d+)?\.log(\.gz)?$`, 이전 형식 `^elum-server(\.\d{4}-\d{2}-\d{2}\.\d+)?\.log(\.gz)?$`.
- `logs` 기준 `resolve().normalize()` 결과가 `logs` 밖이면 거부. 심볼릭 링크는 따라가지 않는다(`NOFOLLOW_LINKS`).
- `deploy-history.log`는 다운로드만 허용, 삭제 불가.

### 에러 코드

| 코드 | HTTP | 상황 |
|---|---|---|
| `INVALID_LOG_PATH` | 400 | 패턴 밖 · 폴더 밖 경로 |
| `LOG_FILE_NOT_FOUND` | 404 | 없는 파일 |
| `LOG_FILE_IN_USE` | 409 | 현재 쓰는 파일 삭제 시도 |
| `INVALID_LOG_LEVEL` | 400 | 알 수 없는 레벨 · 빈 로거 이름 |
| `LOG_FILE_READ_FAILED` | 500 | 기존. 읽기 실패 |
| `LOG_FILE_DELETE_FAILED` | 500 | 삭제 IO 실패 |

### RecentErrorAppender

- logback `AppenderBase`, ERROR 이벤트만. 최근 50건 링 버퍼 + 24시간 집계용 시각 큐(최대 10,000개).
- 정적 싱글턴 저장소(`RecentErrorStore`)에 쓰고 API는 그 저장소를 읽는다(logback이 Spring보다 먼저 뜨기 때문).
- 재시작 시 초기화된다. 화면에 "집계 시작: 서버 시작 시각"을 함께 보여 오해를 막는다. 기록 자체는 `elum-error.log`에 남는다.

## 7. 화면

`logs.html`을 탭 5개로 재구성. daisyUI 기존 스타일을 따른다.

- **상단 카드**: "지금 응답 중 **green** · v2.19.0 · 10/08 09:12 시작 · 포트 8086" / 반대 색 "직전 배포 blue · 마지막 기록 10/07 18:40" / 24시간 ERROR 건수.
- **실시간**: 기존 tail. 대상 선택(내 색·반대 색 × `elum.log`·`elum-error.log`), 레벨 필터(전체·WARN+·ERROR, 클라이언트 측), 키워드 하이라이트, ERROR 빨강·WARN 노랑 표시, [현재 파일 다운로드].
- **파일**: 폴더별 표(이름·크기·수정 시각) + [다운로드][열기→검색 탭][삭제(확인 창)], 사용 중 파일은 삭제 버튼 비활성. 폴더 합계·전체 용량.
- **검색**: 파일 · 레벨 · 키워드 · 건수. 결과 항목별 접기(스택트레이스). 0건이면 빈 상태 카드.
- **배포 이력**: 시각 · 색 · 버전 · 상태 배지(실행 중·종료·실패·기동 중). 실패 행 [로그 보기] → 검색 탭에 해당 색 `elum.log` + 해당 시각 이후로 연다.
- **레벨**: 주요 로거별 현재 레벨 select, 패키지 직접 입력 추가, [원래대로]. 안내 "응답 중인 서버에만 적용되고, 재배포하면 원래 값으로 돌아가요."
- **사이드바**: "서버 로그" 옆 24시간 ERROR 건수 배지(0이면 숨김). 레이아웃 공통 스크립트가 `api/errors`를 1회 조회.
- **대시보드**: "최근 오류" 카드(건수 + 최근 5건) → 클릭 시 로그 화면.

### 실패 경로

- API 실패: 토스트 + 에러 코드(`LOG_FILE_NOT_FOUND` 등) 표시. 탭 내용은 유지.
- 폴링 실패: 화면 유지, 상태 배지 "연결 끊김", 다음 폴링에서 자동 복구. 세션 만료(로그인 페이지 응답)는 기존 처리 유지.
- 폴더·파일 없음(첫 배포 직후 반대 색 등): 빈 상태 카드 "아직 기록이 없어요".
- 배지 조회 실패: 배지만 숨기고 콘솔 경고.

## 8. 코드 구성

```
admin/application/
  controller/ AdminLogController(SSR, 다운로드 포함) · AdminLogApiController(JSON)
  service/    AdminLogService(tail·목록·삭제·다운로드) · AdminLogSearchService · AdminLogLevelService · DeployHistoryService
  dto/response/ LogTailResponse · LogFileListResponse · LogSearchResponse · DeployHistoryResponse · LoggerLevelResponse · RecentErrorsResponse · LogInstanceResponse
common/infrastructure/logging/
  LogPathResolver · LogInstanceInfo · DeployHistoryRecorder · RecentErrorAppender · RecentErrorStore
```

## 9. 테스트

단위(임시 폴더, `@TempDir`)

- `LogPathResolver`: `../`, 절대경로, 패턴 밖 이름, 심볼릭 링크 거부 · 정상 경로 허용
- 삭제: 내 색 `elum.log`/`elum-error.log` → `LOG_FILE_IN_USE`, 반대 색·`.gz` → 성공, `deploy-history.log` → 거부
- 검색: 평문·`.gz`, 스택트레이스 묶음, 레벨 필터(WARN+ 포함관계), 키워드, limit·최신 순
- 배포 이력: 파싱(깨진 줄 무시), 상태 판정 4종, 1000줄 자르기
- `RecentErrorStore`: 50건 상한, 24시간 경계
- 레벨: 알 수 없는 레벨 거부, `null`로 되돌림

웹

- 비로그인 요청 → 로그인 리다이렉트/401
- JSON API 에러가 JSON으로 나오는지

실측(배포 후 운영)

- 상단 카드 색·버전이 nginx 활성 포트와 일치
- `deploy-history.log`에 이번 배포 STARTED·READY, 옛 컨테이너 STOPPED
- 파일 다운로드(평문·`.gz`), 사용 중 파일 삭제 409
- 레벨 변경 후 DEBUG 줄이 사라졌다 돌아오는지
- 사이드바 ERROR 배지

## 10. 영향 · 주의

- 첫 배포 직후 반대 색 폴더는 비어 있다(정상).
- 기존 `logs/elum-server*.log`는 자동 삭제하지 않는다. 필요하면 화면에서 지운다.
- 워크플로 변경 전 이미지(옛 코드)는 `ELUM_INSTANCE`를 무시하고, 새 코드가 `ELUM_INSTANCE` 없이 뜨면 `local/`에 쓴다 — 어느 순서로 반영돼도 서버는 뜬다.
- 운영 서버는 하나뿐이라 실측이 곧 운영 확인이다.

## 11. 구현하며 바꾼 것

- **삭제 금지 범위를 넓혔다** — 색과 무관하게 `elum.log` · `elum-error.log`는 지우지 않는다. 배포 중에는 반대 색 JVM도 자기 파일에 쓰고 있어, 지우면 그 JVM의 이후 로그가 사라진다. 롤링된 `.gz`와 이전 형식만 지운다.
- **관리자 로그 조회가 로그를 덮지 않게 했다** — 운영은 `DispatcherServlet: DEBUG`라 2초 폴링마다 두 줄이 쌓였다. `/admin/logs/api/**` GET 요청 동안 MDC 표시를 걸고 logback TurboFilter가 WARN 미만을 버린다. 삭제·레벨 변경(DELETE·PUT)은 감사 기록으로 남긴다. 실시간 탭이 안 보이거나 창이 뒤로 가면 폴링을 쉰다.
- **hibernate TRACE** — 운영 로그 1000줄 중 바인딩 줄이 0줄이었다. `org.hibernate.type.descriptor`는 Hibernate 6에서 쓰이지 않는 로거라 지금도 아무것도 찍지 않는다. 운영 yml은 GitHub Secret이라 건드리지 않고, 레벨 탭에 실제 바인딩 로거(`org.hibernate.orm.jdbc.bind`)를 넣었다.
- 다운로드는 JSON 에러를 내도록 API 컨트롤러(`/admin/logs/api/download`)에 두고, 요청 시점 크기만큼만 보낸다(기록 중 파일이 자라 Content-Length와 어긋나지 않게).
- 배포 이력 시각은 0초도 찍는다(`11:47:00+09:00`). `OffsetDateTime.toString()`은 0초를 뺀다.
- 오류 집계 시작 시각은 JVM 시작 시각이다(저장소 클래스가 처음 로드된 시각이 아니다).
