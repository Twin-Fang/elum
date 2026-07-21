# GitHub Release에 APK 첨부 — 설계

> **검증 노트 (2026-07-22)**: `pull_request_target` 트리거는 워크플로우 코드를 PR head가 아닌
> PR 오픈 시점의 base(main)에서 로드한다. 이 때문에 워크플로우 파일 자체를 고치는 배포는
> 그 배포 자체에는 수정 전 코드로 실행되고, 수정 효과는 다음 배포부터 나타난다.
> v1.0.85(기능 추가), v1.0.87(#118 버그 수정) 모두 이 특성으로 "수정을 반영하는 배포"에서는
> 검증되지 못했다. 이 커밋은 v1.0.87 수정이 main에 반영된 뒤 다음 배포를 트리거해
> 실제로 APK가 Release에 첨부되는지 확인하기 위한 것이다.

## 배경

`PROJECT-COMMON-RELEASE-CHANGELOG.yaml`의 `merge-and-deploy` job은 develop→main 릴리스 PR을 머지한 뒤
`git tag v$VERSION`으로 태그만 생성한다. GitHub Release는 만들지 않는다.

APK 빌드/배포는 별도 워크플로우인 `PROJECT-FLUTTER-ANDROID-FIREBASE-CICD.yaml`이 main push 시 트리거되어
Firebase App Distribution에 올리고 있으나, 이 APK는 GitHub Release에는 첨부되지 않는다.

원하는 것: main 릴리스 시 태그뿐 아니라 **GitHub Release**도 함께 생성하고, 거기에 **APK 파일**과
**해당 버전의 CHANGELOG 노트**를 첨부한다.

## 목표

- `merge-and-deploy` job의 "릴리스 태그 생성" 스텝 직후, 같은 job 안에서 이어서 실행
- 태그·버전 정보를 그대로 재사용 (재계산 최소화)
- Release 노트는 `CHANGELOG.md`에서 해당 버전 섹션만 추출해서 사용 (기존 `changelog_manager.py export` 재사용)
- Flutter(client)가 프로젝트에 포함된 경우에만 APK를 빌드해 첨부. 포함되지 않으면 APK 없이 Release만 생성
- APK 빌드나 Release 생성이 실패해도 워크플로우 전체는 성공 처리 (태그/배포는 이미 끝난 뒤이므로 핵심 파이프라인을 막지 않음)

## 비목표

- 기존 `PROJECT-FLUTTER-ANDROID-FIREBASE-CICD.yaml`(Firebase App Distribution 배포)은 건드리지 않는다.
  두 워크플로우는 서로 독립적으로 APK를 각각 빌드한다 (빌드 중복은 있으나 워크플로우 간 결합도를 낮추기 위한 의도적 선택).
- iOS 빌드/첨부는 다루지 않는다.
- AAB 첨부는 다루지 않는다 (APK만).

## 변경 위치

`.github/workflows/PROJECT-COMMON-RELEASE-CHANGELOG.yaml` → `merge-and-deploy` job

기존 스텝 순서:
1. 저장소 체크아웃
2. Git 설정
3. PR 브랜치 최신화 (머지)
4. PR 자동 병합
5. **릴리스 태그 생성** ← 이 다음에 신규 스텝 삽입
6. 배포 완료 알림

## 신규 스텝

### 1. `APK 빌드 (release용)`

- 조건: `needs.detect-and-parse.outputs.project_types`에 `flutter`가 포함된 경우에만 실행
- `continue-on-error: true`
- Flutter/Java 셋업 (Firebase 워크플로우와 동일 버전 변수 사용)
- `version_manager.sh get-code`로 `VERSION_CODE` 재계산 (이 job에는 아직 없음)
- Keystore, `key.properties`, `google-services.json`, `.env` 생성 — Firebase 워크플로우와 동일한 시크릿 재사용
  (`RELEASE_KEYSTORE_BASE64`, `RELEASE_KEYSTORE_PASSWORD`, `RELEASE_KEY_ALIAS`, `RELEASE_KEY_PASSWORD`,
  `GOOGLE_SERVICES_JSON`, `CLIENT_ENV_FILE`/`ENV_FILE`/`ENV`)
- `flutter build apk --release --build-name=$VERSION --build-number=$VERSION_CODE`
- 산출물 경로: `client/build/app/outputs/flutter-apk/app-release.apk`

### 2. `릴리스 노트 추출`

- `continue-on-error: true`
- `python3 ./.github/scripts/changelog_manager.py export --version $NEW_VERSION --output release_notes.txt`
- 추출 실패 시 `"v$NEW_VERSION"` 같은 최소 텍스트로 폴백 (기존 Firebase 워크플로우의 폴백 패턴과 동일)

### 3. `GitHub Release 생성`

- `continue-on-error: true`
- `_GITHUB_PAT_TOKEN`으로 인증
- APK 빌드 스텝이 성공했으면 APK를 첨부, 실패/스킵이면 노트만으로 Release 생성
  ```bash
  if [ -f client/build/app/outputs/flutter-apk/app-release.apk ]; then
    gh release create "$TAG_NAME" client/build/app/outputs/flutter-apk/app-release.apk \
      --title "$TAG_NAME" --notes-file release_notes.txt
  else
    gh release create "$TAG_NAME" \
      --title "$TAG_NAME" --notes-file release_notes.txt
  fi
  ```
- 이미 같은 태그로 Release가 존재하면 (재실행 등) 스킵하고 경고만 남김

## 실패 처리

- 각 신규 스텝은 `continue-on-error: true`로 격리 — 실패해도 job 자체는 `success`로 끝난다
- 실패 시 로그에 명확한 경고 메시지를 남겨 원인 추적 가능하게 한다
- "배포 완료 알림" 스텝에서 Release/APK 첨부 성공 여부도 함께 요약 출력

## 영향 범위

- 수정 파일: `.github/workflows/PROJECT-COMMON-RELEASE-CHANGELOG.yaml` (신규 스텝 3개 추가)
- 신규 시크릿 요구 없음 (기존 Firebase 워크플로우가 쓰는 시크릿을 재사용)
- 기존 태그 생성/PR 머지/배포 트리거 로직은 변경 없음
