<!-- This is an auto-generated comment: release notes by coderabbit.ai -->

## Summary by CodeRabbit

## 릴리스 노트

* **새 기능**
  * 루틴 단계에 카드 제목(title) 필드 추가, description은 읽어주기용 문장으로 역할 명확화
  * 관리자 프롬프트 preview/test가 실제 호출과 동일한 조립 로직을 재사용하도록 통합
  * 이미지 프롬프트 조립을 GeminiRoutineImagePromptBuilder로 분리
  * 추가 질문 fallback을 전체 단위에서 목표별 개별 단위로 전환
  * 추가 질문 Gemini 호출을 JSON으로 전환하고 목표별 questions 배열 크기를 강제
  * 이미지 생성 실패 시 1회 재시도, 루틴 수정 시 변경 없는 단계는 이미지 재사용
  * 루틴 수정 Gemini 호출을 REVISE_ROUTINE JSON으로 전환하고 기존 제목을 함께 전달

* **버그 수정**
  * Spring Boot 4 Flyway 자동 설정 누락 수정 및 공통 설정 추가
  * 최종 리뷰 반영 — fallbackQuestionItem 주석 정정, REVISE 프롬프트 title 필드 반영, 단계 title 스키마에 minLength 추가

* **문서**
  * 루틴 생성/추가 질문 API 문서를 이미지 재시도·목표별 질문 보장에 맞춰 갱신

* **기타**
  * elum 버전 관리 : chore : v1.0.67 릴리즈 버전 확정 및 릴리즈 문서 업데이트 (PR )
  * Merge branch 'main' into develop
  * 온보딩 애니메이션 개선 설계 : docs : 시작 화면 등장·idle 연출과 온보딩 페이지 전환 설계 문서 추가
  * 카드확인 화면 배경 블러 글로우 제거 : fix : RoutineFlowScaffold에 showAurora 플래그 추가하고 카드확인 화면에서 오로라 배경 비활성화
  * Merge pull request from Twin-Fang/develop
  * Merge branch 'develop' of into develop
  * elum 버전 관리 : chore : v1.0.65 릴리즈 버전 확정 및 릴리즈 문서 업데이트 (PR )
  * Merge remote-tracking branch 'origin/main' into develop
  * 카드 수정 바텀시트 추가 및 카드확인·아이 상세 Figma 정합 : feat : 카드 제목·설명 수정 바텀시트, 삭제 X 우상단 이동, 아이 상세 상단바 일과 제목 표시, 아이 홈 /today 전환()
  * Merge branch 'develop' of into develop
  * 이미지 재시도 테스트에 정확한 호출 횟수 검증 추가
  * elum 버전 관리 : chore : v1.0.64 릴리즈 버전 확정 및 릴리즈 문서 업데이트 (PR )
  * 골든 테스트 산출물 정리 : chore : test/failures 디렉토리를 git에서 제외
  * Merge branch 'develop' of into develop
  * 카드 삭제 회귀 방지 : test : 마지막 한 장은 지울 수 없다를 고정

<!-- end of auto-generated comment: release notes by coderabbit.ai -->
