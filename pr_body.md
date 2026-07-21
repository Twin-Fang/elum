<!-- This is an auto-generated comment: release notes by coderabbit.ai -->

## Summary by CodeRabbit

## 릴리스 노트

* **새 기능**
  * Gemini 응답 스키마 title 필드에 아이 친화적 제목 작성 힌트 추가
  * 루틴 생성 프롬프트에 아이 친화적 제목 생성 지시 추가
  * 일과 생성/재생성에 회원당 30초 요청 쿨다운 적용

* **버그 수정**
  * 캐릭터 기능 최종 리뷰 Minor 지적 3건 반영 (asset 매핑 동기화, Swagger 문서 정정, 배선 테스트 추가)

* **문서**
  * 일과 추가 질문 추천 답변 emoji 구조 구현 계획 작성
  * 일과 추가 질문 추천 답변 이모지 구조 및 직접입력 제거 설계 작성
  * 루틴 제목 API 문서 예시를 아이 친화적 톤으로 갱신

* **기타**
  * elum 버전 관리 : chore : v1.0.57 릴리즈 버전 확정 및 릴리즈 문서 업데이트 (PR )
  * 에셋·테스트·로딩 화면 업데이트 : chore : 에셋 매핑 동기화 및 테스트 업데이트
  * 상태관리·앱 생명주기 로깅 추가 : feat : RoutineFlowNotifier 상태 전이·main 앱 시작 종료 로깅
  * 네트워크·저장소 디버깅 로그 추가 : feat : Dio 인터셉터·Repository·LocalStorage 모든 호출 자동 로깅
  * 공통 로거 시스템 구현 : feat : 타임스탐프·카테고리·구조화된 디버깅 로그 시스템 추가
  * 배포 환경변수 누락 수정 : fix : 워크플로우가 CLIENT_ENV_FILE 시크릿을 읽도록 수정
  * Merge branch 'main' into develop
  * Merge branch 'main' into develop
  * Merge pull request from Twin-Fang/develop
  * Merge branch 'develop' of into develop
  * Merge remote-tracking branch 'origin/main' into develop
  * 배포 빌드 개발자 도구 활성화 : docs : 배포 앱에만 버튼이 안 보이던 원인 트러블슈팅 기록
  * elum 버전 관리 : chore : v1.0.55 릴리즈 버전 확정 및 릴리즈 문서 업데이트 (PR )
  * 배포 빌드 개발자 도구 활성화 : fix : 빌드 워크플로우에서 ELUM_SHOW_DEV_TOOLS 강제 주입
  * 추가질문 화면 직접 입력 구현 및 선택지 이모지 반영 : feat : + 직접 입력하기 칩·입력 필드 추가
  * 일과 만들기 로딩 화면 Figma 정합 및 flow 순서 수정 : fix : 로딩 화면 2종 분리·스텝 최소 노출시간 보장
  * Merge pull request from Twin-Fang/develop
  * 일과 요청 쿨다운 가드 단위테스트 추가
  * elum 버전 관리 : chore : v1.0.53 릴리즈 버전 확정 및 릴리즈 문서 업데이트 (PR )

<!-- end of auto-generated comment: release notes by coderabbit.ai -->
