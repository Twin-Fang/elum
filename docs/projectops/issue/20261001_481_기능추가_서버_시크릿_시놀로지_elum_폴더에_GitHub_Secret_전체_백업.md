📝 현재 문제점
---

- develop에 push하면 `PROJECT-COMMON-SECRET-FILE-UPLOAD` 워크플로우가 시놀로지로 시크릿을 백업하는데, 설정이 템플릿 기본값 그대로다.
  - `PROJECT_NAME`이 `my-project`라서 `/volume1/projects/my-project/...`에 올라간다. elum 폴더가 아니다.
  - 올리는 시크릿이 `ENV_FILE`, `APPLICATION_PROD_YML` 두 개뿐이다. 레포 시크릿은 25개인데 클라이언트 쪽(`CLIENT_ENV_FILE`, `CLIENT_ADMOB_ENV_STAGED`, 서명키, 스토어 키 등)은 백업이 없다.
- GitHub 시크릿은 값을 다시 읽을 수 없어서, 백업이 없으면 값이 틀렸는지 확인하거나 복구할 방법이 없다. 이번에 스토어 빌드가 실제 광고 단위 ID를 받는지 확인하려 했으나 볼 수 없었다.

🛠️ 해결 방안 / 제안 기능
---

- 업로드 경로를 `/volume1/projects/elum/github_secret/` 아래로 바꾼다.
- 레포의 시크릿 전체를 올린다. 서버용은 `backend`, 클라이언트용은 `client` 폴더로 나눈다.
  - backend: `ENV_FILE`, `APPLICATION_PROD_YML`, `SERVER_HOST`, `SERVER_USER`, `SERVER_PASSWORD`, `SERVER_PORT`, `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64`
  - client: `CLIENT_ENV_FILE`, `CLIENT_ADMOB_ENV_STAGED`, `GOOGLE_SERVICES_JSON`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64`, `RELEASE_KEYSTORE_BASE64`, `RELEASE_KEYSTORE_PASSWORD`, `RELEASE_KEY_ALIAS`, `RELEASE_KEY_PASSWORD`, `APPLE_CERTIFICATE_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_PROVISIONING_PROFILE_BASE64`, `APPLE_TEAM_ID`, `APP_STORE_CONNECT_API_KEY_BASE64`, `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `IOS_BUNDLE_ID`, `IOS_PROVISIONING_PROFILE_NAME`
- 값이 비어 있는 시크릿은 건너뛴다(기존 동작 유지). 타임스탬프 폴더 백업도 그대로 둔다.
- 시크릿이 평문 파일로 저장되므로 올라간 파일은 소유자만 읽도록 권한을 줄인다.

⚙️ 작업 내용
---

- `.github/workflows/PROJECT-COMMON-SECRET-FILE-UPLOAD.yaml`의 `PROJECT_NAME`을 `elum`으로 바꾼다.
- 위 목록의 시크릿별 업로드 구간과 메타데이터 JSON의 파일 목록을 추가한다.
- 검증: 워크플로우 문법 검사 후, 사용자 승인 하에 develop push로 실행해 시놀로지 폴더에 파일이 생기는지 확인한다.

🙋‍♂️ 담당자
---

- 서버/인프라: Cassiiopeia
