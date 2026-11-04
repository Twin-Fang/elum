# 친구 서버 배포 안정화 (#1052) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 친구 서버 blue/green 배포가 nginx 어긋남·동시 실행·전환 검증 실패에서 서비스를 끊지 않게 하고, 운영 도메인 장애를 10~20분 안에 알린다.

**Architecture:** `PROJECT-SPRING-CICD.yaml` 배포 스크립트 안의 "새 색 고르기"를 함수 하나로 모아 실행 중 컨테이너와 교차 확인한다. 전환 검증을 NAS 안 nginx 경로로 하고 실패하면 되돌린다. 감시는 별도 예약 워크플로다.

**Tech Stack:** GitHub Actions, bash(appleboy/ssh-action 원격 스크립트), Docker, DSM nginx, Discord 웹훅

**Spec:** `docs/superpowers/specs/2026-11-04-elum-server-cutover-design.md` [A] 절

## Global Constraints

- 운영 배포 워크플로라 이 변경이 `main` 에 들어가면 다음 서버 배포부터 바로 쓰인다. 운영에서 일부러 실패를 만드는 시험은 하지 않는다.
- 기존 동작 유지: 허용 브랜치 규칙, 헬스체크 120회, nginx 백업·`nginx -t`·reload 실패 복구, 장애 알림 job, 이미지 정리, 백업 10개 보존.
- 출력 문구는 기존 스크립트와 같은 한국어 `echo` 형식. 주석은 한국어 한 줄 머리글.
- 포트: BLUE 8085, GREEN 8086. 도메인 `api.elum.chuseok22.com`.
- 비밀값(`$PW`, 웹훅 주소)을 출력하지 않는다.

## Review Focus

1. nginx 가 없는 색을 가리킬 때(오늘 장애): 실행 중인 반대 색을 새 색 통과 전에 지우면 안 된다 → Task 1 테스트 `drift_keeps_running_color`.
2. 두 색 모두 실행 중인데 nginx 가 한쪽을 가리킴: 기존처럼 반대 색에 배포 → Task 1 테스트 `normal_both_running`.
3. 컨테이너가 있지만 멈춘 상태(exited): 실행 중이 아닌 것으로 본다 → Task 1 테스트 `stopped_counts_as_missing`.
4. NAS 에서 공인 도메인으로 되돌아오는 연결(hairpin)이 막힌 환경: 공인 주소 검증만 실패해도 되돌리면 안 된다 → Task 2 의 검증은 로컬 경로 또는 공인 주소 중 하나만 통과하면 성공.
5. 배포 두 개가 겹침: 두 번째는 기다린다 → Task 1 의 `concurrency` (워크플로 문법 검사로 확인).

---

### Task 1: 새 색 고르기 함수 + 동시 실행 금지

**Files:**
- Modify: `.github/workflows/PROJECT-SPRING-CICD.yaml` (최상위 `concurrency` 추가, 배포 스크립트 157~214행 부근 "활성 포트 → 새 색" 구간)
- Create: `server/tool/deploy-check/decide-new-color.test.sh`

**Interfaces:**
- Produces: 배포 스크립트 안 bash 함수 `decide_new_color ACTIVE_PORT BLUE_PORT GREEN_PORT IS_BLUE_RUNNING IS_GREEN_RUNNING` → 표준출력 한 줄 `NEW_PORT NEW_COLOR OLD_COLOR STATE` (`STATE` ∈ `normal` | `drift` | `none-running`). `IS_*_RUNNING` 은 `1`/`0`.
- 함수는 `# >>> decide-new-color` 와 `# <<< decide-new-color` 줄 사이에 둔다 (테스트가 이 표식으로 뽑아 쓴다).

- [ ] **Step 1: 테스트 작성** `server/tool/deploy-check/decide-new-color.test.sh`

워크플로 파일에서 표식 사이를 뽑아 `source` 한 뒤 아래를 확인한다. 실패하면 종료 코드 1.

```bash
assert_decision "8085 8085 8086 1 0" "8086 green blue normal"        # normal_blue_active
assert_decision "8086 8085 8086 0 1" "8085 blue green normal"        # normal_green_active
assert_decision "8085 8085 8086 1 1" "8086 green blue normal"        # normal_both_running
assert_decision "8085 8085 8086 0 1" "8085 blue green drift"         # drift_keeps_running_color (2026-11-04 장애)
assert_decision "8086 8085 8086 1 0" "8086 green blue drift"         # drift_reverse
assert_decision "8085 8085 8086 0 0" "8085 blue green none-running"  # none_running
```

`stopped_counts_as_missing` 는 함수 밖(실행 중 판정)이라 Step 3 의 판정 명령이 `docker ps`(실행 중만)를 쓰는지 테스트에서 워크플로 본문을 grep 으로 확인한다: `docker ps --format` 이 있고 판정 줄에 `-a` 가 없어야 한다.

- [ ] **Step 2: 실패 확인**

Run: `bash server/tool/deploy-check/decide-new-color.test.sh`
Expected: FAIL (표식이 아직 없음)

- [ ] **Step 3: 워크플로 수정**

