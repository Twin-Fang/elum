# 관리자 시스템 설정을 성격별 화면으로 나누기 (#1218)

## 왜

`/admin/settings` 한 화면에 설정 131개(묶음 19개)가 표 하나로 섞여 있다. AI·요금제·결제·광고·앱 버전이 한 표에 있어
찾기 어렵고, 위쪽 `AI 제공자 전환`·`Free / Pro 비교` 카드가 아래 표와 같은 값을 다시 보여 줘 더 헷갈린다.
사용자 요청: "남길 것은 남기고, 옮길 것은 옮겨 따로 관리".

## 결정

설정값(키·값·기본값·이력·검증)은 바꾸지 않는다. **보여 주고 고치는 화면만** 나눈다.

| 화면 (`SettingsSection`) | 경로 | 설정 묶음 (`ConfigGroup`) |
|---|---|---|
| 시스템 설정 | `/admin/settings` | MEMBER, USAGE_LIMIT, APP_CONTROL, APP_TUNING, LANGUAGE, MAIL (30) |
| AI 설정 (새) | `/admin/settings/ai` | GEMINI_TEXT, GEMINI_IMAGE, IMAGE_PROVIDER, TEXT_PROVIDER, PRICING, AI_BUDGET (32) |
| 요금제·구독 (새) | `/admin/settings/plans` | PLAN_FREE, PLAN_PRO, SIGNUP_PRO_EVENT, EXISTING_MEMBER_PRO_GIFT, SUBSCRIPTION_STORE (60) |
| 광고 보상 (기존) | `/admin/ad-rewards` | AD_REWARD (5) |
| 공지 관리 (기존) | `/admin/notices` | NOTICE (1) |
| 서버 이전 (기존) | `/admin/migration` | MIGRATION (3, 새 묶음) |

- 묶음 > 화면 대응은 `SettingsSection.of(ConfigGroup)` switch 식 한 곳. default 가 없어 새 묶음을 만들고 화면을 정하지 않으면 컴파일이 실패한다.
- `MIGRATION_LOCK`·`MIGRATION_FILE_EXPORT_ENABLED`·`APP_API_BASE_URL` 은 `APP_CONTROL` 에서 새 묶음 `MIGRATION("서버 이전")` 으로 옮긴다. 묶음은 enum 값일 뿐 DB 에 저장하지 않는다.
- 서버 이전 화면의 읽기 전용 `이전 설정` 카드(`MigrationSettingsReader`)는 같은 값을 바로 고치는 설정 칸으로 바꾸고, 읽기 전용 부품은 지운다.
- 표·검색·칩·정렬·수정 패널·토스트는 `settings-parts :: editor(editor)` 조각 하나를 모든 화면이 쓴다.
- 저장 뒤 다시 그리기는 `data-refresh-url`(그 화면 경로)에서 받는다. 요약 구역은 `data-settings-summary="이름"` 마다 갈아 끼운다.
- 폼 제출(기본값 복원, 스크립트 없는 저장, 제공자 순서 변경)은 그 키가 있는 화면으로 돌아간다.
- `지금 적용 중` 요약은 시스템 설정 위에 둔다. 항목이 다른 화면 설정이면 `그 화면#setting=키` 로 가서 패널을 연다. 대시보드 링크도 같다.
- 시스템 설정 위에 `다른 화면에서 관리하는 설정` 카드(화면별 개수·기본값과 다른 수, 바로가기)를 둔다.
- 사이드바: 운영 > `AI 크레딧` 아래 `요금제·구독`, 시스템 > `시스템 설정` 아래 `AI 설정`.
- 테마 전환 버튼: 이모지(🌙/☀️) > 선 아이콘 SVG(달·해) 두 개를 두고 `hidden` 으로 바꿔 보인다.

## 실패 경로

- 저장 실패·규칙 위반: 지금처럼 입력칸 옆 사유 + E-CFG-00x.
- 광고 보상·공지·서버 이전 화면에서 설정을 못 읽으면: 그 화면의 나머지는 그대로, 설정 칸에만 `설정을 불러오지 못했어요 (E-CFG-LOAD)`.
- 저장 후 다시 받기 실패: 지금처럼 네트워크 오류 토스트(E-CFG-NET).

## 하지 않는 것

설정 키·값·기본값 변경, 저장 방식 변경, 화면 간 통합 검색, 관리자 비밀번호 변경 기능.

## 시험

- 모든 설정 키가 정확히 한 화면의 표에 들어간다 (화면별 행을 합치면 전체와 같다) — 설정이 어느 화면에서도 안 보이는 결함.
- 화면 템플릿이 그 화면의 키만 그린다 (AI 화면에 플랜 키가 없음) — 기존 템플릿 시험 갱신.
