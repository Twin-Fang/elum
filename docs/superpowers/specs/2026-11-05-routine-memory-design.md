# Pro 진화형 행동카드: 이룸이별 AI 메모 (#1082)

## 목표

보호자가 AI 카드를 고쳐 확정한 결과(나눔·합침·문장 수정·순서·사진 교체)를 이룸이마다 짧은 메모(최대 10줄)로 정리하고,
Pro 일과 만들기에 메모 + 최근 확정 예시 3개를 함께 넣어 그 아이에게 맞는 크기·말로 카드를 만든다. Free 는 지금 하네스 그대로.

## 지키는 것

| 원칙 | 설계 |
|---|---|
| 진단·장애 유형·정도 수집 금지 (원칙 1) | 메모 지시문 금지 규칙 + 서버 금지 낱말 거르기(`RoutineMemorySafetyFilter`, AI 줄·보호자 줄 모두). 점수·등급 값 없음 |
| 필요한 정보만 AI 로 (원칙 2) | 메모 갱신 입력은 처음 AI 카드 글 <-> 확정 카드 글 + 사진 카드 수뿐. `rawInputText` 는 보내지도 저장하지도 않음. 이름은 자리표시 |
| 원문 저장 금지 (원칙 5) | 스냅샷 `routine.ai_draft_cards` 는 AI 가 만든 카드 글만 (Pro + 켜짐일 때만) |
| 보호자 통제 | 설정 > AI 메모: 보기·고치기·지우기·더하기·모두 지우기·끄기. 나가기·탈퇴(이룸이 정리) 시 삭제 |
| 일과 만들기를 막지 않음 | 맞춤 준비 실패 > 빈 계획(지금 하네스). 메모 갱신은 예약 작업(30분 주기)이라 확정 응답과 무관 |
| 비용 | 이룸이마다 하루 1번 묶어 갱신(고친 일과 5개면 그 전에도). 한 번에 고친 일과 최대 6개. 하루 AI 비용 상한에 닿으면 멈춤 |

## 흐름

1. 일과 만들기 (Pro `ROUTINE_MEMORY` + 켜짐): `RoutinePersonalizationProvider` > 메모 줄 + 확정 예시(고친 것 먼저, 최대 3) >
   `AiCallContext` > 세 제공자 공용 조립(`GeminiTextClient.buildCreateRoutineUserContent`)이 `guardianStyle` 필드로 실음 (사용 안내 문장 포함, 운영 DB 지시문 불변).
   저장할 때 AI 처음 카드를 `ai_draft_cards` 로 남김.
2. 확정·완료 뒤: `RoutineMemoryBuildScheduler` > `RoutineMemoryBuildStore.prepare` (꺼짐·Pro 아님·고친 것 없음은 반영 표시만) >
   `RoutineMemoryAi`(설정된 텍스트 제공자 사슬) > `apply` (보호자 줄 유지·금지 낱말·지운 줄 거름·10줄) > `memory_reflected_at`.
3. AI 실패: 일과는 남기고 `last_built_at` 만 기록 > 하루 뒤 재시도.

## 데이터 (V63)

- `routine.ai_draft_cards TEXT`, `routine.memory_reflected_at TIMESTAMP` (+ 부분 색인)
- `routine_memory(profile_id unique FK ON DELETE CASCADE, enabled, lines JSON, dismissed_lines JSON, last_built_at)`

## API

`GET /api/routine-memory` · `PUT /lines` (전체 교체) · `PATCH /enabled` · `DELETE` — `X-Profile-Id`, Free 는 GET 빈 응답·쓰기 403.

## 하지 않는 것

- 중증도·수준 추정, 원문 학습, 메모를 이룸이 화면에 보이기, Free 노출(Pro 를 앱에서 살 수 없는 동안 설정 줄 숨김), 다국어 메모 문장.