- 최상위(`on:` 아래)에 `concurrency: { group: elum-server-deploy, cancel-in-progress: false }`.
- `decide_new_color` 함수를 표식 사이에 정의. 규칙: conf 색이 실행 중이면 `normal`(새 색 = 반대), 아니고 반대 색이 실행 중이면 `drift`(새 색 = conf 색), 둘 다 아니면 `none-running`(새 색 = conf 색).
- 활성 포트 검증 뒤 `IS_BLUE_RUNNING`/`IS_GREEN_RUNNING` 을 `sudo docker ps --format '{{.Names}}' | grep -qx` 로 구하고 함수 결과로 `PORT`, `CONTAINER_NAME`, `OLD_CONTAINER_NAME` 을 정한다 (기존 206~214행 if 블록 대체).
- `STATE` 가 `drift` 면 `[경고] nginx(${ACTIVE_PORT}) 가 멈춘 색을 가리킴 -> 그 색을 다시 띄워 복구, 실행 중인 ${OLD_CONTAINER_NAME} 은 검증 뒤 정리` 를 남긴다.
- 배포 시작과 끝에 한 줄 요약: `[상태] nginx=${포트} 실행중=${컨테이너 목록}`.

- [ ] **Step 4: 통과 확인**

Run: `bash server/tool/deploy-check/decide-new-color.test.sh`
Expected: `PASS 7` (6개 결정 + 실행 중 판정 1개)

- [ ] **Step 5: 커밋** (`/pro-commit`, 바꾼 두 파일만)

### Task 2: 전환 검증 실패 시 되돌림

**Files:**
- Modify: `.github/workflows/PROJECT-SPRING-CICD.yaml` (340~365행 부근 "도메인 접근 검증 ~ 이전 컨테이너 정리")
- Modify: `server/tool/deploy-check/decide-new-color.test.sh` (본문 검사 추가)

**Interfaces:**
- Consumes: Task 1 의 `PORT`, `CONTAINER_NAME`, `OLD_CONTAINER_NAME`, 기존 `BACKUP_FILE`

- [ ] **Step 1: 테스트 추가** — 워크플로 본문 검사 2개

```bash
assert_contains '--resolve "${DOMAIN}:443:127.0.0.1"'      # verify_uses_local_nginx_path
assert_not_contains '도메인 접근 검증 실패: 배포 진행'          # verify_failure_is_not_ignored
```

- [ ] **Step 2: 실패 확인** — Run: `bash server/tool/deploy-check/decide-new-color.test.sh` / Expected: 위 2개 FAIL

- [ ] **Step 3: 워크플로 수정**

- 검증 루프(10회, 2초)에서 한 번이라도 `curl -fsS --max-time 5 --resolve "${DOMAIN}:443:127.0.0.1" "https://${DOMAIN}/healthz"` 또는 기존 공인 주소 `curl -fsS --max-time 5 "https://${DOMAIN}/healthz"` 가 성공하면 통과.
- 실패하면: `[오류] 전환 뒤 도메인 검증 실패 -> nginx 되돌림, 새 컨테이너 제거, ${OLD_CONTAINER_NAME} 유지` > 백업 복원 > `nginx -t` > reload(실패 시 restart) > 새 컨테이너 `docker rm -f` > `exit 1` (기존 장애 알림 job 이 알린다).
- 이전 컨테이너 정리는 검증 통과 뒤에만 실행되는 위치를 유지한다.

- [ ] **Step 4: 통과 확인** — Run: `bash server/tool/deploy-check/decide-new-color.test.sh` / Expected: `PASS 9`

- [ ] **Step 5: 워크플로 문법 검사** — Run: `actionlint .github/workflows/PROJECT-SPRING-CICD.yaml` (없으면 `python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" <파일>`) / Expected: 오류 없음

- [ ] **Step 6: 커밋** (`/pro-commit`)

### Task 3: 운영 도메인 외부 감시

**Files:**
- Create: `.github/workflows/PROJECT-ELUM-UPTIME-CHECK.yaml`

**Interfaces:**
- Consumes: Secret `DISCORD_INCIDENT_WEBHOOK_URL` (기존, 비면 알림만 건너뜀)

- [ ] **Step 1: 워크플로 작성**

- `on: schedule: '*/10 * * * *'` + `workflow_dispatch`. `concurrency: { group: elum-uptime-check, cancel-in-progress: true }`.
- 대상 2개를 matrix 로: `{name: 운영(친구 서버), url: https://api.elum.chuseok22.com/healthz}`, `{name: 새 서버(내 NAS), url: https://api.elum.suhsaechan.kr/healthz}`. `fail-fast: false`.
- 단계: `curl -fsS --max-time 10` 실패 시 60초 뒤 한 번 더. 두 번 다 실패하면 `**[ELUM 장애] {name} 응답 없음**\n시각 (KST)\n주소\nHTTP 코드\n실행 기록` 을 기존 `notify-deploy-failure` 와 같은 jq + curl 형식으로 보낸다 (멘션 없음, 웹훅 주소 출력 안 함). 웹훅이 비면 `::warning::` 만 남긴다. 장애면 job 을 실패로 끝내 Actions 화면에도 보이게 한다.

- [ ] **Step 2: 문법 검사** — Run: `actionlint .github/workflows/PROJECT-ELUM-UPTIME-CHECK.yaml` / Expected: 오류 없음

- [ ] **Step 3: 커밋** (`/pro-commit`)

### 마무리

- [ ] 브랜치 푸시 (사용자 요청 시) > develop 반영 > 다음 서버 배포 로그에서 `[상태]` 줄·검증 통과 확인 (`/pro-github` actions joblog)
- [ ] 감시 워크플로는 `main` 에 들어간 뒤 예약 실행 1회를 Actions 화면에서 확인
- [ ] `/pro-report` 로 #1052 보고서
