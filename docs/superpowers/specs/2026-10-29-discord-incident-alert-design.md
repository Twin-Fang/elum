# 장애 알림을 Discord 웹훅으로 보내기 (#648)

## 문제

운영 중 장애가 나도 사람이 관리자 화면을 열어야만 안다. 관리자 대시보드의 24시간 오류 수(`RecentErrorStore`)는 메모리 값이라 재시작하면 0이 된다.
5xx 급증, AI 차단(하루 비용 상한), AI 제공자 연속 실패, 서버 배포 실패를 바로 알려 줄 통로가 없다.

## 고른 안

서버와 배포 워크플로가 같은 Discord 웹훅 하나로 보낸다. 웹훅 주소는 Secret `DISCORD_INCIDENT_WEBHOOK_URL` 하나에만 둔다.

```
요청 ─ ServerErrorSurgeFilter ─ ServerErrorSurgeDetector(5분 창, 10건) ─┐
AiDailyBudgetGuard.isReached() == true ─────────────────────────────────┼─ IncidentAlertService ─ 쿨다운 ─ 전용 스레드 ─ DiscordWebhookClient
AiCallLogService.recordFailure/Success ─ AiProviderFailureAlerter(5회) ─┘        (꺼짐이면 즉시 return)
GitHub Actions build/deploy 실패 ─ notify-deploy-failure job ─ curl ─ 같은 웹훅
```

| 구성 | 위치 | 하는 일 |
|---|---|---|
| `IncidentAlertProperties` | common/infrastructure/properties | `elum.incident-alert.*` 설정, 0·음수는 기본값 |
| `IncidentAlertService` | common/application/alert | 켜짐 확인 > 쿨다운 > 문구 조립 > 단일 스레드 발송 |
| `IncidentAlertCooldown` | common/application/alert | 원인 키별 마지막 발송 시각 |
| `ServerErrorSurgeDetector` | common/application/alert | 창 안 5xx 수 집계, 기준 이상이면 대표 오류·경로 상위 3개로 묶음 |
| `ServerErrorSurgeFilter` + `IncidentAlertFilterConfig` | common/infrastructure/alert | 응답 상태·매핑 경로 템플릿·에러 코드를 판정기로 전달 |
| `DiscordWebhookClient` | common/infrastructure/alert | `{content, allowed_mentions:{parse:[]}}` POST, 5초 연결·10초 읽기 제한 |
| `AiProviderFailureAlerter` | ai/application/service | 제공자 줄(OpenAI 그림, Gemini 글 등)별 연속 실패 수 |
| `notify-deploy-failure` job | `.github/workflows/PROJECT-SPRING-CICD.yaml` | build·deploy 실패 시 1회, Secret 없으면 건너뜀 |

### 설정 키

| 키 | 환경변수 | 기본값 |
|---|---|---|
| `elum.incident-alert.discord-webhook-url` | `ELUM_INCIDENT_ALERT_DISCORD_WEBHOOK_URL` | 빈 값 (꺼짐) |
| `elum.incident-alert.admin-base-url` | `ELUM_INCIDENT_ALERT_ADMIN_BASE_URL` | `talk.admin-base-url` |
| `elum.incident-alert.server-error-threshold` | `ELUM_INCIDENT_ALERT_SERVER_ERROR_THRESHOLD` | 10 |
| `elum.incident-alert.server-error-window-seconds` | `ELUM_INCIDENT_ALERT_SERVER_ERROR_WINDOW_SECONDS` | 300 |
| `elum.incident-alert.cooldown-seconds` | `ELUM_INCIDENT_ALERT_COOLDOWN_SECONDS` | 1800 |
| `elum.incident-alert.ai-consecutive-failure-threshold` | `ELUM_INCIDENT_ALERT_AI_CONSECUTIVE_FAILURE_THRESHOLD` | 5 |

배포 워크플로가 `docker run -e ELUM_INCIDENT_ALERT_DISCORD_WEBHOOK_URL=${{ secrets.DISCORD_INCIDENT_WEBHOOK_URL }}`로 넘긴다.
사용자가 할 일은 Secret 하나 등록이다.

### 알림 본문 (서비스 원칙 5)

