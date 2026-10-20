# 예시 일과 카드 이미지를 준비한 에셋으로 (#866)

## 배경

보호자 피드백(2026-10-20): "템플릿 일과가 엉망이에요." 온보딩 예시 일과는 카드마다 픽토그램만 붙고, 문구와 그림이 어긋난 카드가 있다.

| 카드 문구 | 지금 그림 | 원인 |
| --- | --- | --- |
| 바닥을 닦아요 | 식탁 닦기 | 바닥 픽토그램이 없어 `wipe_table_,_to`를 빌려 씀 |
| 그릇을 갖다 놓아요 | 설거지 | `wash_up_,_to` |
| 신발을 신어요 | 남자 신발 | `shoe_-_mans` |

## 결정

1. **이미지는 앱에 번들한다.** 루미 이미지 31장을 512px WebP로 줄여 `client/assets/images/example_routines/`에 둔다. 원본 PNG 28MB가 764KB가 된다. 오프라인·첫 온보딩 직후에도 보인다.
2. **서버는 id만 내려준다.** 단계 응답에 `exampleImageId`(예 `fold_blanket`)를 더한다. 카탈로그 33단계에 하나씩 직접 연결한다. 픽토그램 id로 연결하면 `school_bag`, `wipe_table_,_to`, `sit_,_to`처럼 다른 행동이 같은 그림으로 다시 묶인다.
3. **표시 우선순위: 사진·AI 그림 > 예시 이미지 > 픽토그램 > 기본 카드.** 보호자가 사진으로 바꾸면 그대로 바뀐다. 픽토그램 id는 그대로 내려줘 예시 이미지를 모르는 옛 앱도 지금처럼 보인다.
4. **이미 만들어진 예시 일과도 채운다.** 마이그레이션이 예시 일과 제목(ko·en) + 단계 순서 + 단계 문장(ko·en)이 카탈로그와 같은 단계에만 id를 채운다. 보호자가 고친 단계는 건드리지 않는다.

## 실패 경로

| 상황 | 결과 |
| --- | --- |
| 서버가 앱에 없는 id를 내려줌 | `ExampleCardImageCatalog.parse`가 null로 돌려 픽토그램 > 기본 카드 |
| 번들 파일을 못 읽음 | `ExampleCardArt`가 픽토그램 > 기본 카드로 내려감 |
| 응답에 `exampleImageId` 없음 (옛 서버) | null이라 픽토그램 그대로 |
| 마이그레이션이 두 번 실행됨 | `IF NOT EXISTS` + `example_image_id IS NULL` 조건으로 멱등 |

## 범위

- 서버: `RoutineExampleStep`·카탈로그, `RoutineStep.exampleImageId`, `RoutineStepResponse`, 복제(`RoutineRules`), 마이그레이션 `V48`
- 앱: `ExampleCardImageCatalog`, `ActionCard.exampleImageId`, `ExampleCardArt`, `CardImage`와 화면 연결 5곳, `showsPictogram` > `showsBundledArt`
- 하지 않는 것: AI 이미지 생성, 화면 레이아웃 변경, 서버 이미지 저장소 사용

## 검증

- 서버: 카탈로그 33단계 전부 id가 있고 앱 에셋 파일이 있는지(`RoutineExampleCatalogTest`), 같은 행동만 이미지를 공유하는지, 생성 서비스가 id를 저장하는지
- 마이그레이션: 임시 Postgres에서 두 번 적용, 카탈로그와 같은 단계만 채워지고 고친 단계·비예시 일과는 그대로
- 앱: `flutter analyze` (앱 테스트는 #848에서 제거됨), 시뮬레이터 E2E
- 이미지 파일은 `lumi/` 원본 31장 중 같은 파일명으로 만들었다. 대응표는 서버 카탈로그가 원본이다.
