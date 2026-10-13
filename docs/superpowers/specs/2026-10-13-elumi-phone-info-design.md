# 이룸이 휴대폰 화면에 기기 이름·연결한 사람·연결 날짜 보이기 (#632)

## 목표

설정 → 이룸이 휴대폰 화면에서 연결된 휴대폰마다 **기기 이름, 연결한 사람, 연결 날짜**를 보이고,
연결된 휴대폰이 있어도 목록 아래 `+ 다른 휴대폰 연결하기`로 연결 암호 만들기(`Routes.linkCode`)에 갈 수 있게 한다.

```
iPhone 16                연결됨
김선생님이 연결 · 10월 13일부터
[ 연결 끊기 ]
+ 다른 휴대폰 연결하기
```

## 데이터 흐름

```
이룸이 휴대폰 ─ POST /api/device-links/redeem {code, deviceName?} ─▶ device_link.device_name 저장
보호자 휴대폰 ─ GET  /api/device-links ─▶ devices[{linkId, linkedAt, deviceName, linkedByName, linkedByMe}]
```

- **기기 이름**: 앱이 `device_info_plus` 로 모델명만 읽어 redeem 에 싣는다. iOS 는 `modelName`(`iPhone 16`),
  Android 는 제조사+모델. 사용자가 정한 기기 이름(`OO의 iPhone`)·고유 식별자는 읽지 않는다.
- **연결한 사람**: 그 연결 암호를 만든 보호자(`device_link.member_id`)의 `profile_guardian.display_name`
  (연결의 `profile_id` 기준). 서버는 이룸이별로 한 번에 조회한다 (N+1 없음).
  이메일·계정 ID 는 응답에 없다.
- **내가 연결**: `device_link.member_id == 호출자` 이면 `linkedByMe=true`.
- 서비스 경계: `link` 도메인이 `member.ProfileGuardianRepository` 를 직접 쓰지 않고
  `ProfileGuardianService.displayNamesOf` 를 거친다 (cross-domain allowlist 동결 규칙).

## API 변화 (하위 호환)

| | 변화 |
| --- | --- |
| `POST /api/device-links/redeem` | 요청에 선택 필드 `deviceName` 추가. 없어도 동작(옛 앱). 서버가 제어 문자를 빼고 앞뒤 공백을 자르며 40자로 자른다. 이상한 값은 **거부하지 않고 정리/폐기**한다 — 부가 정보 때문에 연결이 막히면 안 된다. |
| `GET /api/device-links` | `devices[]` 항목에 `deviceName`, `linkedByName`, `linkedByMe` 추가. 옛 앱은 모르는 필드를 무시한다. |
| 에러 코드 | 불변 |
| DB | `V35`: `device_link.device_name VARCHAR(60)` NULL 허용, 기본값 없음. 추가만 한다(옛 서버 이미지로 되돌려도 동작). |

## 행복 경로

1. 이룸이 휴대폰이 암호를 넣는다 → 모델명이 함께 가고 저장된다.
2. 보호자 상태 화면이 기기 이름·`{이름}이 연결 · {월}월 {일}일부터`를 보인다.
3. 다른 휴대폰이 필요하면 목록 아래 입구 → 연결 암호 만들기. (`push` 라 뒤로가기로 이 화면에 돌아온다.)

## 실패·예외 경로

| 상황 | 동작 |
| --- | --- |
| 기기 이름을 못 읽음(플러그인 오류·시간 초과 2초·미지원 플랫폼) | 이름 없이 연결. 연결을 막지 않는다. |
| 서버가 이름을 비어 있다고 봄(공백·제어 문자뿐) | null 로 저장. |
| **기존 행(기기 이름 없음)·옛 앱이 연결** | `deviceName=null` → 기존처럼 `이룸이 휴대폰` 번호 제목(여러 대일 때) + `연결됨`. |
| 연결한 보호자 이름이 없음/모름(이룸이가 비어 있는 옛 행 포함) | `linkedByName=null` → 앱이 `보호자`로 부른다 (`commonGuardianName`). |
| 연결한 보호자가 이미 나감 | `profile_guardian` 행이 없어 이름 null → `보호자가 연결`. 연결 자체는 유지된다. |
| 날짜를 모름 | 연결한 사람만 보인다. |
| 응답 형식이 다름 | `LinkedDevice.fromJson` 이 타입을 확인해 null 로 떨어뜨린다. 화면은 죽지 않는다. |
| 목록 불러오기 실패·0대 | 기존 상태 그대로 (재시도 + 에러 코드 / `연결된 휴대폰이 없어요`). |

## 서비스 원칙 점검

- 진단명·장애 유형 수집 없음. 저장 항목은 **기기 모델명뿐**이다. 이메일은 서버에 없고 저장·표시하지 않는다.
- 새 시각 언어 없음: 입구는 기존 `연결하기` 칩(`linkRetryChipBg`)을 `_ConnectChip` 으로 꺼내 재사용.
- 문구는 해요체. `{name}{batchim, select, yes{이} other{가}} 연결` 은 한국어 조사 선택(`batchimOf`).
  ARB 는 ko·en 에 추가한다 (ja·zh·es 는 골격이라 ko 로 대체된다 — `arb_parity_test` 의 열린 언어 규칙).

## 건드리지 않는 것

- `link_status_screen` 의 데이터 갱신(들어올 때 최신 값 받기)은 #631 이 한다. 이 작업은 레이아웃·표시만 바꾼다.
- `link_enter_screen`·`LinkEnterController` 는 바꾸지 않는다. 이름은 `DeviceLinkRepository.redeem` 이 스스로 읽는다
  (생성자 `deviceNameReader` 로 시험에서 바꾼다).

## 테스트 층

| 결함 | 테스트 |
| --- | --- |
| 옛 앱(이름 없음)이 연결되지 않는다 | `DeviceLinkServiceTest.redeem_withoutDeviceName` |
| 제어 문자·긴 이름이 보호자 화면에 그대로 나간다 | `DeviceNameTest`, `DeviceLinkServiceTest.redeem_savesSanitizedDeviceName` |
| 연결한 사람/내가 연결/기기 이름이 틀리거나 이룸이당 조회가 여러 번 나간다 | `DeviceLinkServiceTest.status_carriesDeviceAndLinkedBy` |
| 앱이 이름을 못 읽으면 연결이 실패한다 | `device_link_disconnect_test` 의 redeem 두 건 |
| 이름이 사람 읽는 모델명이 아니거나 개인 이름이 샌다 | `device_name_reader_test` (정규화), 실기기 값은 미확인 |
| 옛 서버 응답·깨진 값에 화면이 죽는다 | `link_status_test` |
| 세 정보가 안 보이거나 입구가 없다 | `link_status_screen_test` |

## 남은 위험

- iOS `modelName` 이 시뮬레이터·신기종에서 어떤 문자열을 주는지 실기기로 확인하지 못했다.
- 로컬 DB 리허설(V35 적용)은 하지 않았다. 컬럼 추가뿐이라 운영 사본으로 한 번 적용해 보는 것이 안전하다.
