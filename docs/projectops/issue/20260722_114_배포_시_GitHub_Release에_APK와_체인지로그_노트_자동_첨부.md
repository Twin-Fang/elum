📝 현재 문제점
---

- `PROJECT-COMMON-RELEASE-CHANGELOG.yaml`의 `merge-and-deploy` job이 develop→main 릴리스 PR 머지 후 `git tag v$VERSION`으로 태그만 생성하고, GitHub Release는 생성하지 않는다.
- APK는 별도 워크플로우(`PROJECT-FLUTTER-ANDROID-FIREBASE-CICD.yaml`)가 main push 시 빌드해 Firebase App Distribution에만 올리며, GitHub Release에는 첨부되지 않는다.
- 그 결과 배포 이력을 GitHub Release 탭에서 한눈에 확인하거나, 특정 버전의 APK를 GitHub에서 바로 내려받을 방법이 없다.

🛠️ 해결 방안 / 제안 기능
---

- 릴리스 태그 생성 직후 같은 job 안에서 이어서 GitHub Release를 생성한다.
  - Release 노트는 `changelog_manager.py export`로 `CHANGELOG.md`에서 해당 버전 섹션만 추출해 사용한다.
  - 프로젝트에 Flutter(client)가 포함된 경우에만 APK를 빌드해 Release에 첨부한다. 포함되지 않으면 노트만으로 Release를 생성한다.
- APK 빌드/Release 생성이 실패해도 태그·머지·배포는 이미 끝난 뒤이므로 워크플로우 전체를 실패 처리하지 않는다.
- 설계 상세는 `docs/superpowers/specs/2026-07-22-release-apk-github-release-design.md` 참고.

⚙️ 작업 내용
---
- `PROJECT-COMMON-RELEASE-CHANGELOG.yaml`의 `merge-and-deploy` job에 "릴리스 태그 생성" 스텝 뒤로 APK 빌드, 릴리스 노트 추출, GitHub Release 생성 스텝 추가
- 각 신규 스텝은 `continue-on-error: true`로 격리

🙋‍♂️ 담당자
---

- 백엔드: Cassiiopeia
