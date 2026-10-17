🗒️ 설명
---

**앱이 App Store에 출시(심사 승인)되면, 그 뒤부터 다음 릴리스로 버전이 올라갈 때까지 iOS 테스트 빌드가 전부 TestFlight 업로드에서 거부된다.**
IPA 빌드는 12~18분을 다 쓰고 성공한 뒤 **마지막 업로드 한 스텝에서만** 실패하고, 봇 댓글은 이유를 알려주지 않는다.

#209는 같은 Apple 정책(출시 후 해당 버전의 prerelease train이 영구 폐쇄)을 다뤘다. 그때는 테스트 빌드 버전이 `0.0.0`으로 하드코딩된 것이 원인이었고, 수정은 테스트 빌드가 `version.yml`의 현재 버전을 쓰게 하는 것이었다. **그 수정이 문제를 없앤 것이 아니라 옮겼다.** `version.yml`의 현재 값은 마지막으로 출시된 버전이라, 출시 직후부터 다음 릴리스 전까지 그 버전이 닫힌 채로 남기 때문이다.

Apple이 직접 알려주는 원인:

```
[altool] UPLOAD FAILED with 2 errors
[altool] Invalid Pre-Release Train. The train version '2.1.2' is closed for new build submissions (90186)
[altool] This bundle is invalid. The value for key CFBundleShortVersionString [2.1.2] in the Info.plist file
         must contain a higher version than that of the previously approved version [2.1.2].
[altool]    NSUnderlyingError : A server error occurred. (-19241)
```

같은 문제에서 파생돼 함께 드러난 결함이 셋 더 있다.

| # | 결함 | 영향 |
|---|---|---|
| 1 | 실패 봇 댓글에 **거부 사유가 없다** (`TestFlight 배포 중 오류가 발생했습니다`와 로그 링크뿐) | 18분 기다린 뒤 로그를 직접 열어야 원인을 안다 |
| 2 | 봇 댓글의 `커밋`이 **빌드된 커밋이 아니라 워크플로 자체의 SHA(main 끝)** 다 | 어느 코드가 빌드됐는지 오해한다 |
| 3 | 테스트 빌드 번호(이슈 번호 기반 4만대)와 릴리스 빌드 번호(카운터 200번대)가 **서로 다른 체계** | 같은 버전에서 테스트 빌드가 먼저 올라가면 뒤의 릴리스 빌드가 번호가 낮다고 거부될 수 있다(추론, 아직 발생 안 함) |

🔄 재현 방법
---

1. 앱을 App Store에 출시한다(심사 제출 후 승인, `READY_FOR_SALE`). 예: 버전 2.1.2
2. 다음 릴리스로 `version.yml`이 올라가기 전에, 이슈에 iOS 테스트 빌드 트리거 댓글을 단다(`app build <브랜치>`)
3. `테스트 빌드 준비` 성공, `iOS 테스트 빌드` 성공(IPA 생성, 약 12~18분)
4. `TestFlight 테스트 배포` 잡의 `Upload to TestFlight`에서 실패
5. 이슈에 `iOS TestFlight 배포 실패` 봇 댓글이 달리고 사유는 적혀 있지 않다

📸 참고 자료
---

실측 레포: `Twin-Fang/elum` (2026-09-29 ~ 09-30)

### 1. 실패 실행 세 건 (모두 같은 원인)

| run | 시각(UTC) | 앱 버전(빌드) | IPA 빌드 | 업로드 |
|---|---|---|---|---|
| 36644103028 | 09-29 23:14 | 2.1.2 (45102) | 11분 42초 성공 | 2분 43초 실패 |
| 36646878776 | 09-29 23:45 | 2.1.2 (45103) | 18분 42초 성공 | 3분 30초 실패 |
| 36660986019 | 09-30 02:41 | 2.1.2 (45104) | 11분 54초 성공 | 3분 8초 실패 |

