# 카드확인·아이 상세 Figma 정합 + 카드 수정 바텀시트 설계

- 날짜: 2026-07-22
- 기준 Figma (2026-07-22 덤프·PNG 확인):
  - `262:5124` 보호자_새로운 일과 만들기_카드확인
  - `309:3548` 아이_홈 (일과 상세)

## 배경

카드 명세가 바뀌었다. 카드확인 화면에서 **생성(재생성) 기능은 빠지고 삭제·수정만 남는다.**
수정은 카드의 **제목(title)과 설명(description)만** 바꿀 수 있다. 디자이너가 수정 UI를
키보드 가림 문제로 확정하지 못해, 클라이언트에서 바텀시트 패턴으로 확정했다.

## 서버 제약 (2026-07-22 서버 코드 확인)

- `RoutineStep` 엔티티에 **step 단위 title 컬럼이 없다.** (`stepOrder`/`description`/`imagePath`/`completed`/`completedAt`)
- 수정 API `PATCH /api/routines/{id}/steps/{stepId}`의 `RoutineStepUpdateRequest`는 **description만** 받는다.
- `Routine.title`(일과 전체 제목)은 존재하며 `RoutineResponse.title`로 내려온다 — 아이 상세 상단바에 쓴다.
- 이슈 #75(`GET /api/routines/today`)는 아이 홈 **목록** API로, 이번 작업과 겹치지 않는다.

→ **카드 title 수정은 로컬 반영만, description은 기존 API로 즉시 서버 PATCH.**
서버가 step title을 지원하게 되면 `ActionCard.fromJson`이 이미 `title`을 읽도록 되어 있어 그대로 붙는다.
서버 step title 추가는 별도 서버 이슈로 분리한다.

## 1. 보호자 카드확인 (262:5124)

| 항목 | 변경 |
|---|---|
| 삭제 X 버튼 | 이미지 **좌상단 → 우상단** (흐린 원형 배경 + X). 마지막 한 장이면 숨김(기존 규칙 유지) |
| 이미지 위 `완료` 알약 버튼 | **제거** |
| 수정 진입점 | 카드와 저장하기 버튼 사이 중앙에 **`이 카드 수정하기` 알약 칩** (#EEE9E6 배경, Pretendard 600 14). 현재 페이저에서 보고 있는 카드가 대상 |
| 서브텍스트("내용을 확인하고…") | Figma에 없음 → **제거** |

## 2. 카드 수정 바텀시트 (신규)

`showModalBottomSheet(isScrollControlled: true)` + `viewInsets.bottom` 패딩으로
**시트가 키보드 위에 붙는다** — 키보드 가림 문제 원천 차단.

- 구성: 시트 제목("카드 수정하기") + 제목 입력칸 + 설명 입력칸 + 저장 버튼
  (기존 `ElumTextField` / `ElumButton` 재사용)
- 저장(행복 경로): 로컬 상태 즉시 반영(title+description) → 서버에 description PATCH → 시트 닫힘
- 실패 경로:
  - API 실패 → **로컬 반영은 유지**, 스낵바 `수정 내용을 서버에 저장하지 못했어요 (E-STEP)`
  - 제목·설명 둘 다 비면 저장 버튼 비활성
  - 시트 밖 탭/뒤로가기 → 변경 버리고 닫힘
- `RoutineFlowNotifier.updateStep`을 title도 받도록 확장

## 3. 아이 일과 상세 (309:3548)

| 항목 | 변경 |
|---|---|
| 상단바 | 캐릭터 배지(루루) 제거 → **일과 제목(`Routine.title`) 중앙 표시** (Tmoney 800 18) |
| 카드 영역 | 위로 올라간 레이아웃(y=180)에 맞춰 간격 조정 |
| 카드 내부·체크 버튼 | 변경 없음. 수정/삭제 버튼은 아이 화면에 없음(기존과 동일) |

## 4. 검증

- 위젯 테스트: 수정 칩 탭 → 시트 노출 / 저장 → 제목·설명 갱신 / 빈 값 저장 불가 /
  X 우상단 존재 / 아이 상세 상단바에 일과 제목 노출
- `flutter analyze` / `flutter test` 통과
- 시뮬레이터 화면과 Figma PNG 비교
