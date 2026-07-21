📝 현재 문제점
---

- #114에서 추가한 "APK 빌드 (release용)" 스텝이 `working-directory: client`에서 실행되는데, 그 안에서 `version_manager.sh get-code`를 호출하면 스크립트가 현재 작업 디렉토리(`client/`) 기준으로 `version.yml`을 찾다가 실패한다.
- `version.yml`은 레포 루트에만 있어서 `❌ version.yml 파일을 찾을 수 없습니다!`로 즉시 종료(exit 1)되고, `flutter build apk`까지 도달하지 못한다.
- 스텝이 `continue-on-error: true`라 워크플로우 자체는 성공으로 표시되어 실패가 눈에 띄지 않았다.
- 실제로 v1.0.86 배포에서 GitHub Release는 생성됐지만 APK가 첨부되지 않고 "APK 없음"으로 마무리됐다.

🛠️ 해결 방안 / 제안 기능
---

- `version_manager.sh get-code` 호출을 레포 루트 기준 cwd에서 실행하도록 수정한다 (`cd .. && ./.github/scripts/version_manager.sh get-code`).
- 다음 배포에서 GitHub Release에 APK가 정상 첨부되는지 재확인한다.

🙋‍♂️ 담당자
---

- 백엔드: Cassiiopeia