실패 잡 로그(run 36660986019, job 109718495252, 실패 스텝 `Upload to TestFlight`):

```
📦 Found IPA at: /Users/runner/work/elum/elum/ios/build/ipa/elum.ipa
🔧 API_KEY_PATH: /Users/runner/.appstoreconnect/private_keys/AuthKey_***.p8
[altool] Invalid Pre-Release Train. The train version '2.1.2' is closed for new build submissions (90186)
[altool] UPLOAD FAILED with 2 errors
[!] Error uploading ipa file
##[error]Process completed with exit code 1.
```

실패 봇 댓글의 전문(사유 없음):

```
## 🍎 ❌ iOS TestFlight 배포 실패
| 🔧 준비 | ✅ 완료 | 46초 |
| 🔨 IPA 빌드 | ✅ 완료 | 11분 42초 |
| 📤 TestFlight 배포 | ❌ 실패 | 2분 43초 |
❌ **TestFlight 배포 중 오류가 발생했습니다.**
🔗 [워크플로우 실행 로그 확인](...)
```

### 2. App Store Connect 기록 (API 읽기 전용 조회)

앱 버전 상태:

| 버전 | 상태 |
|---|---|
| 2.1.2 | **READY_FOR_SALE** (releaseType AFTER_APPROVAL) |
| 1.45.0 | READY_FOR_SALE |
| 1.43.0 | READY_FOR_SALE |
| 1.24.1 | READY_FOR_SALE |

심사 제출 기록(모두 COMPLETE): 09-21 15:14, 09-24 16:15, 09-25 14:19, **09-29 13:22**. 2.1.2의 릴리스 배포(main push)는 09-29 12:39Z, 심사 제출은 13:22Z, 첫 실패는 그 뒤 23:14Z다.

TestFlight 빌드(발췌, 업로드 시각 ASC 표기):

| 버전 | 빌드 | 업로드 |
|---|---|---|
| 2.1.2 | 214 | 09-29 05:55 |
| 2.1.1 | 44402 | 09-29 05:18 |
| 2.1.1 | 213 | 09-29 05:01 |
| 1.46.0 | 43702 | 09-27 05:46 |
| 1.46.0 | 209 | 09-27 05:28 |
| 1.40.0 | 40502 | 09-23 23:14 |
| 1.40.0 | 201 | 09-23 22:44 |

거부된 45102, 45103, 45104는 목록에 없다.

### 3. 자연 실험: "같은 버전, 다른 빌드 번호"는 출시 전에는 통과했다

1.40.0, 1.46.0, 2.1.1은 **릴리스 빌드(200번대)와 테스트 빌드(4만대)가 같은 버전 이름으로 둘 다 올라갔다.** 이 세 버전은 심사 제출 기록이 없다. 반면 심사에 제출해 승인된 2.1.2는 같은 조건에서 거부됐다. 즉 "같은 버전에 빌드 번호만 올리면 된다"는 **출시 전까지만** 맞다.

### 4. 통제 시험: 버전 이름 하나만 바꿔 A/B

같은 코드(develop), 같은 워크플로, 같은 트리거에서 `version.yml`의 버전 한 줄만 바꾼 버려질 브랜치(`probe-ios-version-299`)로 iOS 테스트 빌드를 돌렸다.

| | 버전 2.1.2 | 버전 2.1.99 |
|---|---|---|
| 빌드 번호 | 45104 | 45105 (더 큼) |
| run | 36660986019 | 36665435791 |
| IPA 빌드 | 성공 | 성공 (12분 21초) |
| TestFlight 업로드 | **실패** (train 2.1.2 closed) | **성공** (7분 45초) |
| App Store Connect | 없음 | `2.1.99` 빌드 45105 `VALID` |

변수는 버전 이름 하나이고, 빌드 번호는 오히려 통과한 쪽이 더 크다. **닫힌 것은 빌드 번호가 아니라 버전 이름(train)이다.**

