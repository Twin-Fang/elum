# 내 NAS 미러 서버

친구 NAS 의 운영 서버를 내 NAS 로 옮기기 전, 운영 사본으로 도는 미러 서버를 띄운다. 설계: `docs/superpowers/specs/2026-10-21-server-move-to-my-nas-design.md` (#936)

미러는 테스트 빌드 개발자 도구의 서버 주소로만 붙는다. 운영 사용자는 계속 친구 서버를 쓴다.

## 구성

| 이름 | 내용 |
|---|---|
| `elum-net` | 미러 전용 docker 네트워크. DB·Redis 는 호스트 포트를 열지 않는다 |
| `elum-postgres` | PostgreSQL 17 (원본과 같은 주 버전), `/volume1/project/elum/postgres` |
| `elum-redis` | 캐시. 영속 저장 안 함 |
| `elum-back-mirror` | 운영과 같은 이미지 `chuseok22/elum-back:main`, 호스트 8085 |
| `/volume1/project/elum/server` | 컨테이너 `/app`. `config/application-prod.yml` 이 DB·Redis·푸시만 덮어쓴다 |
| `/volume1/project/elum/mirror` | `mirror.env`(비밀값), `dumps/`(최근 5개), `bin/`(이 스크립트) |

## 미러에서 꺼 둔 것

- 푸시: FCM 키 경로를 없는 파일로 > NoOp 발송기 (빈 값은 기본 키로 바뀌어 켜진다). `run-mirror.sh` 가 기동 후 켜져 있으면 멈춘다
- 신고 메일: 동기화 때마다 `TALK_REPORT_MAIL_ENABLED=false`
- AI 는 켜 둔다 (운영 키, 직접 누를 때만 비용)

## 파일

- 그림(카드·이야기·공지)만 원본에서 받는다. OpenAI 로 만든 것이라 다시 만들면 비용이 든다
- 음성은 받지 않는다. 동기화 때 `speech_path` 를 비우면 `RoutineStepSpeechSweeper` 가 Supertonic 으로 다시 만든다 (2분마다 20건, 한 건 약 3초)

## mirror.env (root 만 읽기, 커밋 금지)

```
ELUM_DB_PASSWORD=        # 미러 DB 비밀번호 (새로 만든 값)
ELUM_REDIS_PASSWORD=     # 미러 Redis 비밀번호 (새로 만든 값)
SOURCE_DB_HOST=          # 원본 DB (운영 application-prod.yml 의 datasource)
SOURCE_DB_PORT=
SOURCE_DB_NAME=
SOURCE_DB_USER=
SOURCE_DB_PASSWORD=
SOURCE_ADMIN_BASE_URL=   # 파일 받기: 원본 서버 주소 (https://api.elum.chuseok22.com). 원본 관리자 파일 내보내기 API(#1053)를 쓴다
SOURCE_ADMIN_USERNAME=   # 원본 관리자 아이디
SOURCE_ADMIN_PASSWORD=   # 원본 관리자 비밀번호
SOURCE_SSH_TARGET=       # 선택: SSH 로 받을 때 (user@host). 관리자 API 가 있으면 쓰지 않음
SOURCE_SSH_PORT=22
SOURCE_DATA_DIR=/volume1/project/elum/server/data
```

## 쓰는 법 (NAS 에서 root)

```bash
cd /volume1/project/elum/mirror/bin
bash setup-mirror.sh        # 처음 한 번 (여러 번 돌려도 같다)
bash sync-from-source.sh    # 원본 > 미러 덮어쓰기 후 서버 다시 시작 (신고 메일 끔)
bash sync-from-source.sh --cutover   # 전환용: 운영 값 그대로, 서버는 멈춘 채 (CUTOVER.md)
bash verify-consistency.sh [--allow-live] [--skip-files]   # 원본 <-> 내 NAS DB·파일 비교, 차이가 있으면 실패
bash run-mirror.sh          # 데이터 그대로 미러만 다시 띄우기 (새 이미지 받기)
```

`sync-from-source.sh` 는 미러 DB 를 지우고 새로 넣는다. 미러에서 만든 데이터는 사라진다. 운영 전환(2단계) 뒤에는 쓰지 않는다.

## Traefik 배포로 옮긴 뒤 (#1054)

- 실행 설정은 `/volume1/project/elum/runtime-config` (컨테이너 `/app/config` 읽기 전용): 배포가 운영 설정(`APPLICATION_PROD_YML`)을 쓰고, `setup-mirror.sh` 가 DB 주소 덮어쓰기 `application-nas.yml` 을 만든다 (프로필 `prod,nas`). 미러용 `server/config` 와 따로 두는 이유: 같은 파일에 운영 설정을 쓰면 미러가 친구 서버 DB 에 붙는다
- 서버는 GitHub Actions `PROJECT-SPRING-ELUM-NAS-CICD` 가 `elum-back-blue|green` 으로 띄운다 (`mode=mirror` 는 푸시 끔). `run-mirror.sh` 의 `elum-back-mirror` 는 DSM 프록시를 8079 로 옮긴 뒤 지운다
- 파일은 `pull_files.py` 가 원본 관리자 API 로 받는다 (음성 포함, 해시 확인). 원본 `이전 파일 내보내기` 를 켜야 한다
- 전환 절차: `CUTOVER.md`
- 주기 동기화: DSM 작업 스케줄러 `elum-mirror-sync`(root, 매 30분)가 `scheduled-sync.sh` 를 부른다. 겹침 방지(`sync.lock`), 멈춤 표식 `SYNC_PAUSED`, 기록 `mirror/logs/scheduled-sync.log`

