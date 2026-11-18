# 위젯에서 카드 체크 설계 (#1465 2단계)

## 왜
이룸이 기기 "지금 할 카드" 위젯에서 앱을 열지 않고 카드를 끝낼 수 있게 한다. 한 번 누르면 루미가 칭찬하고 다음 카드로 넘어간다.

## 범위
- 이룸이 기기 위젯만 체크 버튼을 단다. 보호자 기기 위젯은 지금처럼 누르면 앱을 연다.
- iOS 17 이상은 위젯 안 버튼(AppIntent)으로 체크한다. iOS 16은 버튼 없이 누르면 그 카드를 연다.
- Android는 모든 버전에서 브로드캐스트로 체크한다.
- **마지막 카드는 위젯에서 끝내지 않는다.** 앱을 열어 그 카드를 체크하고, 앱의 칭찬 화면을 보여 준다.
- 체크만 한다. 위젯에서 체크를 되돌리는 기능은 없다(되돌리기는 앱에서).

## 하지 않는 것
- 위젯에서 바로 서버로 보내지 않는다. 진행 기록의 원본은 앱의 `ChildRoutineNotifier`(기기 저장 > 서버 전송) 하나다. 네이티브에 전송 코드를 따로 두면 두 곳이 어긋난다.
- 그래서 위젯에서 체크한 카드는 **이룸이가 앱을 다음에 열 때** 서버로 간다. 그전까지는 보호자 화면에 반영되지 않는다(알려진 한계, 측정 뒤 다시 본다).

## 데이터
### 요약 JSON에 붙는 것 (`LockScreenElumiCard`)
| 필드 | 뜻 |
|---|---|
| `remainingCount` | 이 일과에서 남은 카드 수 (지금 카드 포함) |
| `upcomingCards` | 지금 카드 다음 카드 최대 2장: `cardId`, `cardText`, `imageFilePath`, `pictogramId`, `exampleImageId` |

위젯은 체크한 뒤 앱 없이 `upcomingCards`의 다음 장을 보여 준다. 다음 장이 바닥나면 "앱에서 이어서 해요" 상태로 바뀐다.

### 체크 대기열 (네이티브 공유 저장소)
- 키 `elum.widget.checkOutbox`: `[{routineId, cardId, dateKey, checkedAtMillis}]`
- iOS는 App Group UserDefaults, Android는 위젯 SharedPreferences에 둔다.
- 같은 `routineId+cardId`는 한 번만 넣는다.
- 위젯 표시 상태(`checkedCardIds`)도 함께 바꿔서 위젯이 바로 다음 카드를 그린다.
- 앱이 새 요약을 보내면 위젯 표시 상태를 비운다. 새 요약이 기준이 된다.

### 앱이 대기열을 받는 때
- 앱이 켜질 때와 앞으로 돌아올 때 `takeWidgetChecks`를 부른다(꺼내면 비워진다).
- Android에서 앱이 떠 있으면 네이티브가 `widgetChecksAdded`로 알린다.
- 각 항목은 `ChildRoutineNotifier.markCheckedFromWidget(routine, cardId)`로 처리한다.
  - 이미 체크된 카드는 건너뛴다(토글 아님).
  - 오늘이 아닌 `dateKey`는 버린다.
  - 오늘 일과에 그 일과·카드가 없으면 버린다(로그 `[widget check] dropped : …`).
- 처리한 뒤 일반 흐름대로 기기에 저장 > 서버 전송 > 새 요약 > 위젯 갱신이 이어진다.

## 위젯 동작
| 상황 | 화면 | 누르면 |
|---|---|---|
| 남은 카드 2장 이상 | 카드 그림·글 + "다 했어요" 버튼 | 대기열에 넣기 > 루미 칭찬 한마디 > 다음 카드 |
| 마지막 카드 | 카드 + "다 했어요" 버튼 | 앱 열기 `check:<routineId>:<cardId>` > 체크 > 칭찬 화면 |
| 위젯에서 받아 둔 다음 카드가 없음 | 루미 + "앱에서 이어서 해요" | 앱 열기 `routine:<id>` |
| 보호자 기기 · iOS 16 | 지금과 같음 | 앱 열기 |

- **연속 누름 막기**: 마지막 체크 뒤 1.5초 안에 들어온 누름은 무시한다. 같은 손가락이 다음 카드까지 끝내지 않게 한다.
- 체크 직후 루미는 `cheer` 표정과 "잘했어요!" 한마디를 보여 준다. 다음 갱신 때 원래 상태로 돌아간다.

## 경로
`check:<routineId>:<cardId>` 경로를 새로 둔다. 앱은 그 카드를 체크한 뒤 일과 카드 화면을 연다. 마지막 카드였다면 앱의 완료·칭찬 흐름이 그대로 이어진다. 경로 값은 `LockScreenRoutes` 한 곳에 둔다.

## 실패 경로
- 대기열 JSON이 깨졌으면 비우고 로그를 남긴다. 위젯은 요약 기준으로 돌아간다.
- 앱이 대기열을 처리하다 실패해도 홈은 그대로 뜬다(로그만).
- 요약이 오늘 것이 아니면 체크 버튼을 숨기고 누르면 앱을 연다.

## 측정
앱이 대기열을 처리할 때 `[widget check] applied : n` 로그를 남긴다. 서버 집계는 위젯 설치·누름 집계와 함께 다음에 한다.

## 구현 약속 (두 플랫폼 공통, 2026-11-18)
- 요약 JSON `elumiCard` 추가 필드: `remainingCount`(int, 지금 카드 포함 남은 카드 수), `upcomingCards`([{`cardId`,`cardText`,`imageFilePath`,`pictogramId`,`exampleImageId`}], 최대 2장).
- 위젯 공유 저장소 키 (iOS App Group UserDefaults `group.kr.twinfang.elum` · Android SharedPreferences `elum_widget`):
  - `elum.widget.checkOutbox`: JSON 배열 `[{"routineId","cardId","dateKey","checkedAtMillis"}]`
  - `elum.widget.checkedCardIds`: JSON 배열 `["cardId", ...]` (위젯 표시용, 앱이 새 요약을 보내면 비움)
  - `elum.widget.lastCheckAtMillis`: long (연속 누름 1.5초 막기 · 체크 뒤 10분 동안 루미 cheer + "잘했어요!")
- 위젯이 보여 줄 카드 = [지금 카드] + `upcomingCards` 중 `checkedCardIds` 에 없는 첫 장. 남은 수 = `remainingCount` − 체크한 수.
  - 남은 수 ≥ 2: "다 했어요" 버튼 > 대기열에 넣기 (iOS 17 AppIntent · Android 브로드캐스트)
  - 남은 수 = 1: "다 했어요" 버튼 > 앱 열기 `check:<routineId>:<cardId>`
  - 보여 줄 카드 없음(받아 둔 카드 소진): 루미 + "앱에서 이어서 해요" > `routine:<id>`
  - 요약이 오늘 것이 아니거나 보호자 기기 · iOS 16: 버튼 없음 (지금처럼 누르면 앱)
- 채널 `elum/home_widget` 추가 메서드: `takeWidgetChecks` > JSON 문자열(배열) 꺼내고 비움 · 네이티브 > Dart `widgetChecksAdded` (Android, 앱이 떠 있을 때) · `updateSnapshot` 은 `checkedCardIds` 를 비움.
- 버튼 문구 `widget_check_done` "다 했어요" · 칭찬 `widget_check_praise` "잘했어요!" · 소진 `widget_continue_in_app` "앱에서 이어서 해요" (5개 언어).