### 5. 원인이 되는 워크플로 부분 (elum 복사본 기준)

`PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml`
- 머리 주석: `버전은 version.yml에서 동적으로 읽어 사용 (운영 버전과 동일, 빌드 번호로 구분)`
- `테스트 빌드 버전 설정` 스텝(대략 274~303행): `version_manager.sh get`으로 읽은 값을 그대로 버전으로 쓴다. 빌드 번호는 `repository_dispatch`의 `client_payload.build_number`(이슈 번호 기반)를 쓴다. 예: 이슈 451은 45102~45105, 444는 44402, 437은 43702, 405는 40502.
- 빌드 단계(대략 679~680행): 위 두 값을 그대로 `--build-name`, `--build-number`로 넘긴다.
- 릴리스 워크플로는 `version.yml`의 `version_code`(214) 카운터를 쓴다.

### 6. 봇 댓글의 커밋 표기

4개 빌드(develop 3회, 시험 브랜치 1회)가 모두 `커밋 bb1c651`을 표시했다. `bb1c651`은 main의 끝(`elum 버전 관리 : docs : v2.1.2 README 버전 정보 업데이트 [skip ci]`)이다. 실제 체크아웃 로그는 다음과 같다.

```
ref: develop
git checkout --progress --force -B develop refs/remotes/origin/develop
```

### 7. 함께 발견한 것 (별도 이슈 후보)

- `testflight-wizard`가 만드는 `github-secrets.json`과 `.txt`가 다운로드 폴더에 **누구나 읽을 수 있는 권한(644)** 으로 남는다. 내용은 배포 인증서(base64), 인증서 암호, 프로비저닝 프로필, App Store Connect API 키(base64), 키 ID, 발급자 ID, 팀 ID, 번들 ID 9개다. 등록이 끝나면 지워야 하는데 안내나 자동 삭제가 없다.
- 로컬에서 App Store Connect 상태(버전이 출시됐는지)를 확인할 방법이 없어, 발급자 ID를 GitHub 시크릿에서 못 읽고 브라우저 세션 만료로 막혔다. CI에서 상태를 조회하는 수동 실행 작업이 있으면 좋다.

✅ 예상 동작
---

- 테스트 빌드는 **이미 출시되어 닫힌 버전 이름을 절대 쓰지 않는다.** 출시된 최대 버전보다 높을 때만 그 버전으로 빌드하고, 그렇지 않으면 다음 패치 버전 이름으로 빌드한다.
- 위 판단은 빌드를 시작하기 **전에** App Store Connect를 조회해 내린다(사전 점검). 닫힌 버전이면 12~18분 빌드 뒤가 아니라 시작 직후에 원인과 함께 알려준다.
- 실패 봇 댓글에 **Apple이 준 거부 사유**(예: `train version '2.1.2' is closed`)를 한 줄로 싣는다.
- 봇 댓글의 `커밋`은 **실제 빌드된 ref의 커밋**을 표시한다.
- 테스트 빌드와 릴리스 빌드의 빌드 번호가 같은 버전 안에서 항상 증가하도록 한 체계로 관리한다.
- Android는 `versionCode`만 증가하면 되므로 영향이 없다.

⚙️ 환경 정보
---

- **워크플로우**: `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml`, 트리거 `repository_dispatch` (이슈 댓글 빌드 트리거 경유)
- **실측 레포**: Twin-Fang/elum, 앱 버전 2.1.2(빌드 45102~45105), 2026-09-29 ~ 09-30
- **원인**: Apple 정책. 출시된 버전의 prerelease train은 새 빌드를 받지 않는다(`Invalid Pre-Release Train ... closed for new build submissions`, 90186)
- **관련 이슈**: #209(같은 정책, 하드코딩 `0.0.0`), #601(iOS 테스트 빌드 lane), TEAM-ROMROM/RomRom-FE#735

🙋‍♂️ 담당자
---

- **프론트엔드**: @Cassiiopeia
