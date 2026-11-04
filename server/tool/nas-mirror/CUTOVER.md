# 전환 절차서 (친구 서버 > 내 NAS)

설계: `docs/superpowers/specs/2026-11-04-elum-server-cutover-design.md` [E] 절 (#1054)

스크립트는 내 NAS `/volume1/project/elum/mirror/bin` 에서 root 로 돌린다 (`sudo bash <스크립트>`).
관리자 화면 = 친구 서버 `https://api.elum.chuseok22.com/admin/settings`, 내 서버 `https://api.elum.suhsaechan.kr/admin/settings`.

## 전환 전 조건 (하나라도 아니면 전환하지 않는다)

- [ ] 친구 서버에 #1053(이전 잠금·파일 내보내기)과 #831 서버 쪽이 배포됨 (설정은 전부 꺼짐)
- [ ] #831 앱 버전이 두 스토어에 출시됨, 친구 서버 `최소 버전`을 그 버전으로 올려 사용자가 업데이트함
- [ ] 내 NAS: `PROJECT-SPRING-ELUM-NAS-CICD` 를 mirror 모드로 배포 (`git push origin <친구 서버와 같은 커밋>:deploy-nas`, 워크플로가 main 에 있으면 수동 실행도 가능), 친구 서버와 **같은 커밋**
- [ ] DSM 역방향 프록시 `api.elum.suhsaechan.kr` > `localhost:8079`, `elum-back-mirror` 정리
- [ ] 내 NAS 에서 `https://api.elum.suhsaechan.kr/.well-known/apple-app-site-association` · `/.well-known/assetlinks.json` 응답 확인 (#831 앱이 새 도메인을 앱 링크로 등록하므로, 앱 출시 전에 필요)
- [ ] `mirror.env` 에 `SOURCE_ADMIN_BASE_URL` · `SOURCE_ADMIN_USERNAME` · `SOURCE_ADMIN_PASSWORD`
- [ ] 리허설 통과 (아래), 걸린 시간 기록

## 리허설 (운영 영향 없음, 몇 번이든)

친구 서버 `이전 파일 내보내기` 켬 > 내 NAS:

```bash
bash sync-from-source.sh                      # 미러 갱신 (DB·파일, 신고 메일 끔)
bash verify-consistency.sh --allow-live       # 차이는 정보로만 (원본이 살아 있어 생김)
```

테스트 빌드 개발자 도구 > 서버 직접 입력 `https://api.elum.suhsaechan.kr` > 로그인·일과·그림·이야기 확인.

## 전환 (새벽, 사용자 승인 뒤)

| 순서 | 할 일 | 실패하면 |
|---|---|---|
| 0 | 내 NAS 주기 동기화 멈춤: 내 서버 관리자 > 서버 이전 [멈춤] (= `/volume1/project/elum/server/migration-sync/SYNC_PAUSED`) | — |
| 1 | 친구 서버 `점검 모드` 켬 | — |
| 2 | 2분 대기 (진행 중 요청·작업) | — |
| 3 | 친구 서버 `이전 잠금` 켬 (토큰 갱신·예약 작업·발송 멈춤) + `이전 파일 내보내기` 켬 | 잠금·점검 끔 = 원래대로 |
| 3-1 | **60초 이상 대기** (설정 캐시 30초 + 배경 작업) | — |
| 4 | `bash sync-from-source.sh --cutover` (서버는 멈춘 채) | 잠금·점검 끔 |
| 5 | (4 에 포함) 파일 차이분 받기 | 잠금·점검 끔 |
| 6 | `bash verify-consistency.sh --status-file /volume1/project/elum/server/migration-sync/verify-status.json` **차이 0** (결과는 내 서버 관리자 > 서버 이전에도 보임) | 다르면 4 다시, 2번 연속 다르면 취소 |
| 7 | GitHub Actions `PROJECT-SPRING-ELUM-NAS-CICD` 를 `mode=production` 으로 실행 (FCM 켬) | 취소 |
| 8 | 내 서버 관리자에서 `점검 모드` 끔 (DB 복사로 켜진 채 넘어옴), `/healthz` · `/api/app/status` 확인. `새 서버 주소`가 자기 자신(`https://api.elum.suhsaechan.kr`)인지 확인 (4 가 넣음, 비어 있으면 앱이 옛 서버로 되돌아감) | 취소 |
| 9 | 친구 서버 `새 서버 주소` = `https://api.elum.suhsaechan.kr`, 친구 서버 `점검 모드` 끔 (잠금은 유지) | 잠금 끔 + 주소 비움 = 원래대로 |
| 10 | AdMob 콘솔 보상 콜백 주소를 새 도메인으로 (사람) | — |
| 11 | 내 서버 로그·관리자 화면으로 사용자 유입 확인 | — |

취소는 9 전까지 언제든 "친구 서버 잠금·점검 끔". 그때까지 앱은 친구 서버만 본다.

## 전환 뒤

- 내 NAS 배포 워크플로를 `main` 푸시로 돌게 바꾸고, 친구 서버 워크플로는 푸시 실행을 끈다 (친구 서버는 잠금 그대로)
- 다음 앱 릴리스에서 `.env` 기본 주소를 새 도메인으로
- 친구 서버 `이전 파일 내보내기` 끔, 파일 내보내기 API 제거 이슈
- `sync-from-source.sh` 는 더 쓰지 않는다 (내 NAS 가 원본이 됨). DSM 작업 스케줄러 `elum-mirror-sync` · `elum-mirror-requests` 를 삭제한다 (`SYNC_PAUSED` 는 그때까지 둔다)
- 옛 서버 안내 상태는 내 서버 관리자 > 서버 이전 > 옛 서버 칸에서 본다 (응답·점검·새 주소 안내)
