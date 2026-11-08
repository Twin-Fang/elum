# 이미지 저장소 MinIO 전환 (#1197)

카드, 이야기, 공지 그림을 서버 폴더에서 NAS MinIO로 옮긴다. 저장소 인터페이스가 열쇠를 돌려주므로 DB와 앱은 바꾸지 않는다. 음성 파일은 범위 밖이다.

## 구조

- 스위치 `elum.store.image`: `local`(기본), `minio`. 저장소 3개가 함께 바뀐다.
- 버킷 `elum`, 객체 이름 `{구역}/{열쇠}`. 구역은 `routine-images`, `talk-images`, `notice-images`로 로컬 폴더 이름과 같다.
- 계정 `elum-server`: 정책 `elum-rw`로 `elum` 버킷만 접근한다. 비밀번호 원본은 NAS `/volume1/project/elum/runtime-config/minio.env`(root 600).
- 서버는 `minio_default` 네트워크로 `http://minio:9000`에 접속한다.
- 그림 전달은 지금처럼 서버 API가 한다.

## 동작

| 동작 | 처리 |
|---|---|
| 쓰기 | MinIO만. 실패하면 저장소별 기존 오류 코드 |
| 읽기 | MinIO. 없거나 장애면 `fallback-to-local=true`일 때 로컬, 아니면 없음 오류 |
| 삭제 | MinIO와 로컬 양쪽. 로컬에 남으면 지운 그림이 읽기 대체로 다시 보인다. 실패해도 예외 없음 |
| 설정 누락 | 기동 실패 |
| 시작 때 MinIO 접속 실패 | 오류 로그만 남기고 뜬다 |

## 전환 순서

1. 버킷과 계정 생성, 기존 파일 1차 복사
2. NAS `application-nas.yml`에 `elum.store` 값 추가 (`fallback-to-local: true`)
3. 코드 배포 (`develop`에서 `PROJECT-SPRING-ELUM-NAS-CICD` 수동 실행)
4. 쓰기, 읽기, 삭제 실측
5. 2차 복사(전환 전 만든 그림 포함), 개수와 바이트 대조
6. `fallback-to-local: false`로 바꾸고 재배포, 옛 그림 읽기 실측
7. 로컬 파일은 지우지 않는다. 삭제는 사용자 확인 후

## 되돌리기

`elum.store.image: local`로 바꾸고 재배포한다. 전환 뒤 새로 만든 그림은 MinIO에만 있으므로 먼저 MinIO에서 로컬로 복사한다.

## 주의

- `setup-mirror.sh`는 `application-nas.yml`을 덮어쓴다. 다시 돌리면 `elum.store` 값이 사라져 로컬 저장으로 돌아간다.
- `MigrationFileExportService`는 로컬 폴더를 읽는 서버 이전 전용 기능이라 MinIO를 보지 않는다.