종류, 시각(KST), 서버(blue/green · 버전), 건수, 대표 오류(상태 코드 + `ErrorCode` 이름), 대표 경로(메서드 + 매핑 템플릿 `/api/routines/{routineId}`), 관리자 화면 링크.
실제 주소·쿼리·요청 본문·보호자 원문·AI 실패 원문·회원 id·토큰은 싣지 않는다. AI 실패는 `AiFailureKind` 분류 이름(예: 크레딧·결제)만 싣는다.

### 반복 억제

| 종류 | 원인 키 | 재발송 간격 |
|---|---|---|
| 5xx 급증 | `all` (경로별로 따로 울리지 않음) | 30분 |
| AI 하루 비용 상한 | 오늘 날짜 | 24시간 (날짜별 1회) |
| AI 제공자 연속 실패 | 제공자 줄 이름 | 30분, 성공 1건이면 수 0 |

쿨다운은 메모리 값이라 재시작하면 첫 알림이 다시 나간다. Blue/Green 두 JVM이 겹치는 동안에는 둘이 따로 셀 수 있다.

## 검토하고 버린 안

| 안 | 버린 이유 |
|---|---|
| logback ERROR 로그마다 웹훅 (`RecentErrorAppender` 확장) | 로그 문구에 원문이 섞일 수 있고 경고성 ERROR까지 울린다. 상태 코드 기준이 더 정확하다 |
| `GlobalExceptionHandler.handleException`에서만 세기 | admin(Thymeleaf)·보안 필터에서 난 5xx를 놓친다. 필터에서 응답 상태를 본다 |
| `AsyncConfig`에 알림용 Executor 빈 추가 | Executor 빈이 둘이 되면 이름 없는 `@Async`의 기본 실행기가 바뀔 수 있다. 서비스 안 전용 스레드로 둔다 |
| Spring Boot Actuator + 외부 모니터링 | 의존성·운영 구성이 늘어난다. 이번 범위는 웹훅 하나 |
| Sentry 등 SaaS | #659에서 따로 다룬다 |

## 하지 않는 것

- 웹훅 생성, Secret·운영 환경변수 등록 (사용자)
- 앱(Flutter) 배포 워크플로 실패 알림 (서버 배포만, 필요하면 같은 Secret으로 후속)
- 알림 기록 저장·관리자 화면 표시
- 503 집계: 점검 모드·AI 비용 상한·크레딧·제공자 꺼짐 같은 의도한 멈춤이다. AI 쪽은 전용 알림이 따로 있다

## 실패 경로

| 상황 | 동작 |
|---|---|
| 웹훅 주소 없음 | 기동 시 경고 1회 `[incident alert] disabled : discord webhook url is empty`, 이후 아무것도 안 함. 서버 기동은 그대로 |
| 주소가 https 아님 | 기동 시 경고 1회 후 꺼짐 |
| Discord 4xx/5xx·429 | `[incident alert] discord rejected : status=…` 경고. 본 요청과 무관 (전용 스레드) |
| 네트워크 끊김·타임아웃 | 연결 5초·읽기 10초 후 `discord send failed : error={예외 이름}` 경고. 예외 문구에 웹훅 주소가 들어가므로 문구는 남기지 않는다 |
| 발송 대기 100건 초과 | 버리고 `dropped : send queue full` 경고. 요청 스레드에서 보내지 않는다 |
| 집계·알림 코드 자체 예외 | 필터·AI 기록·비용 가드 모두 try/catch 후 경고. 응답·AI 판정은 바뀌지 않는다 |
| 앱이 연결을 끊음 (ClientAbort) | 5xx로 세지 않는다 |
| 배포 워크플로 Secret 없음 | `notify-deploy-failure`가 메시지만 남기고 성공 종료 |
| 배포 알림 curl 실패 | `::warning::` 남기고 끝. 워크플로 결과(실패)는 그대로 |

## 테스트

| 테스트 | 겨누는 결함 |
|---|---|
| `IncidentAlertServiceTest.notify_sameCauseWithinCooldown_sendsOnce` | 5xx가 이어질 때 같은 알림이 채널을 덮음 |
| `IncidentAlertServiceTest.notify_webhookUrlEmpty_disabledAndSendsNothing` | 주소 미등록 환경에서 발송 시도·예외 |
| `ServerErrorSurgeDetectorTest.record_belowThreshold_returnsNoAlert` | 오류 한두 건에 알림이 울림 |

실제 Discord 호출은 하지 않는다. 운영 시험 발송은 Secret 등록 후 사용자가 한다.
