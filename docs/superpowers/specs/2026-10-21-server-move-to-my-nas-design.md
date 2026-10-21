# 이룸 서버를 내 NAS 로 이사 — 1단계: 미러 서버 띄우기

## 왜

- 운영 서버가 친구 NAS(`chuseok22.synology.me`)에 있어 장애가 나도 들어가 볼 수 없다. 컨테이너·로그를 배포 로그로만 추측한다.
- 실사용자가 있는 앱이라 한 번에 옮기지 않고, 내 NAS 에 같은 서버를 먼저 띄워 실제 앱으로 검증한 뒤 넘긴다.

## 단계

| 단계 | 내용 | 이 문서 |
|---|---|---|
| 1 | 내 NAS 에 미러 서버를 띄운다. 운영 DB·파일 사본으로 돌고, 테스트 빌드 개발자 도구로만 붙는다 | ✅ |
| 2 | 전환: 친구 서버 최소 버전 올림(옛 앱 강제 업데이트) > 최종 동기화 > 새 주소 앱 배포 | 별도 설계 |
| 3 | 파일 저장소를 MinIO 로 바꾼다 (저장소 인터페이스 4개에 구현체 추가) | 별도 설계 |

친구 서버와 `api.elum.chuseok22.com` 은 1·2단계 동안 그대로 둔다.

## 확인한 사실 (2026-10-21)

| 항목 | 친구 서버(운영) | 내 NAS |
|---|---|---|
| DB | PostgreSQL 17.10, `elum` 14MB, Flyway 52 | 기존 `postgres` 컨테이너는 14 → **쓰지 않는다** (17 덤프 복원 불가) |
| Redis | `chuseok22.synology.me:6379` (캐시) | 이룸 전용 컨테이너 새로 |
| 파일 | `/volume1/project/elum/server` → 컨테이너 `/app` (그림·음성·로그) | 같은 경로로 만든다 |
| 이미지 | Docker Hub `chuseok22/elum-back:main` (공개) | 같은 이미지를 pull |
| 자원 | — | 메모리 가용 약 5.5GB, 디스크 11TB 여유, 8085·8086 비어 있음 |

이미지 저장: MinIO 를 쓰지 않는다. `LocalFile*Storage` 4개(카드 그림·음성·이야기 그림·공지 그림)가 `/app/data/` 아래 파일로 저장한다.

## 구성

```
내 NAS
├── docker network: elum-net
│   ├── elum-postgres  (postgres:17, 볼륨 /volume1/project/elum/postgres)
│   ├── elum-redis     (redis:7, 비밀번호, 캐시라 영속 안 함)
│   └── elum-back-mirror (chuseok22/elum-back:main, 호스트 8085 → 8080)
└── /volume1/project/elum/server  → /app
    ├── config/application-prod.yml   미러 전용 덮어쓰기 설정 (WORKDIR /app 이라 Spring 이 자동으로 읽음)
    ├── data/                          친구 서버에서 복사
    └── logs/
```

- 이미지 안 `application-prod.yml`(운영 값)은 그대로 두고, `/app/config/application-prod.yml` 이 **바꿀 키만** 덮어쓴다: DB·Redis 주소와 계정, FCM 키 경로(없는 파일).
- DB·Redis 는 호스트 포트를 열지 않는다. `elum-net` 안에서만 접근한다.
- 암호화 마스터키(`elum.secret.master-key`)는 운영과 같은 값을 쓴다. 다르면 DB 에 암호화 저장된 SMTP 비밀번호 등을 못 읽는다.

## 동기화 (친구 > 내 NAS, 덮어쓰기)

`server/tool/nas-mirror/` 스크립트, 내 NAS 에서 실행.

1. 미러 서버 중지
2. DB: `postgres:17` 일회용 컨테이너로 친구 DB `pg_dump` > `elum-postgres` 의 `elum` DB 를 지우고 복원
3. 안전 처리 SQL: 신고 메일 끄기 (아래)
4. 음성: 옮기지 않는다. `routine_step.speech_path` 를 비워 `RoutineStepSpeechSweeper` 가 Supertonic(내 AI 서버, 비용 없음)으로 다시 만든다. 2026-10-21 기준 364건, 약 20분
5. 그림: 친구 NAS `data/` 를 rsync, `routine-speech/` 제외 (받을 방법은 2단계 전환 때 정한다 — 그 전까지 이 단계는 건너뛴다)
6. 미러 서버 시작 > `/healthz` 확인

미러 서버를 아무도 운영으로 쓰지 않는 동안만 덮어쓰기가 안전하다. 2단계 전환 뒤에는 이 스크립트를 쓰지 않는다.

## 테스트 서버 안전 정책 (사용자 승인)

DB 사본에 실사용자 푸시 토큰·이메일이 그대로 있다.

| 기능 | 미러 서버 | 방법 |
|---|---|---|
| 푸시 | **끈다** | FCM 키 경로를 없는 파일로 → `NoOpPushSender` (빈 값은 이미지 안 기본 키로 바뀌어 켜진다). 기동 후 켜져 있으면 미러를 멈춘다 |
| 신고 메일 | **끈다** | 복원 직후 시스템 설정의 신고 메일 켜기 값을 끈다 |
| AI | 켠다 | 직접 누를 때만 비용이 난다 |

## 주소

- 1단계 접속: 사용자 도메인(예: `api.elum.suhsaechan.kr`) > DSM 리버스 프록시 > 8085, Let's Encrypt.
- 도메인이 정해지기 전에는 NAS 안에서 `curl 127.0.0.1:8085/healthz` 로만 확인한다.
- 앱: 개발자 도구 서버 주소 직접 입력으로 붙는다. 주소가 정해지면 목록에 넣는다.

## 하지 않는 것

- 운영 배포 워크플로(`PROJECT-SPRING-CICD.yaml`)는 건드리지 않는다. 미러는 NAS 스크립트로 같은 이미지를 받아 띄운다.
- 실시간 DB 복제(logical replication)는 하지 않는다. 친구 PostgreSQL 설정 변경이 필요해 과하다.
- MinIO 전환은 3단계에서 따로 한다.
- 내 NAS 기존 `postgres`·`redis` 컨테이너는 건드리지 않는다.

## 실패 경로

| 상황 | 동작 |
|---|---|
| 친구 DB 덤프 실패 | 복원 단계로 가지 않는다. 기존 미러 DB 유지, 미러 서버 다시 시작 |
| 복원 실패 | 스크립트 중단, 로그 남김. 다음 동기화로 다시 |
| 미러 서버 헬스체크 실패 | 컨테이너 로그 마지막 200줄 출력 |
| 파일 미동기화 | 그림 조회가 404 → 앱은 대체 그림을 보여 준다 |

## 사용자에게 남은 일

1. 새 서버 도메인 이름과 DNS 관리 위치
2. 친구 NAS 의 그림 폴더를 받을 방법 (2단계 전환 때 정함)
